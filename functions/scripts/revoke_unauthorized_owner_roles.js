#!/usr/bin/env node

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const { FieldValue } = admin.firestore;

const args = new Set(process.argv.slice(2));
const applyChanges = args.has('--apply');
const actor = process.env.ROLE_MIGRATION_ACTOR || 'role-migration-script';

function toBoolean(value) {
  return value === true;
}

async function isAuthorizedOwner(uid) {
  const [ownerDoc, adminDoc] = await Promise.all([
    db.collection('owners').doc(uid).get(),
    db.collection('admins').doc(uid).get(),
  ]);

  if (adminDoc.exists && adminDoc.get('active') !== false) {
    return true;
  }

  if (!ownerDoc.exists) {
    return false;
  }

  const ownerId = String(ownerDoc.data()?.ownerId || '').trim();
  return ownerId === uid;
}

async function run() {
  const snapshot = await db
    .collection('users')
    .where('role', '==', 'owner')
    .get();

  if (snapshot.empty) {
    console.log('No users with role=owner found.');
    return;
  }

  const unauthorized = [];

  for (const doc of snapshot.docs) {
    const uid = doc.id;
    const authorized = await isAuthorizedOwner(uid);
    if (!toBoolean(authorized)) {
      unauthorized.push({ uid, data: doc.data() || {} });
    }
  }

  console.log(`Found ${snapshot.size} owner-role users.`);
  console.log(`Unauthorized owner-role users: ${unauthorized.length}`);

  if (!unauthorized.length) {
    return;
  }

  unauthorized.forEach((entry) => {
    console.log(`- ${entry.uid} (${entry.data.email || 'no-email'})`);
  });

  if (!applyChanges) {
    console.log('Dry run only. Re-run with --apply to downgrade unauthorized users to tenant.');
    return;
  }

  let downgraded = 0;
  for (const entry of unauthorized) {
    const userRef = db.collection('users').doc(entry.uid);
    await userRef.set(
      {
        role: 'tenant',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await db.collection('admin_audit_logs').add({
      action: 'revoke_unauthorized_owner_role',
      adminId: actor,
      targetId: entry.uid,
      oldValue: 'owner',
      newValue: 'tenant',
      reason: 'post-hardening-migration',
      timestamp: FieldValue.serverTimestamp(),
      meta: {
        channel: 'revoke_unauthorized_owner_roles',
      },
    });

    downgraded += 1;
  }

  console.log(`Downgraded ${downgraded} unauthorized owner-role users to tenant.`);
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  });

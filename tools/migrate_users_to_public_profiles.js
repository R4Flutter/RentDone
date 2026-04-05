/*
 * One-time migration script:
 * Copy safe public fields from /users/{uid} to /publicProfiles/{uid}.
 *
 * Usage:
 *   node tools/migrate_users_to_public_profiles.js
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS for Firebase Admin SDK.
 */

const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

function asString(value) {
  return String(value ?? '').trim();
}

function asNumberOrNull(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function toPublicProfile(user) {
  const name = asString(user.name);
  const phoneOptional = asString(user.phone || user.phone_optional);
  const profileImage = asString(user.photoUrl || user.profileImage);
  const rating =
    asNumberOrNull(user.rating) ??
    asNumberOrNull(user.trustScore) ??
    0;

  return {
    name,
    phone_optional: phoneOptional,
    rating,
    profileImage,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function run() {
  let lastDoc = null;
  let processed = 0;
  let written = 0;

  while (true) {
    let query = db.collection('users').orderBy('__name__').limit(400);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      processed += 1;
      const profile = toPublicProfile(doc.data() || {});
      const profileRef = db.collection('publicProfiles').doc(doc.id);
      batch.set(profileRef, profile, { merge: true });
      written += 1;
    }

    await batch.commit();
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }

  console.log(`Migration complete. Processed: ${processed}, written: ${written}`);
}

run().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});

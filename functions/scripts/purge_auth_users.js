/*
 * Purge all Firebase Auth users for a project.
 * Optional: also delete matching Firestore user profile docs in users/{uid}.
 *
 * Usage:
 *   node scripts/purge_auth_users.js --project rentdone-92c6f --confirm
 *   node scripts/purge_auth_users.js --project rentdone-92c6f --confirm --delete-firestore-users
 */

const admin = require('firebase-admin');

function hasFlag(name) {
  return process.argv.includes(name);
}

function getArg(name) {
  const index = process.argv.indexOf(name);
  if (index < 0 || index + 1 >= process.argv.length) return null;
  return process.argv[index + 1];
}

async function deleteFirestoreUsers(db) {
  let deleted = 0;
  const pageSize = 400;

  while (true) {
    const snapshot = await db.collection('users').limit(pageSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      deleted += 1;
    }

    await batch.commit();
    process.stdout.write(`Deleted Firestore users docs: ${deleted}\n`);
  }

  return deleted;
}

async function listAllAuthUids(auth) {
  const uids = [];
  let pageToken;

  while (true) {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) {
      uids.push(user.uid);
    }

    if (!page.pageToken) break;
    pageToken = page.pageToken;
  }

  return uids;
}

async function deleteAuthUsers(auth, uids) {
  let deleted = 0;
  let failed = 0;

  for (let i = 0; i < uids.length; i += 1000) {
    const chunk = uids.slice(i, i + 1000);
    const result = await auth.deleteUsers(chunk);
    deleted += result.successCount;
    failed += result.failureCount;

    process.stdout.write(
      `Processed ${Math.min(i + 1000, uids.length)}/${uids.length} auth users. Deleted=${deleted}, Failed=${failed}\n`,
    );

    if (result.failureCount > 0) {
      for (const err of result.errors) {
        process.stdout.write(
          `  Failed uid=${chunk[err.index]} code=${err.error.code} message=${err.error.message}\n`,
        );
      }
    }
  }

  return { deleted, failed };
}

async function main() {
  const projectId = getArg('--project') || process.env.FIREBASE_PROJECT_ID;
  const confirmed = hasFlag('--confirm');
  const deleteFirestore = hasFlag('--delete-firestore-users');

  if (!projectId) {
    throw new Error('Missing --project <projectId>');
  }

  if (!confirmed) {
    throw new Error('Refusing to run without --confirm');
  }

  admin.initializeApp({ projectId });

  const appProjectId = admin.app().options.projectId;
  if (appProjectId !== projectId) {
    throw new Error(`Project mismatch. Expected ${projectId}, got ${appProjectId}`);
  }

  const auth = admin.auth();
  const db = admin.firestore();

  process.stdout.write(`Starting purge for Firebase project: ${projectId}\n`);

  const uids = await listAllAuthUids(auth);
  process.stdout.write(`Found ${uids.length} Firebase Auth users\n`);

  const authResult = await deleteAuthUsers(auth, uids);

  let firestoreDeleted = 0;
  if (deleteFirestore) {
    firestoreDeleted = await deleteFirestoreUsers(db);
  }

  process.stdout.write('Purge completed.\n');
  process.stdout.write(
    JSON.stringify(
      {
        projectId,
        authUsersFound: uids.length,
        authUsersDeleted: authResult.deleted,
        authUsersFailed: authResult.failed,
        firestoreUsersDeleted: firestoreDeleted,
      },
      null,
      2,
    ) + '\n',
  );
}

main().catch((error) => {
  process.stderr.write(`ERROR: ${error.message}\n`);
  process.exit(1);
});

/*
  DANGER: Deletes Firebase Authentication users in bulk.

  Usage:
    1) Set service account JSON path:
       set GOOGLE_APPLICATION_CREDENTIALS=C:\path\service-account.json
    2) Dry run:
       node tools/reset_firebase_auth_users.js --dry-run
    3) Actual delete:
       node tools/reset_firebase_auth_users.js --confirm
*/

let admin;
try {
  admin = require('firebase-admin');
} catch (_) {
  admin = require('../functions/node_modules/firebase-admin');
}

const args = new Set(process.argv.slice(2));
const isDryRun = args.has('--dry-run') || !args.has('--confirm');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function listAllUsers() {
  const users = [];
  let nextPageToken;

  do {
    const result = await admin.auth().listUsers(1000, nextPageToken);
    users.push(...result.users);
    nextPageToken = result.pageToken;
  } while (nextPageToken);

  return users;
}

async function deleteUsersInChunks(uids) {
  const chunkSize = 1000;
  let deleted = 0;

  for (let i = 0; i < uids.length; i += chunkSize) {
    const batch = uids.slice(i, i + chunkSize);
    const result = await admin.auth().deleteUsers(batch);
    deleted += result.successCount;

    if (result.failureCount > 0) {
      const failed = result.errors.map((e) => ({
        index: e.index,
        code: e.error && e.error.code,
        message: e.error && e.error.message,
      }));
      console.error('Batch delete failures:', failed);
    }

    console.log(`Processed ${Math.min(i + chunkSize, uids.length)}/${uids.length}`);
  }

  return deleted;
}

async function main() {
  const users = await listAllUsers();
  console.log(`Found ${users.length} Firebase Auth users.`);

  if (users.length === 0) {
    console.log('Nothing to delete.');
    return;
  }

  if (isDryRun) {
    console.log('DRY RUN enabled. No users were deleted.');
    console.log('Run with --confirm to permanently delete all users.');
    return;
  }

  const uids = users.map((u) => u.uid);
  const deleted = await deleteUsersInChunks(uids);
  console.log(`Deleted ${deleted} users.`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Reset failed:', error && error.message ? error.message : error);
    process.exit(1);
  });

/*
 * One-time cleanup script:
 * Replaces raw `razorpaySignature` in payment docs with a SHA-256 hash and
 * removes plaintext signature storage.
 *
 * Usage (from repo root):
 *   node tools/backfill_razorpay_signature_cleanup.js
 *
 * Requires Firebase Admin credentials via GOOGLE_APPLICATION_CREDENTIALS.
 */

const crypto = require('node:crypto');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

function asString(value) {
  return String(value ?? '').trim();
}

function hashSignature(signature) {
  return crypto.createHash('sha256').update(signature).digest('hex');
}

async function run() {
  const snapshot = await db
    .collection('payments')
    .where('razorpaySignature', '!=', null)
    .limit(1000)
    .get();

  if (snapshot.empty) {
    console.log('No payment docs with raw razorpaySignature were found.');
    return;
  }

  const batch = db.batch();
  let updated = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() ?? {};
    const rawSignature = asString(data.razorpaySignature);

    if (!rawSignature) {
      batch.update(doc.ref, {
        razorpaySignature: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      updated += 1;
      continue;
    }

    batch.update(doc.ref, {
      razorpaySignatureHash: hashSignature(rawSignature),
      razorpaySignature: admin.firestore.FieldValue.delete(),
      signatureCleanupAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    updated += 1;
  }

  await batch.commit();
  console.log(`Updated ${updated} payment docs.`);

  if (snapshot.size === 1000) {
    console.log('More docs may remain. Re-run the script until it reports none.');
  }
}

run().catch((error) => {
  console.error('Cleanup failed:', error);
  process.exit(1);
});

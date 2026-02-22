// Firebase Cloud Function to migrate existing users to have Gravatar URLs
// Deploy this to Firebase Functions to automatically add gravatarUrl to existing users

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

/**
 * Generates a Gravatar URL from an email address
 */
function getGravatarUrl(email, size = 400) {
  if (!email || email.trim() === '') {
    return null;
  }
  
  const normalizedEmail = email.trim().toLowerCase();
  const hash = crypto.createHash('md5').update(normalizedEmail).digest('hex');
  return `https://www.gravatar.com/avatar/${hash}?s=${size}&d=identicon`;
}

/**
 * Cloud Function to migrate all users to have Gravatar URLs
 * Run once: https://YOUR_PROJECT.cloudfunctions.net/migrateUsersToGravatar
 */
exports.migrateUsersToGravatar = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const usersRef = db.collection('users');
    const snapshot = await usersRef.get();
    
    let updated = 0;
    let skipped = 0;
    const batch = db.batch();
    
    snapshot.forEach((doc) => {
      const data = doc.data();
      const email = data.email;
      
      // Skip if no email or gravatarUrl already exists
      if (!email || data.gravatarUrl) {
        skipped++;
        return;
      }
      
      const gravatarUrl = getGravatarUrl(email);
      
      if (gravatarUrl) {
        // Update photoUrl if it's empty
        const updates = {
          gravatarUrl: gravatarUrl,
        };
        
        if (!data.photoUrl || data.photoUrl === '') {
          updates.photoUrl = gravatarUrl;
        }
        
        batch.update(doc.ref, updates);
        updated++;
      }
    });
    
    await batch.commit();
    
    res.json({
      success: true,
      message: `Migration completed: ${updated} users updated, ${skipped} skipped`,
      updated,
      skipped,
    });
  } catch (error) {
    console.error('Migration error:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Firestore trigger to automatically add Gravatar URL when user is created/updated
 * This ensures all new users automatically get Gravatar URLs
 */
exports.onUserWrite = functions.firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    
    if (!after || !after.email) {
      return null;
    }
    
    // Only update if gravatarUrl is missing
    if (after.gravatarUrl) {
      return null;
    }
    
    const gravatarUrl = getGravatarUrl(after.email);
    
    if (!gravatarUrl) {
      return null;
    }
    
    const updates = {
      gravatarUrl: gravatarUrl,
    };
    
    // If no photoUrl, set it to Gravatar
    if (!after.photoUrl || after.photoUrl === '') {
      updates.photoUrl = gravatarUrl;
    }
    
    return change.after.ref.update(updates);
  });

/**
 * Callable function to refresh a user's Gravatar URL
 * Call from Flutter: FirebaseFunctions.instance.httpsCallable('refreshUserGravatar').call()
 */
exports.refreshUserGravatar = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  
  const userData = userDoc.data();
  const email = userData.email;
  
  if (!email) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'User has no email address'
    );
  }
  
  const gravatarUrl = getGravatarUrl(email);
  
  await userRef.update({
    gravatarUrl: gravatarUrl,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return {
    success: true,
    gravatarUrl: gravatarUrl,
  };
});

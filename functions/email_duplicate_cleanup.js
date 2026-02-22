// Firebase Cloud Function to find and report duplicate emails
// Add to functions/index.js or create a new file

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * HTTP Function to find duplicate emails in the users collection
 * Call: https://YOUR_PROJECT.cloudfunctions.net/findDuplicateEmails
 * 
 * Returns:
 * {
 *   duplicates: {
 *     "user@example.com": ["uid1", "uid2"],
 *     ...
 *   },
 *   count: 2,
 *   totalAffectedUsers: 4
 * }
 */
exports.findDuplicateEmails = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const usersSnapshot = await db.collection('users').get();
    
    const emailMap = new Map();
    
    // Build map of email -> array of user IDs
    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      const email = data.emailLowercase;
      
      if (email && email.trim() !== '') {
        if (!emailMap.has(email)) {
          emailMap.set(email, []);
        }
        emailMap.get(email).push({
          uid: doc.id,
          name: data.name || 'Unknown',
          role: data.role || 'unknown',
          createdAt: data.createdAt?.toDate?.() || null,
        });
      }
    });
    
    // Filter to only duplicates
    const duplicates = {};
    let totalAffectedUsers = 0;
    
    emailMap.forEach((users, email) => {
      if (users.length > 1) {
        duplicates[email] = users;
        totalAffectedUsers += users.length;
      }
    });
    
    res.json({
      success: true,
      duplicates,
      count: Object.keys(duplicates).length,
      totalAffectedUsers,
      message: Object.keys(duplicates).length === 0 
        ? 'No duplicate emails found! ✓' 
        : `Found ${Object.keys(duplicates).length} duplicate email(s) affecting ${totalAffectedUsers} users.`,
    });
  } catch (error) {
    console.error('Error finding duplicates:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Callable Function to resolve duplicate emails for the current user
 * Call from Flutter: FirebaseFunctions.instance.httpsCallable('resolveDuplicateEmail').call()
 * 
 * This function will:
 * 1. Find if the current user's email is used by other accounts
 * 2. Keep the oldest account with this email
 * 3. Clear the email from newer duplicate accounts
 */
exports.resolveDuplicateEmail = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const currentUserId = context.auth.uid;
  const db = admin.firestore();
  
  try {
    // Get current user's email
    const currentUserDoc = await db.collection('users').doc(currentUserId).get();
    const currentUserData = currentUserDoc.data();
    const email = currentUserData?.emailLowercase;
    
    if (!email) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'User has no email address'
      );
    }
    
    // Find all users with this email
    const duplicatesSnapshot = await db
      .collection('users')
      .where('emailLowercase', '==', email)
      .get();
    
    if (duplicatesSnapshot.size <= 1) {
      return {
        success: true,
        message: 'No duplicates found for your email',
        action: 'none',
      };
    }
    
    // Sort by creation date to find the oldest account
    const users = duplicatesSnapshot.docs.map(doc => ({
      id: doc.id,
      data: doc.data(),
      createdAt: doc.data().createdAt?.toDate?.() || new Date(0),
    })).sort((a, b) => a.createdAt - b.createdAt);
    
    const oldestUser = users[0];
    
    // If current user is the oldest, clear email from others
    if (oldestUser.id === currentUserId) {
      const batch = db.batch();
      
      for (let i = 1; i < users.length; i++) {
        const userRef = db.collection('users').doc(users[i].id);
        batch.update(userRef, {
          email: '',
          emailLowercase: '',
          emailConflictResolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      
      return {
        success: true,
        message: `Your account keeps the email. ${users.length - 1} other account(s) cleared.`,
        action: 'kept_email',
        affectedAccounts: users.length - 1,
      };
    } else {
      // Current user is not the oldest, clear their email
      await db.collection('users').doc(currentUserId).update({
        email: '',
        emailLowercase: '',
        emailConflictResolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        message: 'This email belongs to an older account. Your email has been cleared. Please update with a different email.',
        action: 'email_cleared',
        oldestAccountId: oldestUser.id,
      };
    }
  } catch (error) {
    console.error('Error resolving duplicate:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to resolve duplicate: ${error.message}`
    );
  }
});

/**
 * Admin function to clean up all duplicate emails
 * Requires admin authentication
 * Call: https://YOUR_PROJECT.cloudfunctions.net/adminCleanupDuplicateEmails?adminKey=YOUR_SECRET_KEY
 */
exports.adminCleanupDuplicateEmails = functions.https.onRequest(async (req, res) => {
  // Simple admin key check (replace with proper admin auth in production)
  const adminKey = req.query.adminKey;
  if (adminKey !== process.env.ADMIN_KEY) {
    res.status(403).json({ error: 'Unauthorized' });
    return;
  }
  
  try {
    const db = admin.firestore();
    const usersSnapshot = await db.collection('users').get();
    
    const emailMap = new Map();
    
    // Build map
    usersSnapshot.forEach((doc) => {
      const data = doc.data();
      const email = data.emailLowercase;
      
      if (email && email.trim() !== '') {
        if (!emailMap.has(email)) {
          emailMap.set(email, []);
        }
        emailMap.get(email).push({
          id: doc.id,
          createdAt: data.createdAt?.toDate?.() || new Date(0),
        });
      }
    });
    
    let clearedCount = 0;
    const batch = db.batch();
    
    // For each duplicate email, keep oldest and clear others
    emailMap.forEach((users, email) => {
      if (users.length > 1) {
        users.sort((a, b) => a.createdAt - b.createdAt);
        
        // Clear email from all except the oldest
        for (let i = 1; i < users.length; i++) {
          const userRef = db.collection('users').doc(users[i].id);
          batch.update(userRef, {
            email: '',
            emailLowercase: '',
            previousEmail: email,
            emailConflictResolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          clearedCount++;
        }
      }
    });
    
    if (clearedCount > 0) {
      await batch.commit();
    }
    
    res.json({
      success: true,
      message: `Cleaned up ${clearedCount} duplicate email(s)`,
      clearedCount,
      duplicateEmailsFound: emailMap.size,
    });
  } catch (error) {
    console.error('Error cleaning duplicates:', error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

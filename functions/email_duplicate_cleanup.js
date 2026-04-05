// Firebase Cloud Function to find and report duplicate emails
// Add to functions/index.js or create a new file

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

function parseBool(value, fallback = false) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  return ['1', 'true', 'yes', 'on'].includes(normalized);
}

function getSecurityConfig() {
  return {
    enforceAppCheck: parseBool(process.env.SECURITY_ENFORCE_APP_CHECK, true),
  };
}

function assertAdminCallableAuth(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required',
    );
  }

  const { enforceAppCheck } = getSecurityConfig();
  if (enforceAppCheck && !context.app) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'App Check token is required',
    );
  }

  if (!context.auth.token || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Admin access required',
    );
  }
}

async function rateLimitAdminOrThrow({ uid, action, limit = 2 }) {
  const now = new Date();
  const bucket = `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, '0')}${String(now.getUTCDate()).padStart(2, '0')}${String(now.getUTCHours()).padStart(2, '0')}${String(now.getUTCMinutes()).padStart(2, '0')}`;
  const safeAction = String(action || 'admin_action').trim().toLowerCase();
  const docId = `${safeAction}_${uid}_${bucket}`;
  const ref = admin.firestore().collection('_rateLimits').doc(docId);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? Number(snap.data()?.count || 0) : 0;
    if (current >= limit) {
      throw new functions.https.HttpsError('resource-exhausted', 'rate-limited');
    }
    tx.set(ref, {
      action: safeAction,
      uid,
      bucket,
      count: current + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: snap.exists ? snap.data().createdAt : admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + (24 * 60 * 60 * 1000))),
    }, { merge: true });
  });
}

/**
 * Admin callable to find duplicate emails
 */
exports.findDuplicateEmails = functions.https.onCall(async (data, context) => {
  assertAdminCallableAuth(context);
  await rateLimitAdminOrThrow({ uid: context.auth.uid, action: 'admin_find_duplicates' });

  const db = admin.firestore();
  const usersSnapshot = await db.collection('users').get();
  const emailMap = new Map();

  usersSnapshot.forEach((doc) => {
    const userData = doc.data();
    const email = userData.emailLowercase;

    if (email && email.trim() !== '') {
      if (!emailMap.has(email)) {
        emailMap.set(email, []);
      }
      emailMap.get(email).push({
        uid: doc.id,
        name: userData.name || 'Unknown',
        role: userData.role || 'unknown',
        createdAt: userData.createdAt?.toDate?.() || null,
      });
    }
  });

  const duplicates = {};
  let totalAffectedUsers = 0;

  emailMap.forEach((users, email) => {
    if (users.length > 1) {
      duplicates[email] = users;
      totalAffectedUsers += users.length;
    }
  });

  return {
    success: true,
    duplicates,
    count: Object.keys(duplicates).length,
    totalAffectedUsers,
    message: Object.keys(duplicates).length === 0
      ? 'No duplicate emails found! ✓'
      : `Found ${Object.keys(duplicates).length} duplicate email(s) affecting ${totalAffectedUsers} users.`,
  };
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
 * Admin callable to clean up duplicate emails
 * Requires Firebase Auth admin claim
 */
exports.adminCleanupDuplicateEmails = functions.https.onCall(async (data, context) => {
  assertAdminCallableAuth(context);
  await rateLimitAdminOrThrow({ uid: context.auth.uid, action: 'admin_cleanup_emails' });

  const db = admin.firestore();
  const usersSnapshot = await db.collection('users').get();
  const emailMap = new Map();

  usersSnapshot.forEach((doc) => {
    const userData = doc.data();
    const email = userData.emailLowercase;

    if (email && email.trim() !== '') {
      if (!emailMap.has(email)) {
        emailMap.set(email, []);
      }
      emailMap.get(email).push({
        id: doc.id,
        createdAt: userData.createdAt?.toDate?.() || new Date(0),
      });
    }
  });

  let clearedCount = 0;
  const batch = db.batch();

  emailMap.forEach((users, email) => {
    if (users.length > 1) {
      users.sort((a, b) => a.createdAt - b.createdAt);
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

  await db.collection('admin_audit_logs').add({
    action: 'admin_cleanup_duplicate_emails',
    adminId: context.auth.uid,
    targetId: 'users',
    newValue: {
      clearedCount,
      duplicateEmailsFound: emailMap.size,
    },
    reason: String(data?.reason || 'cleanup'),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    message: `Cleaned up ${clearedCount} duplicate email(s)`,
    clearedCount,
    duplicateEmailsFound: emailMap.size,
  };
});

# Email Uniqueness Fix - Testing & Deployment Guide

## Problem Fixed
**Issue**: Users could login with different email addresses but access the same account.

**Root Cause**: Firebase Authentication creates unique UIDs based on the authentication method (email/password, Google sign-in, etc.), but our app's Firestore database wasn't validating that email addresses are unique across different Firebase Auth accounts.

**Solution**: Added email uniqueness validation at the application level before creating/updating user documents in Firestore.

---

## Changes Made

### 1. **Authentication Service** (`auth_firebase_services.dart`)
- Added email uniqueness check in `_upsertAndMapUser()` method
- Before creating/updating user document, queries Firestore for existing email
- Throws `AuthException` if email belongs to different user account
- Email is normalized (lowercase + trimmed) for consistent comparison

### 2. **Email Validation Helper** (`email_validation_helper.dart`)
- New utility class for email operations
- Methods:
  - `findUserWithEmail()`: Search for user by email
  - `canUserUseEmail()`: Check if email is available for specific user
  - `findDuplicateEmails()`: Identify all duplicate emails in database
  - `isValidEmailFormat()`: Validate email format with regex
  - `normalizeEmail()`: Standardize email (lowercase + trim)

### 3. **Firestore Security Rules** (`firestore_email_rules.rules`)
- Server-side validation to enforce email uniqueness
- Prevents duplicate emails at database level
- Must be deployed to Firebase

### 4. **Cloud Functions** (`email_duplicate_cleanup.js`)
- `findDuplicateEmails`: HTTP function to identify duplicate emails
- `resolveDuplicateEmail`: Callable function for users to resolve conflicts
- `adminCleanupDuplicateEmails`: Admin function to bulk cleanup existing duplicates

---

## Testing Instructions

### Test 1: New User Registration
**Goal**: Verify different emails create separate accounts

1. **Sign up with Email A**
   - Register new user: `testuser1@example.com`
   - Note the user profile details you enter
   - Logout

2. **Sign up with Email B**
   - Register new user with different email: `testuser2@example.com`
   - Enter DIFFERENT profile details
   - Logout

3. **Verify Separate Accounts**
   - Login with `testuser1@example.com` - should see first profile
   - Logout, login with `testuser2@example.com` - should see second profile
   - Each should have separate data

**Expected**: ✅ Two completely separate accounts with different profiles

### Test 2: Email Already Registered
**Goal**: Verify duplicate email prevention

1. **Attempt Duplicate Registration**
   - Try to sign up with `testuser1@example.com` again
   - Should show error: "This email is already registered with another account"

**Expected**: ✅ Registration blocked with clear error message

### Test 3: Google Sign-In with Existing Email
**Goal**: Verify Google login doesn't create duplicate

1. **Sign up with Email**
   - Register: `myemail@gmail.com` via email/password

2. **Attempt Google Sign-In**
   - Try to login with Google using same `myemail@gmail.com`
   - Should show error: "This email is already registered with another account. Please use email/password login."

**Expected**: ✅ Google sign-in blocked, directed to use original method

### Test 4: Profile Email Change
**Goal**: Verify email uniqueness when updating profile

1. **Login as User 1**
   - Login with existing account

2. **Try to Change Email to Existing One**
   - Go to profile settings
   - Try to change email to another user's email
   - Should fail with error

**Expected**: ✅ Email update blocked if email already in use

---

## Deployment Steps

### Step 1: Deploy App Code
```bash
# Your Flutter app already has the fix
# Just build and deploy as normal
flutter clean
flutter pub get
flutter build apk  # or 'flutter build ios'
```

### Step 2: Deploy Firestore Rules
```bash
# Deploy the security rules to Firebase
firebase deploy --only firestore:rules
```

**Important**: Copy the rules from `firestore_email_rules.rules` and paste into your `firestore.rules` file before deploying.

### Step 3: Deploy Cloud Functions
```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Deploy the cleanup functions
firebase deploy --only functions
```

### Step 4: Check for Existing Duplicates
```bash
# Call the findDuplicateEmails function
# Replace YOUR_PROJECT with your Firebase project ID
curl https://us-central1-YOUR_PROJECT.cloudfunctions.net/findDuplicateEmails
```

**If duplicates found**, proceed to Step 5.

### Step 5: Cleanup Existing Duplicates (If Needed)
```bash
# Set admin key as environment variable in Firebase
firebase functions:config:set admin.key="YOUR_SECURE_RANDOM_KEY"

# Redeploy functions
firebase deploy --only functions

# Run cleanup (replace with your actual key)
curl "https://us-central1-YOUR_PROJECT.cloudfunctions.net/adminCleanupDuplicateEmails?adminKey=YOUR_SECURE_RANDOM_KEY"
```

---

## Database Schema
Each user document in `/users/{userId}` should have:

```json
{
  "uid": "firebase_auth_uid",
  "email": "user@example.com",
  "emailLowercase": "user@example.com",
  "name": "User Name",
  "role": "owner",
  "photoUrl": "https://...",
  "gravatarUrl": "https://gravatar.com/avatar/...",
  "createdAt": "timestamp",
  "emailConflictResolvedAt": "timestamp (if duplicate was resolved)"
}
```

---

## Troubleshooting

### Issue: "Email already registered" for legitimate user
**Cause**: Database might have duplicate emails from before the fix.

**Solution**:
1. Call `findDuplicateEmails` function to identify duplicates
2. Use `adminCleanupDuplicateEmails` to resolve automatically, OR
3. Manually resolve in Firebase Console:
   - Go to Firestore Database
   - Search for duplicate email
   - Keep the oldest user's email
   - Clear email field from newer users

### Issue: Users cannot change their email
**Cause**: Target email might already exist.

**Solution**: Tell user to choose a different email that isn't already registered.

### Issue: Google Sign-In users can't login after fix
**Cause**: Their Google email might match an existing email/password account.

**Check**: 
1. Look up their Google email in Firestore
2. Find which UID owns that email
3. Ask user to use that original authentication method

---

## Monitoring

### Check for New Duplicates
Run this periodically:
```bash
curl https://us-central1-YOUR_PROJECT.cloudfunctions.net/findDuplicateEmails
```

### User Reports Issue
1. Get their email from user
2. Query Firestore: `users` collection → where `emailLowercase == email`
3. Check how many documents returned
4. If multiples, use cleanup function

---

## Rollback Plan (If Issues Occur)

### Rollback Code
```bash
git revert HEAD
flutter pub get
flutter build apk
```

### Rollback Firestore Rules
1. Go to Firebase Console → Firestore → Rules
2. Click "Version History"
3. Restore previous version

### Keep Cloud Functions
The duplicate finder functions are read-only and won't cause issues.

---

## Future Improvements

1. **Add Email Verification**: Require email verification before allowing login
2. **Add Phone Number Uniqueness**: Similar validation for phone auth
3. **Better Error Messages**: More specific guidance for users on how to resolve conflicts
4. **Account Merging**: Allow users to merge duplicate accounts manually
5. **Audit Logging**: Track all email changes and conflict resolutions

---

## Support

If you encounter issues:
1. Check Firebase Console Logs for detailed errors
2. Review Cloud Functions logs for authentication failures
3. Use `email_validation_helper.dart` methods to debug
4. Check Firestore indexes if queries are slow

---

## Summary

✅ **Fixed**: Different emails no longer access same account  
✅ **Added**: Email uniqueness validation  
✅ **Added**: Firestore security rules  
✅ **Added**: Cleanup Cloud Functions  
✅ **Added**: Testing utilities  

**Next**: Test thoroughly → Deploy rules → Check for duplicates → Go live! 🚀

"""
╔════════════════════════════════════════════════════════════════╗
║  RENTDONE - OTP AUTHENTICATION IMPLEMENTATION GUIDE           ║
║  Complete Production-Ready Code                               ║
╚════════════════════════════════════════════════════════════════╝

📋 ARCHITECTURE OVERVIEW
─────────────────────────

Data Layer (Services):
├── auth_firebase_services.dart        ← Firebase Phone Auth
├── user_firestore_service.dart        ← User Data Persistence
└── firebase_auth_provider.dart        ← Riverpod Providers

Domain Layer (Business Logic):
├── validate_user_input.dart           ← Input Validation
└── entities/auth_user.dart            ← User Model

Presentation Layer (UI):
├── pages/login_screen.dart            ← OTP UI
├── providers/auth_notifier.dart       ← State Management
└── providers/auth_state.dart          ← State Definition

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔄 COMPLETE OTP FLOW
─────────────────────

STEP 1: User Opens Login Screen
   ↓
   State: AuthState.initial() {
     otpSent: false
     isLoading: false
     nameError: null
     phoneError: null
     otpError: null
   }

STEP 2: User Enters Phone & Name, Clicks "Send OTP"
   ↓
   Input Validation:
   ✓ Name not empty
   ✓ Phone format: +91XXXXXXXXXX (country code required)
   ✓ Phone length: 8-14 digits after country code
   
   If validation passes:
   ↓
   
STEP 3: Firebase Send OTP
   ↓
   AuthFirebaseService.sendOtp(phoneNumber)
   │
   ├─ WEB: Uses signInWithPhoneNumber
   │       Shows confirmation dialog
   │
   └─ MOBILE: Uses verifyPhoneNumber
             SMS sent automatically
             Auto-verification on Android (if enabled)
   
   ↓
   Firebase stores verification ID internally
   
STEP 4: OTP Sent Successfully
   ↓
   State: AuthState {
     otpSent: true           ← Switch to OTP input
     isLoading: false
     resendSeconds: 30       ← 30-second timer starts
   }
   
   UI Changes:
   ├─ Show OTP input boxes (6 digits)
   ├─ Show "Resend OTP" button (disabled for 30s)
   ├─ Show timer countdown
   └─ Disable name/phone fields

STEP 5: User Receives SMS
   ↓
   (In real scenario)
   SMS: "Your RentDone OTP is: 123456. Valid for 60 seconds."
   
   (In development with test numbers)
   SMS shows: 123456

STEP 6: User Enters OTP
   ↓
   OTP Input Widget handles:
   ✓ Auto-focus on next box
   ✓ Paste support (paste "123456" → auto-fills all boxes)
   ✓ Backspace support
   ✓ Auto-select last box → dismiss keyboard
   
   ↓

STEP 7: User Clicks "Verify OTP"
   ↓
   AuthNotifier.verifyOtp(otp: "123456")
   │
   ├─ Validate OTP format (6 digits)
   ├─ Call Firebase: signInWithCredential
   │
   └─ Firebase Returns:
       UserCredential {
         user: FirebaseUser {
           uid: "abc123xyz"
           phoneNumber: "+919876543210"
           ...
         }
       }

STEP 8: Create User in Firestore
   ↓
   UserFirestoreService.createOrUpdateUser(AuthUser)
   │
   └─ Firestore Document Created:
      users/{uid} = {
        uid: "abc123xyz"
        name: "John Doe"
        phone: "+919876543210"
        role: null (to be selected)
        createdAt: timestamp
        isProfileComplete: false
      }

STEP 9: Login Successful
   ↓
   State: AuthState {
     otpSent: false          ← Reset
     isLoading: false
     otpError: null
   }
   
   Auth State Stream emits: User(uid: "abc123xyz")
   
   UI Navigation:
   ├─ RoleSelectionScreen (owner/tenant)
   └─ After role: ProfileCompletionScreen

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️ ERROR HANDLING AT EACH STEP
──────────────────────────────

1. Invalid Phone Number
   Error: "Please enter a valid phone number" (starting with +)
   Recovery: Allow user to re-enter
   
2. Too Many Requests
   Error: "Too many attempts. Please wait before trying again."
   Recovery: Disable send button for 1 hour
   
3. Network Error
   Error: "No internet connection. Please check your network."
   Recovery: Show retry button
   
4. Verification ID Expired
   Error: "OTP expired. Please request a new one."
   Recovery: Auto-reset, show send OTP screen again
   
5. Invalid OTP
   Error: "Incorrect OTP. Please try again."
   Recovery: Allow user to re-enter or resend

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔐 STATE MANAGEMENT WITH RIVERPOD
──────────────────────────────────

Provider Definition:
   final authProvider = NotifierProvider<AuthNotifier, AuthState>((ref) {
     return AuthNotifier();
   });

Usage in Widget:
   final authState = ref.watch(authProvider);        // Listen to state
   final authNotifier = ref.read(authProvider.notifier);  // Call actions

Example:
   // Send OTP
   await authNotifier.sendOtp(phone, name: name);
   
   // Verify OTP
   await authNotifier.verifyOtp(otp);
   
   // Sign Out
   await authNotifier.signOut();

State Updates:
   ref.watch(authProvider) rebuilds widget on state change
   ref.read(authProvider.notifier) doesn't cause rebuild

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ SPECIAL FEATURES
────────────────────

1. Auto-Verification (Android)
   Firebase automatically:
   ├─ Reads incoming SMS
   ├─ Extracts OTP
   └─ Verifies instantly (if enabled)
   
   User doesn't need to type OTP!

2. Resend OTP with Timer
   ├─ User can't click resend for 30 seconds
   ├─ Timer counts down visually
   ├─ "Resend OTP" becomes "Resend (25s)"
   └─ Auto-clickable when timer reaches 0

3. Smart Phone Input
   ├─ Validates country code
   ├─ Formats: +91 9876543210 (add space for readability)
   ├─ Shows flag emoji from country code
   └─ Prevents invalid formats

4. Paste Support for OTP
   User can:
   ├─ Paste "123456" → auto-fills 6 boxes
   ├─ Use clipboard from SMS
   └─ Works on both iOS and Android

5. Session Expiry
   ├─ OTP valid for 60 seconds
   ├─ After 60s: "OTP expired. Please request new one."
   ├─ Verification ID auto-cleared
   └─ User must request new OTP

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 TESTING SCENARIOS
─────────────────────

Test Case 1: Happy Path
   Phone: +1 650-253-0000
   OTP: 123456
   Expected: Login success → Role selection

Test Case 2: Invalid Phone
   Phone: 9876543210 (no country code)
   Expected: Error "Enter valid phone number"

Test Case 3: Wrong OTP
   Phone: +1 650-253-0000
   OTP: 000000
   Expected: Error "Incorrect OTP"

Test Case 4: Expired OTP
   Phone: +1 650-253-0000
   OTP: (wait 61 seconds)
   Expected: Error "OTP expired"

Test Case 5: Network Offline
   Turn off WiFi/Mobile data
   Click "Send OTP"
   Expected: Error "No internet connection"

Test Case 6: Resend OTP
   Click "Send OTP"
   Wait 30 seconds
   Click "Resend OTP"
   Expected: New OTP sent successfully

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎨 UI COMPONENTS USED
──────────────────────

1. Name Input TextField
   ├─ Validation: Required
   ├─ Error display: Field error
   └─ Clear on send OTP

2. Phone Input TextField
   ├─ Country code selector: +91
   ├─ Placeholder: 9876543210
   ├─ Validation: 10+ digits
   └─ Format: +91 98765 43210

3. OTP Input (6 boxes)
   ├─ Size: 46x56 each
   ├─ Border: 1px gray (active: 2px blue)
   ├─ Font: TitleLarge
   ├─ Spacing: Between boxes
   └─ Auto-next focus

4. Send OTP Button
   ├─ Label: "Send OTP" (initially)
   ├─ Label: "Verify OTP" (after OTP sent)
   ├─ Disabled: false (respects validation)
   ├─ Loading: Shows spinner
   └─ Color: Primary blue

5. Resend OTP Button
   ├─ Label: "Resend OTP (30s)"
   ├─ Disabled: True for 30 seconds
   ├─ Updates: Every 1 second
   ├─ Color: Gray until available
   └─ Clickable: After timer expires

6. Error Messages
   ├─ Phone Error: Below phone field (Red)
   ├─ OTP Error: Below OTP boxes (Red)
   ├─ Name Error: Below name field (Red)
   ├─ General Error: SnackBar (Bottom)
   └─ Duration: 3-5 seconds

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 CUSTOMIZATION OPTIONS
─────────────────────────

To adjust OTP timeout:
   File: auth_firebase_services.dart
   Line: Duration timeout = const Duration(seconds: 60)
   Change: 60 to desired seconds

To adjust resend timer:
   File: auth_notifier.dart
   Line: resendSeconds: 30
   Change: 30 to desired seconds

To enable/disable auto-verification:
   Platform: Android only
   Already: Enabled by default in Firebase
   Manage: Firebase Console > Authentication

To change app name for SMS:
   Firebase Console > Project Settings
   Update: App Display Name

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 DEPLOYMENT CHECKLIST
──────────────────────

Before Going Live:
   ✓ Enable Phone Authentication in Firebase
   ✓ Remove test phone numbers
   ✓ Set all error messages to production text
   ✓ Test with real SMS on actual devices
   ✓ Set up Firebase Realtime Database rules
   ✓ Enable Firebase Cloud Messaging (optional)
   ✓ Set up app signing in Firebase
   ✓ Update privacy policy with OTP terms
   ✓ Test error handling scenarios
   ✓ Verify Firestore security rules

Performance:
   ✓ OTP send time: < 5 seconds
   ✓ OTP verify time: < 3 seconds
   ✓ Network requests cached when possible
   ✓ Database writes optimized

Security:
   ✓ Phone numbers never exposed
   ✓ OTP only used for 60 seconds
   ✓ Verification ID cleared after use
   ✓ Rate limiting enforced
   ✓ HTTPS only (automatic)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📞 TROUBLESHOOTING
──────────────────

Issue: OTP not received
   → Check internet connection
   → Verify phone number format: +91XXXXXXXXXX
   → Check Firebase console for errors
   → Try with test phone number first

Issue: Auto-verification not working
   → Ensure Google Play Services installed
   → Update Android to latest
   → May take 1-2 minutes after install

Issue: Firebase configuration error
   → Download google-services.json from Firebase
   → Place in: android/app/
   → Run: flutter clean && flutter pub get

Issue: State management issues
   → Clear app data
   → Rebuild: flutter clean && flutter pub get
   → Restart: flutter run

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ READY TO USE!
─────────────────

Your OTP authentication system is now:
   ✓ Fully implemented
   ✓ Production-ready
   ✓ Error handling included
   ✓ Security best practices applied
   ✓ User-friendly UI components
   ✓ Firestore integration complete

Just enable Phone Authentication in Firebase Console
and you're good to go!

Questions? Check FIREBASE_OTP_SETUP_GUIDE.md

"""

/**
 * 🔐 COMPLETE OTP AUTHENTICATION IMPLEMENTATION
 * Production-Ready Firebase Integration
 * 
 * This file shows how to integrate OTP authentication in your app.
 */

// ═══════════════════════════════════════════════════════════════
// 1. UPDATE YOUR LOGIN SCREEN (lib/features/auth/presentation/pages/login_screen.dart)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';
import 'package:rentdone/shared/widgets/otp_input.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final List<TextEditingController> otpControllers;
  late final List<FocusNode> otpFocusNodes;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    phoneController = TextEditingController();

    otpControllers = List.generate(6, (_) => TextEditingController());
    otpFocusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    for (final c in otpControllers) {
      c.dispose();
    }
    for (final f in otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getPhoneWithCountryCode() {
    final country = '+91'; // Default India
    final phone = phoneController.text.replaceAll(' ', '');
    
    if (phone.startsWith('+')) {
      return phone;
    }
    
    return '$country$phone';
  }

  String _getOTPCode() {
    return otpControllers.map((c) => c.text).join();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Title
              Center(
                child: Text(
                  state.otpSent ? 'Enter OTP' : 'Login with phone',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  state.otpSent
                      ? 'We sent a one-time password to your phone'
                      : 'We\'ll send you a one-time password',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ─────────────────────────────
              // NAME FIELD (Hidden after OTP sent)
              // ─────────────────────────────
              if (!state.otpSent) ...[
                TextFormField(
                  controller: nameController,
                  onChanged: (_) => notifier.clearErrors(),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Full name',
                    errorText: state.nameError,
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: colors.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─────────────────────────────
              // PHONE FIELD
              // ─────────────────────────────
              if (!state.otpSent)
                TextFormField(
                  controller: phoneController,
                  onChanged: (_) => notifier.clearErrors(),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Phone number',
                    hintText: 'XXXXXXXXXX',
                    prefix: Text('${state.countryFlag} ${state.countryCode} '),
                    errorText: state.phoneError,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    filled: true,
                    fillColor: colors.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                )
              else
                // Display phone number after OTP sent
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined),
                      const SizedBox(width: 12),
                      Text(
                        'Phone: ${state.countryFlag} ${_getPhoneWithCountryCode()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // Reset to phone entry
                          otpControllers.forEach((c) => c.clear());
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ─────────────────────────────
              // OTP INPUT (Show after OTP sent)
              // ─────────────────────────────
              if (state.otpSent) ...[
                OtpInput(
                  controllers: otpControllers,
                  focusNodes: otpFocusNodes,
                ),
                const SizedBox(height: 16),

                // OTP Error Message
                if (state.otpError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.otpError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
              ],

              // Phone Error Message
              if (state.phoneError != null && !state.otpSent)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(
                    state.phoneError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // ─────────────────────────────
              // MAIN ACTION BUTTON
              // ─────────────────────────────
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (!state.otpSent) {
                          // Send OTP
                          await notifier.sendOtp(
                            _getPhoneWithCountryCode(),
                            name: nameController.text,
                          );
                        } else {
                          // Verify OTP
                          await notifier.verifyOtp(_getOTPCode());
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colors.primary,
                  disabledBackgroundColor: colors.primary.withValues(alpha: 0.5),
                ),
                child: state.isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(colors.surfaceContainerHighest),
                        ),
                      )
                    : Text(
                        state.otpSent ? 'Verify OTP' : 'Send OTP',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // ─────────────────────────────
              // RESEND OTP BUTTON
              // ─────────────────────────────
              if (state.otpSent)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive OTP? ",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: state.resendSeconds > 0
                          ? null
                          : () async {
                              await notifier.resendOtp();
                            },
                      child: Text(
                        state.resendSeconds > 0
                            ? 'Resend (${state.resendSeconds}s)'
                            : 'Resend OTP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: state.resendSeconds > 0
                              ? colors.onSurface.withValues(alpha: 0.4)
                              : colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 2. ADD AUTH STATE PROVIDER STREAM
// ═══════════════════════════════════════════════════════════════

// The authStateProvider is already created in:
// lib/features/auth/data/services/firebase_auth_provider.dart
//
// To use it in your code (inside a ConsumerWidget):
//
// Example:
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final authStateAsync = ref.watch(authStateProvider);
//     
//     return authStateAsync.when(
//       data: (user) {
//         if (user != null) {
//           // User logged in
//           return HomeScreen();
//         } else {
//           // User logged out
//           return LoginPage();
//         }
//       },
//       loading: () => CircularProgressIndicator(),
//       error: (err, stack) => ErrorWidget(),
//     );
//   }

// ═══════════════════════════════════════════════════════════════
// 3. UPDATE MAIN.DART INITIALIZATION
// ═══════════════════════════════════════════════════════════════

// Update your main.dart with Firebase initialization:
//
// Example:
//   import 'package:firebase_core/firebase_core.dart';
//   import 'firebase/firebase_options.dart';
//   
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     
//     // Initialize Firebase
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//     
//     runApp(const RentDoneApp());
//   }

// ═══════════════════════════════════════════════════════════════
// 4. TESTING THE OTP FLOW
// ═══════════════════════════════════════════════════════════════

/*
TEST CASE: Complete OTP Flow
─────────────────────────────

1. Enter credentials:
   Name: Test User
   Phone: +1 650-253-0000 (test number)

2. Click "Send OTP"
   Expected: Loading spinner shows, then OTP input appears
   
3. Enter OTP:
   OTP: 123456 (test OTP for this number)
   
4. Click "Verify OTP"
   Expected: User created in Firestore, navigated to role selection
   
5. Verify in Firebase Console:
   → Authentication > Users (should see the phone number)
   → Firestore > users collection (should see user document)
*/

// ═══════════════════════════════════════════════════════════════
// 5. ERROR HANDLING EXAMPLES
// ═══════════════════════════════════════════════════════════════

/*
The implementation handles all these errors automatically:

┌─────────────────────────────────────────────────────┐
│ ERROR                          │ HANDLING            │
├─────────────────────────────────────────────────────┤
│ Invalid phone (no country code) │ Show field error    │
│ Empty name                       │ Show field error    │
│ Wrong OTP                        │ Show OTP error      │
│ OTP expired (60s passed)         │ Show error, allow   │
│                                  │ resend              │
│                                  │                     │
│ Too many requests (rate limit)   │ Disable for hour    │
│ No internet connection           │ Show error,         │
│                                  │ allow retry         │
│ Firebase not configured          │ Show error          │
└─────────────────────────────────────────────────────┘
*/

// ═══════════════════════════════════════════════════════════════
// 6. FLOW DIAGRAM
// ═══════════════════════════════════════════════════════════════

/*
┌─────────────────────────────────────────────────────────────┐
│                     LOGIN FLOW DIAGRAM                      │
└─────────────────────────────────────────────────────────────┘

 ┌──────────────────┐
 │  Login Screen    │
 │  (Phone + Name)  │
 └────────┬─────────┘
          │
          │ Click "Send OTP"
          ↓
 ┌──────────────────────────────┐
 │ AuthNotifier.sendOtp()       │
 │  ├─ Validate name            │
 │  ├─ Validate phone format    │
 │  └─ Firebase.verifyPhoneNum  │
 └────────┬─────────────────────┘
          │
          │ Firebase returns (verification ID)
          ↓
 ┌──────────────────────────────┐
 │ State: otpSent = true        │
 │ Show: OTP Input boxes        │
 │ Timer: 30 seconds resend     │
 └────────┬─────────────────────┘
          │
          │ User receives SMS with OTP
          │ User enters 6 digits
          │ Click "Verify OTP"
          ↓
 ┌──────────────────────────────┐
 │ AuthNotifier.verifyOtp()     │
 │  ├─ Validate OTP format      │
 │  └─ Firebase.signInWithCr... │
 └────────┬─────────────────────┘
          │
          │ Firebase returns UserCredential
          ↓
 ┌──────────────────────────────┐
 │ UserFirestoreService creates │
 │ user document in Firestore   │
 └────────┬─────────────────────┘
          │
          │ Auth state changes
          ↓
 ┌──────────────────────────────┐
 │ Navigate to Role Selection   │
 │ (owner / tenant)             │
 └──────────────────────────────┘
*/

// ═══════════════════════════════════════════════════════════════
// 7. DEBUGGING TIPS
// ═══════════════════════════════════════════════════════════════

/*
To debug OTP authentication:

1. Check Firebase Console:
   Authentication > Sign-in method > Phone
   Should be ENABLED ✓

2. Check Firestore:
   Firestore > Collections > users
   Should have user document after login ✓

3. Check Firebase logs:
   Firebase Console > Functions > Logs
   Look for any errors ✓

4. Check App logs:
   Run: flutter logs
   Filter for: "auth" or "firestore" ✓

5. Use test phone numbers:
   Firebase allows test numbers without real SMS
   Test: +1 650-253-0000
   OTP: 123456

6. Check network:
   Ensure internet connection is active
   Try on different WiFi ✓
*/

// ═══════════════════════════════════════════════════════════════
// COMPLETE! 🎉
// Your OTP authentication is now fully configured and ready!
// ═══════════════════════════════════════════════════════════════

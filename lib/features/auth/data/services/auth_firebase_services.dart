import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/core/services/gravatar_service.dart';
import 'package:rentdone/features/auth/data/models/auth_user_dto.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';

class AuthFirebaseService {
  static const Duration _authTimeout = Duration(seconds: 20);
  static const Duration _firestoreTimeout = Duration(seconds: 15);
  static const Duration _functionsTimeout = Duration(seconds: 10);

  AuthFirebaseService(
    this._auth,
    this._firestore,
    this._googleSignIn,
    this._functions,
  );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;
  String? _verificationId;
  bool _googleInitialized = false;

  Future<void> sendOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      if (kIsWeb) {
        final confirmationResult = await _withTimeout(
          _auth.signInWithPhoneNumber(phoneNumber),
          timeoutMessage: 'OTP request timed out. Please try again.',
        );
        _verificationId = confirmationResult.verificationId;
        return;
      }

      final completer = Completer<void>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete();
            }
          } on FirebaseAuthException catch (error) {
            if (!completer.isCompleted) {
              completer.completeError(_mapFirebaseException(error));
            }
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          if (!completer.isCompleted) {
            completer.completeError(_mapFirebaseException(error));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      await completer.future.timeout(
        timeout,
        onTimeout: () => throw const AuthException(
          message: 'OTP request timed out. Please try again.',
        ),
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<UserCredential> verifyOtp({required String otp}) async {
    try {
      final verificationId = _verificationId;
      if (verificationId == null) {
        throw const AuthException(
          message: 'OTP session expired. Please request again.',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      return await _withTimeout(
        _auth.signInWithCredential(credential),
        timeoutMessage: 'OTP verification timed out. Please try again.',
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(message: 'Invalid OTP. Please try again.');
    }
  }

  Future<AuthUser> signInWithGoogle({
    required UserRole selectedRole,
    required String phone,
  }) async {
    try {
      final validatedPhone = await _assertPhoneValidWithoutOtp(phone);
      UserCredential credential;

      if (kIsWeb) {
        credential = await _withTimeout(
          _auth.signInWithPopup(GoogleAuthProvider()),
          timeoutMessage: 'Google sign-in timed out. Please try again.',
        );
      } else {
        await _initializeGoogleSignInIfNeeded();
        final googleUser = await _withTimeout(
          _googleSignIn.authenticate(),
          timeoutMessage: 'Google sign-in timed out. Please try again.',
        );

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(
            message:
                'Google Sign-In is not fully configured. Ensure SHA-1/SHA-256 fingerprints are added in Firebase Console and Google Sign-In is enabled.',
          );
        }
        final authCredential = GoogleAuthProvider.credential(idToken: idToken);

        credential = await _withTimeout(
          _auth.signInWithCredential(authCredential),
          timeoutMessage: 'Google sign-in timed out. Please try again.',
        );
      }

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Authentication failed. Please try again.',
        );
      }

      return _upsertAndMapUser(
        user: user,
        selectedRole: selectedRole,
        phone: validatedPhone,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } on GoogleSignInException catch (error) {
      if (error.code.name == 'canceled') {
        throw const AuthException(message: 'Google sign-in was cancelled.');
      }
      throw AuthException(
        message:
            error.description ?? 'Unable to sign in with Google right now.',
      );
    } on PlatformException catch (e) {
      if (e.message?.contains('serverClientId') == true) {
        throw const AuthException(
          message:
              'Google Sign-In is not configured for this app. Please contact support.',
        );
      }
      throw AuthException(
        message: e.message ?? 'Unable to sign in with Google right now.',
      );
    } catch (_) {
      throw const AuthException(
        message: 'Unable to sign in with Google right now.',
      );
    }
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) async {
    try {
      final validatedPhone = await _assertPhoneValidWithoutOtp(phone);
      final normalizedEmail = email.trim().toLowerCase();
      _assertEmailPasswordInputs(
        email: normalizedEmail,
        password: password,
      );
      final credential = await _withTimeout(
        _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        ),
        timeoutMessage: 'Sign in timed out. Please try again.',
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Authentication failed. Please try again.',
        );
      }

      final existingProfile = await _ensureExistingProfileForSignedInUser(
        user: user,
        selectedRole: selectedRole,
        phone: validatedPhone,
      );

      if (!user.emailVerified) {
        await _sendEmailVerificationIfNeeded(
          user: user,
          existingProfile: existingProfile,
        );
        await _safeSignOut();
        throw const AuthException(
          message:
              'Email not verified. A verification link has been sent. Check inbox/spam, open the link, then sign in.',
        );
      }

      return _upsertAndMapUser(
        user: user,
        selectedRole: selectedRole,
        phone: validatedPhone,
        allowAutoProvision: false,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(message: 'Unable to sign in with email.');
    }
  }

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) async {
    try {
      final validatedPhone = await _assertPhoneValidWithoutOtp(phone);
      final normalizedEmail = email.trim().toLowerCase();
      _assertEmailPasswordInputs(
        email: normalizedEmail,
        password: password,
      );
      final credential = await _withTimeout(
        _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        ),
        timeoutMessage: 'Account creation timed out. Please try again.',
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Account creation failed. Please try again.',
        );
      }

      // Production flow: create account and dispatch verification link.
      // Access to protected app routes is still blocked by router until verified.
      if (!user.emailVerified) {
        try {
          await _withTimeout(
            user.sendEmailVerification(),
            timeoutMessage: 'Verification email request timed out.',
          );
        } catch (_) {
          // Do not fail account creation because of transient mail send issues.
        }
      }

      return _upsertAndMapUser(
        user: user,
        selectedRole: selectedRole,
        phone: validatedPhone,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(message: 'Unable to create account.');
    }
  }

  Future<UserRole?> getUserRole(String uid) async {
    try {
      final doc = await _withTimeout(
        _firestore.collection('users').doc(uid).get(),
        timeout: _firestoreTimeout,
        timeoutMessage: 'Unable to load account role right now.',
      );
      final data = doc.data();
      if (data == null) return null;
      return UserRoleX.tryParse(data['role'] as String?);
    } catch (_) {
      return null;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthException(message: 'Please sign in again.');
      }

      final currentPasswordText = currentPassword.trim();
      final newPasswordText = newPassword.trim();

      if (currentPasswordText.isEmpty) {
        throw const AuthException(message: 'Current password is required.');
      }

      if (newPasswordText.length < 6) {
        throw const AuthException(
          message: 'New password must be at least 6 characters.',
        );
      }

      if (currentPasswordText == newPasswordText) {
        throw const AuthException(
          message: 'New password must be different from current password.',
        );
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        throw const AuthException(
          message: 'Password change is available only for email accounts.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPasswordText,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPasswordText);
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(
        message: 'Unable to change password right now.',
      );
    }
  }

  Future<void> sendPasswordResetCode({String? email}) async {
    try {
      final resolvedEmail = (email ?? _auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();

      if (resolvedEmail.isEmpty) {
        throw const AuthException(
          message: 'Email is required to send a reset code.',
        );
      }

      final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      );
      if (!emailRegex.hasMatch(resolvedEmail)) {
        throw const AuthException(message: 'Please enter a valid email.');
      }

      await _withTimeout(
        _auth.sendPasswordResetEmail(email: resolvedEmail),
        timeoutMessage: 'Password reset request timed out. Please try again.',
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(
        message: 'Unable to send reset code right now.',
      );
    }
  }

  Future<void> signOut() async {
    await _safeSignOut();
  }

  User? get currentUser => _auth.currentUser;

  Future<AuthUser> _upsertAndMapUser({
    required User user,
    required UserRole selectedRole,
    required String phone,
    bool allowAutoProvision = true,
  }) async {
    final userEmail = user.email ?? '';
    final normalizedEmail = userEmail.toLowerCase().trim();

    // Check if this email is already used by a different account
    if (normalizedEmail.isNotEmpty) {
      final emailQuery = await _withTimeout(
        _firestore
            .collection('users')
            .where('emailLowercase', isEqualTo: normalizedEmail)
            .limit(1)
            .get(),
        timeout: _firestoreTimeout,
        timeoutMessage: 'Unable to validate account email right now.',
      );

      if (emailQuery.docs.isNotEmpty) {
        final existingUserId = emailQuery.docs.first.id;
        if (existingUserId != user.uid) {
          await _safeSignOut();
          throw AuthException(
            message:
                'This email is already registered with another account. Please use a different email or sign in to the existing account.',
          );
        }
      }
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await _withTimeout(
      docRef.get(),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to load account profile right now.',
    );
    final data = snapshot.data();
    final existingRole = UserRoleX.tryParse(data?['role'] as String?);

    if (!snapshot.exists && !allowAutoProvision) {
      throw const AuthException(
        message:
            'This account is not provisioned yet. Please contact support.',
      );
    }

    // SECURITY: If user already has a role, they cannot change it
    if (existingRole != null) {
      if (existingRole != selectedRole) {
        await _safeSignOut();
        throw AuthException(
          message:
              'This account is registered as ${existingRole.label}. '
              'Your role cannot be changed. Please continue as ${existingRole.label}.',
        );
      }
      // Role is already set and matches, continue with existing role
    }

    final roleToPersist = existingRole ?? selectedRole;
    final normalizedPhone = phone.trim();
    final existingPhone = (data?['phone'] as String? ?? '').trim();
    final phoneToPersist = normalizedPhone.isNotEmpty
        ? normalizedPhone
        : existingPhone;
    final now = FieldValue.serverTimestamp();

    // Generate Gravatar URL from email
    final gravatarUrl = GravatarService.getGravatarUrlWithFallback(
      userEmail,
      size: 400,
      fallbackType: 'identicon',
    );

    // SECURITY: role field is set once and never changed by client
    await _withTimeout(
      docRef.set({
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'emailLowercase': normalizedEmail,
        'photoUrl': user.photoURL ?? gravatarUrl,
        'gravatarUrl': gravatarUrl,
        'phone': phoneToPersist,
        'role': roleToPersist.value, // ← Immutable after first set
        'notifications': {'rent_due': true, 'payment_received': true},
        'updatedAt': now,
        if (!snapshot.exists) 'createdAt': now,
        'lastLoginAt': now,
      }, SetOptions(merge: true)),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to save account profile right now.',
    );

    final dto = AuthUserDto.fromFirebaseUser(user);
    return AuthUser(
      uid: dto.uid,
      name: dto.name,
      email: dto.email,
      phone: phoneToPersist,
      role: roleToPersist.value,
      createdAt: dto.createdAt,
      lastLoginAt: dto.lastLoginAt,
      isProfileComplete: true,
    );
  }

  Future<void> _initializeGoogleSignInIfNeeded() async {
    if (_googleInitialized) return;
    await _withTimeout(
      _googleSignIn.initialize(
        serverClientId:
            '35844123331-ut1le47rn4bc62ev8q1461m8bhboikrd.apps.googleusercontent.com',
      ),
      timeoutMessage: 'Google sign-in initialization timed out.',
    );
    _googleInitialized = true;
  }

  Future<String> _assertPhoneValidWithoutOtp(String phone) async {
    final localPhone = _normalizeIndianPhone(phone);
    if (localPhone == null) {
      throw const AuthException(
        message: 'Enter a valid Indian mobile number.',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'validateIndianPhoneNoOtp',
        options: HttpsCallableOptions(timeout: _functionsTimeout),
      );

      final result = await _withTimeout(
        callable.call(<String, dynamic>{'phoneNumber': localPhone}),
        timeout: _functionsTimeout,
        timeoutMessage: 'Phone validation timed out.',
      );

      final data = result.data;
      if (data is Map) {
        final backendValid = data['valid'] == true;
        final backendLocal = (data['localPhone'] ?? '').toString().trim();
        if (backendValid && _normalizeIndianPhone(backendLocal) != null) {
          return backendLocal;
        }
      }

      throw const AuthException(
        message: 'Phone number validation failed. Please try again.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') {
        throw AuthException(
          message:
              (error.message?.trim().isNotEmpty ?? false)
              ? error.message!.trim()
              : 'Enter a valid Indian mobile number.',
        );
      }

      // Graceful fallback for transient backend issues.
      return localPhone;
    } on TimeoutException {
      return localPhone;
    } catch (_) {
      return localPhone;
    }
  }

  String? _normalizeIndianPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(local)) {
        return local;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _ensureExistingProfileForSignedInUser({
    required User user,
    required UserRole selectedRole,
    required String phone,
  }) async {
    final normalizedEmail = (user.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const AuthException(
        message: 'Email is required for sign in.',
      );
    }

    final uidDocRef = _firestore.collection('users').doc(user.uid);
    final uidDoc = await _withTimeout(
      uidDocRef.get(),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to load account profile right now.',
    );

    if (uidDoc.exists) {
      final data = uidDoc.data() ?? <String, dynamic>{};
      final existingRole = UserRoleX.tryParse(data['role'] as String?);
      if (existingRole != null && existingRole != selectedRole) {
        await _safeSignOut();
        throw AuthException(
          message:
              'This email is registered as ${existingRole.label}. Please continue with ${existingRole.label}.',
        );
      }
      return data;
    }

    final legacyQuery = await _withTimeout(
      _firestore
          .collection('users')
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get(),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to load account profile right now.',
    );

    DocumentSnapshot<Map<String, dynamic>>? legacyDoc;
    if (legacyQuery.docs.isNotEmpty) {
      legacyDoc = legacyQuery.docs.first;
    } else {
      final directQuery = await _withTimeout(
        _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get(),
        timeout: _firestoreTimeout,
        timeoutMessage: 'Unable to load account profile right now.',
      );
      if (directQuery.docs.isNotEmpty) {
        legacyDoc = directQuery.docs.first;
      }
    }

    if (legacyDoc == null) {
      await _safeSignOut();
      throw const AuthException(
        message:
            'No existing account found for this email. Please sign up first.',
      );
    }

    final legacyData = legacyDoc.data() ?? <String, dynamic>{};
    final existingRole = UserRoleX.tryParse(legacyData['role'] as String?);
    if (existingRole != null && existingRole != selectedRole) {
      await _safeSignOut();
      throw AuthException(
        message:
            'This email is registered as ${existingRole.label}. Please continue with ${existingRole.label}.',
      );
    }

    final normalizedPhone = phone.trim();

    await _withTimeout(
      uidDocRef.set({
        ...legacyData,
        'uid': user.uid,
        'email': user.email,
        'emailLowercase': normalizedEmail,
        'phone': normalizedPhone.isNotEmpty
            ? normalizedPhone
            : (legacyData['phone'] ?? ''),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to save account profile right now.',
    );

    final refreshedProfile = await _withTimeout(
      uidDocRef.get(),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to load account profile right now.',
    );

    return refreshedProfile.data() ?? <String, dynamic>{};
  }

  Future<void> _sendEmailVerificationIfNeeded({
    required User user,
    required Map<String, dynamic> existingProfile,
  }) async {
    final now = DateTime.now();
    final rawLastSent = existingProfile['emailVerificationSentAt'];
    DateTime? lastSent;
    if (rawLastSent is Timestamp) {
      lastSent = rawLastSent.toDate();
    }

    final shouldSend =
        lastSent == null || now.difference(lastSent).inSeconds > 60;
    if (!shouldSend) {
      return;
    }

    await _withTimeout(
      user.sendEmailVerification(),
      timeoutMessage: 'Verification email request timed out.',
    );

    await _withTimeout(
      _firestore.collection('users').doc(user.uid).set({
        'emailVerificationSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      timeout: _firestoreTimeout,
      timeoutMessage: 'Unable to update verification status right now.',
    );
  }

  Future<T> _withTimeout<T>(
    Future<T> future, {
    Duration timeout = _authTimeout,
    String? timeoutMessage,
  }) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      throw AuthException(
        message:
            timeoutMessage ?? 'Request timed out. Please check connection and retry.',
      );
    }
  }

  void _assertEmailPasswordInputs({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (normalizedEmail.isEmpty || !emailRegex.hasMatch(normalizedEmail)) {
      throw const AuthException(message: 'Please enter a valid email.');
    }
    if (password.length < 6) {
      throw const AuthException(
        message: 'Password is too weak. Use at least 6 characters.',
      );
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Best effort sign-out; do not block auth recovery paths.
    }
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Best effort sign-out for Google session.
      }
    }
  }

  AuthException _mapFirebaseException(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return const AuthException(
          message: 'The phone number entered is invalid.',
        );
      case 'too-many-requests':
        return const AuthException(
          message: 'Too many attempts. Please wait before trying again.',
        );
      case 'session-expired':
        return const AuthException(
          message: 'OTP expired. Please request a new one.',
        );
      case 'invalid-verification-code':
        return const AuthException(message: 'Incorrect OTP. Please try again.');
      case 'network-request-failed':
        return const AuthException(message: 'No internet connection.');
      case 'account-exists-with-different-credential':
        return const AuthException(
          message: 'Account already exists with another sign-in method.',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException(message: 'Invalid email or password.');
      case 'user-not-found':
        return const AuthException(message: 'No account found for this email.');
      case 'email-already-in-use':
        return const AuthException(message: 'Email is already in use.');
      case 'weak-password':
        return const AuthException(
          message: 'Password is too weak. Use at least 6 characters.',
        );
      case 'invalid-email':
        return const AuthException(message: 'Please enter a valid email.');
      case 'operation-not-allowed':
        return const AuthException(
          message:
              'Email/password sign-in is disabled in Firebase. Enable it from Firebase Console > Authentication > Sign-in method.',
        );
      case 'requires-recent-login':
        return const AuthException(
          message: 'Please sign in again to continue this sensitive action.',
        );
      case 'credential-already-in-use':
        return const AuthException(
          message:
              'This credential is already linked to another account. Use that account to continue.',
        );
      case 'provider-already-linked':
        return const AuthException(
          message: 'This sign-in method is already linked to your account.',
        );
      case 'user-token-expired':
        return const AuthException(
          message: 'Your session expired. Please sign in again.',
        );
      case 'expired-action-code':
      case 'invalid-action-code':
        return const AuthException(
          message:
              'This verification link is invalid or expired. Request a new link and try again.',
        );
      case 'quota-exceeded':
        return const AuthException(
          message: 'Too many requests. Please wait and try again later.',
        );
      case 'user-disabled':
        return const AuthException(
          message: 'This account has been disabled. Contact support.',
        );
      default:
        return AuthException(
          message: error.message ?? 'Authentication failed.',
        );
    }
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException({required this.message});

  @override
  String toString() => message;
}

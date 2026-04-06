import 'dart:async';

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
  AuthFirebaseService(this._auth, this._firestore, this._googleSignIn);

  static const int _minPasswordLength = 12;
  static const Duration _passwordResetCooldown = Duration(seconds: 60);
  static const String _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
  static final Map<String, DateTime> _lastPasswordResetByEmail =
      <String, DateTime>{};

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  String? _verificationId;
  bool _googleInitialized = false;

  Future<void> sendOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      if (kIsWeb) {
        final confirmationResult = await _auth.signInWithPhoneNumber(
          phoneNumber,
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

      await completer.future;
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

      return await _auth.signInWithCredential(credential);
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
      UserCredential credential;

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _initializeGoogleSignInIfNeeded();
        final googleUser = await _googleSignIn.authenticate();

        final googleAuth = googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(
            message:
                'Google Sign-In is not fully configured. Ensure SHA-1/SHA-256 fingerprints are added in Firebase Console and Google Sign-In is enabled.',
          );
        }
        final authCredential = GoogleAuthProvider.credential(idToken: idToken);

        credential = await _auth.signInWithCredential(authCredential);
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
        phone: phone,
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
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Authentication failed. Please try again.',
        );
      }

      return _upsertAndMapUser(
        user: user,
        selectedRole: selectedRole,
        phone: phone,
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
      final normalizedPassword = password.trim();
      if (normalizedPassword.length < _minPasswordLength) {
        throw const AuthException(
          message: 'Password must be at least 12 characters.',
        );
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: normalizedPassword,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Account creation failed. Please try again.',
        );
      }

      // Trigger email verification for all email/password signups.
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }

      return _upsertAndMapUser(
        user: user,
        selectedRole: selectedRole,
        phone: phone,
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
      final doc = await _firestore.collection('users').doc(uid).get();
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

      if (newPasswordText.length < _minPasswordLength) {
        throw const AuthException(
          message: 'New password must be at least 12 characters.',
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
      final currentUserEmail = (_auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      final resolvedEmail = (email ?? currentUserEmail).trim().toLowerCase();

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

      // Prevent authenticated users from requesting reset links for other emails.
      if (currentUserEmail.isNotEmpty && resolvedEmail != currentUserEmail) {
        throw const AuthException(
          message:
              'Password reset is allowed only for your signed-in account email.',
        );
      }

      final lastRequestedAt = _lastPasswordResetByEmail[resolvedEmail];
      if (lastRequestedAt != null) {
        final elapsed = DateTime.now().difference(lastRequestedAt);
        if (elapsed < _passwordResetCooldown) {
          final waitSeconds = (_passwordResetCooldown - elapsed).inSeconds
              .clamp(1, 999);
          throw AuthException(
            message:
                'Please wait $waitSeconds seconds before requesting another reset email.',
          );
        }
      }

      await _auth.sendPasswordResetEmail(email: resolvedEmail);
      _lastPasswordResetByEmail[resolvedEmail] = DateTime.now();
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
    await _auth.signOut();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }

  User? get currentUser => _auth.currentUser;

  Future<AuthUser> _upsertAndMapUser({
    required User user,
    required UserRole selectedRole,
    required String phone,
  }) async {
    final userEmail = user.email ?? '';
    final normalizedEmail = userEmail.toLowerCase().trim();

    // Check if this email is already used by a different account
    if (normalizedEmail.isNotEmpty) {
      final emailQuery = await _firestore
          .collection('users')
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        final existingUserId = emailQuery.docs.first.id;
        if (existingUserId != user.uid) {
          throw AuthException(
            message:
                'This email is already registered with another account. Please use a different email or sign in to the existing account.',
          );
        }
      }
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final existingRole = UserRoleX.tryParse(data?['role'] as String?);

    // SECURITY: If user already has a role, they cannot change it
    if (existingRole != null) {
      if (existingRole != selectedRole) {
        throw AuthException(
          message:
              'This account is registered as ${existingRole.label}. '
              'Your role cannot be changed. Please continue as ${existingRole.label}.',
        );
      }
      // Role is already set and matches, continue with existing role
    } else {
      // SECURITY: New user - role is determined by signup flow, NOT client choice
      // In production: Backend service should determine role based on business logic
      // For now, enforce that role can only be 'tenant' on first signup
      // Owners should be created via invitation or backend admin
      if (selectedRole != UserRole.tenant) {
        throw AuthException(
          message:
              'New accounts must register as tenants. '
              'Contact support to become an owner.',
        );
      }
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
    await docRef.set({
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
    }, SetOptions(merge: true));

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
    final hasClientId = _googleServerClientId.trim().isNotEmpty;
    if (hasClientId) {
      await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    } else {
      await _googleSignIn.initialize();
    }
    _googleInitialized = true;
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
      case 'user-not-found':
      case 'invalid-login-credentials':
        return const AuthException(message: 'Invalid email or password.');
      case 'email-already-in-use':
        return const AuthException(
          message:
              'Unable to create account with those credentials. Try signing in instead.',
        );
      case 'weak-password':
        return const AuthException(
          message: 'Password is too weak. Use at least 12 characters.',
        );
      case 'invalid-email':
        return const AuthException(message: 'Please enter a valid email.');
      case 'operation-not-allowed':
        return const AuthException(
          message:
              'Email/password sign-in is disabled in Firebase. Enable it from Firebase Console > Authentication > Sign-in method.',
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

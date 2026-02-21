import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/data/models/auth_user_dto.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';

class AuthFirebaseService {
  AuthFirebaseService(this._auth, this._firestore, this._googleSignIn);

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
        if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
          throw const AuthException(
            message:
                'Google Sign-In is not fully configured for this app. Add correct SHA fingerprint and Web client ID in Firebase.',
          );
        }
        final authCredential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

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
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Account creation failed. Please try again.',
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
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final existingRole = UserRoleX.tryParse(data?['role'] as String?);

    if (existingRole != null && existingRole != selectedRole) {
      throw AuthException(
        message:
            'This account is registered as ${existingRole.label}. Please continue as ${existingRole.label}.',
      );
    }

    final roleToPersist = existingRole ?? selectedRole;
    final normalizedPhone = phone.trim();
    final now = FieldValue.serverTimestamp();

    await docRef.set({
      'uid': user.uid,
      'name': user.displayName,
      'email': user.email,
      'phone': normalizedPhone,
      'role': roleToPersist.value,
      'isProfileComplete': true,
      'updatedAt': now,
      if (!snapshot.exists) 'createdAt': now,
      'lastLoginAt': now,
    }, SetOptions(merge: true));

    final dto = AuthUserDto.fromFirebaseUser(user);
    return AuthUser(
      uid: dto.uid,
      name: dto.name,
      email: dto.email,
      phone: normalizedPhone,
      role: roleToPersist.value,
      createdAt: dto.createdAt,
      lastLoginAt: dto.lastLoginAt,
      isProfileComplete: true,
    );
  }

  Future<void> _initializeGoogleSignInIfNeeded() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
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

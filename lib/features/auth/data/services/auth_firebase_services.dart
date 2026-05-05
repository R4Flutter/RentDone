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

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  String? _verificationId;

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

  Future<UserCredential> verifyOtp({
    required String otp,
    UserRole? selectedRole,
    String? phone,
  }) async {
    try {
      final verificationId = _verificationId;
      if (verificationId == null) {
        throw const AuthException(
          message: 'Session expired. Please request OTP again.',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Ensure user doc exists for phone auth users
      if (userCredential.user != null) {
        await _upsertAndMapUser(
          user: userCredential.user!,
          selectedRole: selectedRole ?? UserRole.tenant,
          phone: phone ?? '',
        );
      }

      return userCredential;
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
        // Force account picker by signing out first if already signed in
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
        
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthException(message: 'Google sign-in was cancelled.');
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(
            message:
                'Google Sign-In is not fully configured. Ensure SHA-1/SHA-256 fingerprints are added in Firebase Console and Google Sign-In is enabled.',
          );
        }
        final authCredential = GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: googleAuth.accessToken,
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
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw const AuthException(message: 'Google sign-in was cancelled.');
      }
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

      // Fix: Immediately create user doc to satisfy security rules and ensure role existence.
      // Rules depend on /users/{userId} existing for role-based access.
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'emailLowercase': email.trim().toLowerCase(),
        'role': selectedRole.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

      await _auth.sendPasswordResetEmail(email: resolvedEmail);
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
      try {
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
      } catch (e) {
        if (e is AuthException) rethrow;
        // Ignore firestore errors if it's just a permission check failure on search
        debugPrint('Email uniqueness check skipped: $e');
      }
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    DocumentSnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await docRef.get();
    } catch (e) {
      debugPrint('Error fetching user doc: $e');
    }
    
    final data = snapshot?.data();
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
      // SECURITY: New user - role is determined by signup flow.
      if (selectedRole != UserRole.tenant && selectedRole != UserRole.owner) {
        throw AuthException(
          message: 'Invalid role selected. Please choose Owner or Tenant.',
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

    final userData = {
      'uid': user.uid,
      'name': user.displayName ?? (data?['name'] as String?),
      'email': user.email ?? (data?['email'] as String?),
      'emailLowercase': normalizedEmail.isNotEmpty ? normalizedEmail : (data?['emailLowercase'] as String?),
      'photoUrl': user.photoURL ?? (data?['photoUrl'] as String?) ?? gravatarUrl,
      'gravatarUrl': gravatarUrl,
      'phone': phoneToPersist,
      'role': roleToPersist.value, // Immutable after first set
      'notifications': data?['notifications'] ?? {'rent_due': true, 'payment_received': true},
      'updatedAt': now,
      'lastLoginAt': now,
    };

    if (snapshot == null || !snapshot.exists) {
      userData['createdAt'] = now;
    }

    // SECURITY: role field is set once and never changed by client
    await docRef.set(userData, SetOptions(merge: true));

    final dto = AuthUserDto.fromFirebaseUser(user);
    return AuthUser(
      uid: dto.uid,
      name: userData['name'] as String? ?? dto.name,
      email: userData['email'] as String? ?? dto.email,
      phone: phoneToPersist,
      role: roleToPersist.value,
      createdAt: dto.createdAt,
      lastLoginAt: DateTime.now(),
      isProfileComplete: true,
    );
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

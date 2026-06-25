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

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _phoneDigitsRegex = RegExp(r'^[6-9]\d{9}$');

  String _sanitizeEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.length > 254) {
      throw const AuthException(message: 'Email address is too long.');
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      throw const AuthException(message: 'Enter a valid email address.');
    }
    return trimmed;
  }

  String _sanitizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length < 10 || digits.length > 15) {
      throw const AuthException(message: 'Enter a valid phone number.');
    }
    if (!_phoneDigitsRegex.hasMatch(digits) && digits.length == 10) {
      throw const AuthException(
        message: 'Enter a valid Indian mobile number.',
      );
    }
    return digits;
  }

  String _sanitizePassword(String password) {
    if (password.isEmpty) {
      throw const AuthException(message: 'Password is required.');
    }
    if (password.length < 6) {
      throw const AuthException(
        message: 'Password must be at least 6 characters.',
      );
    }
    if (password.length > 128) {
      throw const AuthException(
        message: 'Password is too long. Maximum 128 characters.',
      );
    }
    return password;
  }

  void _validateRole(UserRole role) {
    if (role != UserRole.tenant && role != UserRole.owner) {
      throw const AuthException(
        message: 'Invalid role. Please choose Owner or Tenant.',
      );
    }
  }

  Future<void> sendOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final sanitizedPhone = phoneNumber.trim();
    if (sanitizedPhone.isEmpty || sanitizedPhone.length < 10) {
      throw const AuthException(message: 'Enter a valid phone number.');
    }
    try {
      if (kIsWeb) {
        final confirmationResult = await _auth.signInWithPhoneNumber(
          sanitizedPhone,
        );
        _verificationId = confirmationResult.verificationId;
        return;
      }

      final completer = Completer<void>();

      await _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhone,
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

      final sanitizedOtp = otp.trim();
      if (sanitizedOtp.isEmpty || sanitizedOtp.length > 6 || !RegExp(r'^\d+$').hasMatch(sanitizedOtp)) {
        throw const AuthException(message: 'Invalid OTP format.');
      }

      final sanitizedPhone = phone != null ? _sanitizePhone(phone) : '';

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: sanitizedOtp,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _upsertAndMapUser(
          user: userCredential.user!,
          selectedRole: selectedRole ?? UserRole.tenant,
          phone: sanitizedPhone,
        );
      }

      return userCredential;
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
    _validateRole(selectedRole);
    final sanitizedPhone = _sanitizePhone(phone);
    try {
      UserCredential credential;

      if (kIsWeb) {
        // Sign out any existing Firebase session first
        await _auth.signOut();
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        // Always force the Google account picker by signing out + disconnecting.
        // This prevents the cached account (e.g. naikraj116@gmail.com) from
        // being silently reused when the user wants to switch accounts.
        try {
          await _googleSignIn.signOut();
          await _googleSignIn.disconnect();
        } catch (_) {
          // disconnect() throws if no account is cached — safe to ignore.
        }
        // Also sign out of Firebase so the router doesn't redirect prematurely
        // to the previous user's dashboard while the picker is open.
        await _auth.signOut();

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
        phone: sanitizedPhone,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        throw const AuthException(message: 'Google sign-in was cancelled.');
      }
      throw const AuthException(
        message: 'Unable to sign in with Google right now.',
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
    _validateRole(selectedRole);
    final sanitizedEmail = _sanitizeEmail(email);
    final sanitizedPassword = _sanitizePassword(password);
    final sanitizedPhone = _sanitizePhone(phone);
    try {
      final currentFirebaseUser = _auth.currentUser;
      if (currentFirebaseUser != null && currentFirebaseUser.email?.toLowerCase() != sanitizedEmail) {
        await _auth.signOut();
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
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
        phone: sanitizedPhone,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(message: 'Unable to sign in. Please try again.');
    }
  }

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) async {
    _validateRole(selectedRole);
    final sanitizedEmail = _sanitizeEmail(email);
    final sanitizedPassword = _sanitizePassword(password);
    final sanitizedPhone = _sanitizePhone(phone);
    try {
      final currentFirebaseUser = _auth.currentUser;
      if (currentFirebaseUser != null && currentFirebaseUser.email?.toLowerCase() != sanitizedEmail) {
        await _auth.signOut();
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Account creation failed. Please try again.',
        );
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'emailLowercase': sanitizedEmail,
        'role': selectedRole.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return _upsertAndMapUser(
        user: user,
        selectedRole: selectedRole,
        phone: sanitizedPhone,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseException(error);
    } catch (_) {
      throw const AuthException(message: 'Unable to create account. Please try again.');
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

      final currentPasswordText = _sanitizePassword(currentPassword);
      final newPasswordText = _sanitizePassword(newPassword);

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
      final resolvedEmail = _sanitizeEmail(email ?? _auth.currentUser?.email ?? '');

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
    final resolvedName = (userData['name'] as String? ?? dto.name ?? '').trim();
    final resolvedPhone = phoneToPersist.trim();
    // BUG-12 fix: compute isProfileComplete from actual data, not hardcoded true.
    final profileComplete = resolvedName.isNotEmpty && resolvedPhone.isNotEmpty;
    return AuthUser(
      uid: dto.uid,
      name: resolvedName.isEmpty ? null : resolvedName,
      email: userData['email'] as String? ?? dto.email,
      phone: resolvedPhone,
      role: roleToPersist.value,
      createdAt: dto.createdAt,
      lastLoginAt: DateTime.now(),
      isProfileComplete: profileComplete,
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
        return const AuthException(message: 'Invalid email or password.');
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
          message: 'This sign-in method is not available right now.',
        );
      default:
        return const AuthException(message: 'Authentication failed. Please try again.');
    }
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException({required this.message});

  @override
  String toString() => message;
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthFirebaseService {
  AuthFirebaseService(this._auth);

  final FirebaseAuth _auth;

  String? _verificationId;

  /// ─────────────────────────────
  /// SEND OTP
  /// ─────────────────────────────
  Future<void> sendOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      // WEB FLOW
      if (kIsWeb) {
        final confirmationResult =
            await _auth.signInWithPhoneNumber(phoneNumber);

        _verificationId = confirmationResult.verificationId;
        return;
      }

      // MOBILE FLOW
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // 🔥 Auto-verification (Android)
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw _mapFirebaseException(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (_) {
      throw const AuthException(
        message: 'Something went wrong. Please try again.',
      );
    }
  }


  Future<UserCredential> verifyOtp({
    required String otp,
  }) async {
    try {
      if (_verificationId == null) {
        throw const AuthException(
          message: 'OTP session expired. Please request again.',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (_) {
      throw const AuthException(
        message: 'Invalid OTP. Please try again.',
      );
    }
  }

  /// ─────────────────────────────
  /// SIGN OUT
  /// ─────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// ─────────────────────────────
  /// CURRENT USER
  /// ─────────────────────────────
  User? get currentUser => _auth.currentUser;

  /// ─────────────────────────────
  /// ERROR MAPPING (IMPORTANT)
  /// ─────────────────────────────
  AuthException _mapFirebaseException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return const AuthException(
          message: 'The phone number entered is invalid.',
        );

      case 'too-many-requests':
        return const AuthException(
          message:
              'Too many attempts. Please wait before trying again.',
        );

      case 'session-expired':
        return const AuthException(
          message: 'OTP expired. Please request a new one.',
        );

      case 'invalid-verification-code':
        return const AuthException(
          message: 'Incorrect OTP. Please try again.',
        );

      case 'network-request-failed':
        return const AuthException(
          message: 'No internet connection.',
        );

      default:
        return AuthException(
          message: e.message ?? 'Authentication failed.',
        );
    }
  }
}

/// ─────────────────────────────
/// CUSTOM AUTH EXCEPTION
/// ─────────────────────────────
class AuthException implements Exception {
  final String message;
  const AuthException({required this.message});

  @override
  String toString() => message;
}
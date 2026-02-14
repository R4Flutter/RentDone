import 'package:firebase_auth/firebase_auth.dart';

/// Auth service implementing Email Link authentication
class AuthFirebaseService {
  AuthFirebaseService(this._auth);

  final FirebaseAuth _auth;

  /// Send a sign-in link to the given email. Uses Firebase Email Link
  /// authentication (magic link). Configure `ActionCodeSettings` in
  /// production with your app's package names / dynamic link domain.
  Future<void> sendSignInLinkToEmail({required String email}) async {
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://rentdone.example.com/finishSignIn', // Update to your URL
        handleCodeInApp: true,
        androidPackageName: 'com.rentdone.app',
        androidInstallApp: true,
        androidMinimumVersion: '21',
        iOSBundleId: 'com.rentdone.app',
      );

      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw AuthException(
        message: 'Failed to send sign-in link. ${e.toString()}',
      );
    }
  }

  /// Complete sign-in using the email and the incoming link (emailLink).
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      if (!FirebaseAuth.instance.isSignInWithEmailLink(emailLink)) {
        throw const AuthException(message: 'Invalid sign-in link.');
      }

      final userCredential = await _auth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw AuthException(
        message: 'Failed to sign in with link. ${e.toString()}',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw const AuthException(
        message: 'Failed to sign out. Please try again.',
      );
    }
  }

  /// Update User Profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AuthException(message: 'User not authenticated.');
      }

      await user.updateProfile(displayName: displayName, photoURL: photoUrl);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw AuthException(message: 'Failed to update profile: ${e.toString()}');
    }
  }

  /// Get Current User
  User? get currentUser => _auth.currentUser;

  /// Stream Auth State Changes
  Stream<User?> getAuthStateChanges() => _auth.authStateChanges();

  /// Map firebase exceptions to user-friendly messages
  AuthException _mapFirebaseException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return const AuthException(message: 'The email address is invalid.');
      case 'user-disabled':
        return const AuthException(message: 'This account has been disabled.');
      case 'user-not-found':
        return const AuthException(message: 'No user found for this email.');
      case 'too-many-requests':
        return const AuthException(
          message: 'Too many attempts. Please try later.',
        );
      case 'network-request-failed':
        return const AuthException(message: 'No internet connection.');
      case 'invalid-action-code':
        return const AuthException(message: 'Invalid or expired sign-in link.');
      default:
        return AuthException(message: e.message ?? 'Authentication failed.');
    }
  }
}

/// Custom Auth Exception
class AuthException implements Exception {
  final String message;
  const AuthException({required this.message});

  @override
  String toString() => message;
}

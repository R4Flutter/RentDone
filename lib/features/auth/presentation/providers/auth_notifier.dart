import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/domain/usecases/validate_user_input.dart';
import 'package:rentdone/features/auth/data/services/firebase_auth_provider.dart';
import 'package:rentdone/features/auth/data/services/auth_firebase_services.dart';
import 'package:rentdone/features/auth/data/services/user_firestore_provider.dart';
import 'auth_state.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';

class AuthNotifier extends Notifier<AuthState> {
  Timer? _timer;
  final _validator = AuthInputValidator();
  late AuthFirebaseService _authService;
  late dynamic _userService;
  String? _email;
  String? _userName;

  @override
  AuthState build() {
    _authService = ref.watch(authFirebaseServiceProvider);
    _userService = ref.watch(userFirestoreServiceProvider);

    ref.onDispose(() {
      _timer?.cancel();
    });

    return AuthState.initial();
  }

  /// Send email sign-in link
  Future<void> sendEmailLink(String email, {required String name}) async {
    if (state.isLoading) return;

    // EMAIL VALIDATION
    final emailError = _validator.validateEmail(email);
    if (emailError != null) {
      _setEmailError(emailError);
      return;
    }

    // NAME VALIDATION
    if (name.trim().isEmpty) {
      state = state.copyWith(
        nameError: 'Please enter your name',
        emailError: null,
        linkError: null,
      );
      return;
    }

    clearErrors();
    state = state.copyWith(isLoading: true);

    try {
      _email = email.trim();
      _userName = name.trim();

      await _authService.sendSignInLinkToEmail(email: _email!);

      state = state.copyWith(
        isLoading: false,
        linkSent: true,
        resendSeconds: 60,
      );
      _startResendTimer();
    } on AuthException catch (e) {
      _setLinkError(e.message);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _setLinkError('Failed to send sign-in link. Please try again.');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Resend sign-in link
  Future<void> resendEmailLink() async {
    if (state.isLoading || _email == null) return;

    state = state.copyWith(isLoading: true);

    try {
      await _authService.sendSignInLinkToEmail(email: _email!);

      state = state.copyWith(
        isLoading: false,
        resendSeconds: 60,
        linkError: null,
      );
      _startResendTimer();
    } on AuthException catch (e) {
      _setLinkError(e.message);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _setLinkError('Failed to resend sign-in link. Please try again.');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Complete sign-in using the email and the link (emailLink)
  Future<void> completeSignIn({
    required String email,
    required String emailLink,
  }) async {
    if (state.isLoading) return;

    final emailError = _validator.validateEmail(email);
    if (emailError != null) {
      _setEmailError(emailError);
      return;
    }

    clearErrors();
    state = state.copyWith(isLoading: true);

    try {
      final userCredential = await _authService.signInWithEmailLink(
        email: email.trim(),
        emailLink: emailLink,
      );

      final uid = userCredential.user!.uid;

      bool exists = await _userService.userExists(uid);
      if (!exists) {
        final authUser = AuthUser(
          uid: uid,
          name: _userName ?? userCredential.user!.displayName,
          phone: null,
          role: null,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isProfileComplete: false,
        );
        await _userService.createOrUpdateUser(authUser);
      } else {
        await _userService.updateLastLogin(uid);
      }

      // Clear transient data
      _email = null;
      _userName = null;
      _timer?.cancel();

      state = state.copyWith(
        isLoading: false,
        linkSent: false,
        linkError: null,
      );
    } on AuthException catch (e) {
      _setLinkError(e.message);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _setLinkError('Failed to sign in. Please try again.');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _email = null;
      _userName = null;
      _timer?.cancel();
      state = AuthState.initial();
    } catch (e) {
      _setLinkError('Failed to sign out. Please try again.');
    }
  }

  void onPrimaryAction({
    required String name,
    required String email,
    String? emailLink,
  }) {
    if (!state.linkSent) {
      sendEmailLink(email, name: name);
    } else {
      if (emailLink != null && emailLink.isNotEmpty) {
        completeSignIn(email: email, emailLink: emailLink);
      }
    }
  }

  void _startResendTimer() {
    _timer?.cancel();

    if (state.resendSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!ref.mounted) {
        timer.cancel();
        return;
      }

      if (state.resendSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(resendSeconds: 0);
      } else {
        state = state.copyWith(resendSeconds: state.resendSeconds - 1);
      }
    });
  }

  void _setEmailError(String message) {
    state = state.copyWith(
      emailError: message,
      nameError: null,
      linkError: null,
    );
  }

  void _setLinkError(String message) {
    state = state.copyWith(
      linkError: message,
      nameError: null,
      emailError: null,
    );
  }

  void clearErrors() {
    state = state.copyWith(nameError: null, emailError: null, linkError: null);
  }
}

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/domain/usecases/validate_user_input.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  Timer? _timer;
  final _validator = AuthInputValidator();

  // ─────────────────────────────
  // INITIAL STATE
  // ─────────────────────────────
  @override
  AuthState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return AuthState.initial();
  }

  // ─────────────────────────────
  // SEND OTP (PHONE ONLY)
  // ─────────────────────────────
  Future<void> sendOtp(String phone, {required String name}) async {
    if (state.isLoading) return;

    // PHONE VALIDATION
    final phoneError = _validator.validatePhone(phone);
    if (phoneError != null) {
      _setPhoneError(phoneError);
      return;
    }

    clearErrors();
    state = state.copyWith(isLoading: true);

    try {
      // 🔮 Replace with Firebase verifyPhoneNumber
      await Future.delayed(const Duration(seconds: 1));

      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        resendSeconds: 30,
      );

      _startResendTimer();
    } catch (_) {
      _setOtpError('Failed to send OTP. Please try again.');
      state = state.copyWith(isLoading: false);
    }
  }

  // ─────────────────────────────
  // VERIFY OTP
  // ─────────────────────────────
  Future<void> verifyOtp(String otp) async {
    if (state.isLoading) return;

    if (!state.otpSent) {
      _setOtpError('Please request OTP first');
      return;
    }

    final otpError = _validator.validateOtp(otp);
    if (otpError != null) {
      _setOtpError(otpError);
      return;
    }

    clearErrors();
    state = state.copyWith(isLoading: true);

    try {
      // 🔮 Replace with Firebase signInWithCredential
      await Future.delayed(const Duration(seconds: 1));

      state = state.copyWith(isLoading: false);
    } catch (_) {
      _setOtpError('Invalid OTP. Please try again.');
      state = state.copyWith(isLoading: false);
    }
  }

  // ─────────────────────────────
  // RESEND TIMER
  // ─────────────────────────────
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

  // ─────────────────────────────
  // ERROR HANDLING
  // ─────────────────────────────
  void _setPhoneError(String message) {
    state = state.copyWith(
      phoneError: message,
      nameError: null,
      otpError: null,
    );
  }

  void _setOtpError(String message) {
    state = state.copyWith(
      otpError: message,
      nameError: null,
      phoneError: null,
    );
  }

  /// Clear errors on typing
  void clearErrors() {
    state = state.copyWith(nameError: null, phoneError: null, otpError: null);
  }
}

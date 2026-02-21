import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/auth/domain/usecases/validate_user_input.dart';

import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  Timer? _timer;
  final _validator = AuthInputValidator();

  @override
  AuthState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return AuthState.initial();
  }

  Future<void> sendOtp(String phone, {required String name}) async {
    if (state.isLoading) return;

    final nameError = _validator.validateName(name);
    if (nameError != null) {
      _setNameError(nameError);
      return;
    }

    final phoneError = _validator.validatePhone(phone);
    if (phoneError != null) {
      _setPhoneError(phoneError);
      return;
    }

    clearErrors();
    state = state.copyWith(isLoading: true);

    try {
      await ref
          .read(sendOtpUseCaseProvider)
          .call(phone: '${state.countryCode}${phone.trim()}');

      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        resendSeconds: 30,
        clearNameError: true,
        clearPhoneError: true,
        clearOtpError: true,
      );

      _startResendTimer();
    } catch (error) {
      _setOtpError(error.toString());
      state = state.copyWith(isLoading: false);
    }
  }

  void onPrimaryAction({
    required String name,
    required String phone,
    required String otp,
  }) {
    if (!state.otpSent) {
      sendOtp(phone, name: name);
    } else {
      verifyOtp(otp);
    }
  }

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
      await ref.read(verifyOtpUseCaseProvider).call(otp: otp.trim());
      state = state.copyWith(isLoading: false, clearOtpError: true);
    } catch (error) {
      _setOtpError(error.toString());
      state = state.copyWith(isLoading: false);
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

  void _setNameError(String message) {
    state = state.copyWith(
      nameError: message,
      clearPhoneError: true,
      clearOtpError: true,
    );
  }

  void _setPhoneError(String message) {
    state = state.copyWith(
      phoneError: message,
      clearNameError: true,
      clearOtpError: true,
    );
  }

  void _setOtpError(String message) {
    state = state.copyWith(
      otpError: message,
      clearNameError: true,
      clearPhoneError: true,
    );
  }

  void clearErrors() {
    state = state.copyWith(
      clearNameError: true,
      clearPhoneError: true,
      clearOtpError: true,
    );
  }
}

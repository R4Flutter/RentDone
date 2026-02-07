import 'package:flutter/material.dart';

@immutable
class AuthState {
  final bool otpSent;
  final bool isLoading;

  // 🎯 Field-level errors
  final String? nameError;
  final String? phoneError;
  final String? otpError;

  // 🌍 Other state
  final int resendSeconds;
  final String countryCode;
  final String countryFlag;

  const AuthState({
    required this.otpSent,
    required this.isLoading,
    required this.nameError,
    required this.phoneError,
    required this.otpError,
    required this.resendSeconds,
    required this.countryCode,
    required this.countryFlag,
  });

  // INITIAL STATE
  factory AuthState.initial() {
    return const AuthState(
      otpSent: false,
      isLoading: false,
      nameError: null,
      phoneError: null,
      otpError: null,
      resendSeconds: 0,
      countryCode: '+91',
      countryFlag: '🇮🇳',
    );
  }

  AuthState copyWith({
    bool? otpSent,
    bool? isLoading,
    String? nameError,
    String? phoneError,
    String? otpError,
    int? resendSeconds,
    String? countryCode,
    String? countryFlag,
  }) {
    return AuthState(
      otpSent: otpSent ?? this.otpSent,
      isLoading: isLoading ?? this.isLoading,
      nameError: nameError,
      phoneError: phoneError,
      otpError: otpError,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      countryCode: countryCode ?? this.countryCode,
      countryFlag: countryFlag ?? this.countryFlag,
    );
  }
}
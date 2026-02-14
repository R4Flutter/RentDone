import 'package:flutter/material.dart';

@immutable
class AuthState {
  final bool linkSent;
  final bool isLoading;

  // 🎯 Field-level errors
  final String? nameError;
  final String? emailError;
  final String? linkError;

  // 🌍 Other state
  final int resendSeconds;
  // (optional) keep for UI if needed
  final String? countryCode;
  final String? countryFlag;

  const AuthState({
    required this.linkSent,
    required this.isLoading,
    required this.nameError,
    required this.emailError,
    required this.linkError,
    required this.resendSeconds,
    required this.countryCode,
    required this.countryFlag,
  });

  // INITIAL STATE
  factory AuthState.initial() {
    return const AuthState(
      linkSent: false,
      isLoading: false,
      nameError: null,
      emailError: null,
      linkError: null,
      resendSeconds: 0,
      countryCode: null,
      countryFlag: null,
    );
  }

  AuthState copyWith({
    bool? linkSent,
    bool? isLoading,

    String? nameError,
    bool clearNameError = false,

    String? emailError,
    bool clearEmailError = false,

    String? linkError,
    bool clearLinkError = false,

    int? resendSeconds,
    String? countryCode,
    String? countryFlag,
  }) {
    return AuthState(
      linkSent: linkSent ?? this.linkSent,
      isLoading: isLoading ?? this.isLoading,

      nameError: clearNameError ? null : nameError ?? this.nameError,

      emailError: clearEmailError ? null : emailError ?? this.emailError,

      linkError: clearLinkError ? null : linkError ?? this.linkError,

      resendSeconds: resendSeconds ?? this.resendSeconds,
      countryCode: countryCode ?? this.countryCode,
      countryFlag: countryFlag ?? this.countryFlag,
    );
  }
}

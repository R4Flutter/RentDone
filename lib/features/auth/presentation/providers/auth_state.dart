import 'package:flutter/material.dart';
import 'package:rentdone/core/constants/user_role.dart';

@immutable
class AuthState {
  final bool isLoading;
  final bool isRegisterMode;
  final UserRole? selectedRole;
  final String? errorMessage;

  const AuthState({
    required this.isLoading,
    required this.isRegisterMode,
    required this.selectedRole,
    required this.errorMessage,
  });

  factory AuthState.initial() {
    return const AuthState(
      isLoading: false,
      isRegisterMode: false,
      selectedRole: null,
      errorMessage: null,
    );
  }

  AuthState copyWith({
    bool? isLoading,
    bool? isRegisterMode,
    UserRole? selectedRole,
    bool clearSelectedRole = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isRegisterMode: isRegisterMode ?? this.isRegisterMode,
      selectedRole: clearSelectedRole
          ? null
          : selectedRole ?? this.selectedRole,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

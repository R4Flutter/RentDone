import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';

import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState.initial();
  }

  void setSelectedRole(UserRole role) {
    state = state.copyWith(selectedRole: role, clearError: true);
  }

  void setMode({required bool registerMode}) {
    state = state.copyWith(isRegisterMode: registerMode, clearError: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<AuthUser> continueWithGoogle({required String phone}) async {
    final role = _validatedRole();
    final normalizedPhone = _normalizeOptionalPhone(phone);
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(selectedRole: role, phone: normalizedPhone);
      state = state.copyWith(isLoading: false);
      return user;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(error),
      );
      rethrow;
    }
  }

  Future<AuthUser> continueWithEmail({
    required String email,
    required String password,
    required String phone,
  }) async {
    final role = _validatedRole();
    final normalizedPhone = _validatePhone(phone);

    final emailText = email.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (emailText.isEmpty || !emailRegex.hasMatch(emailText)) {
      final message = 'Enter a valid email address.';
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }

    if (password.length < 6) {
      final message = 'Password should be at least 6 characters.';
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = state.isRegisterMode
          ? await repository.registerWithEmail(
              email: emailText,
              password: password,
              selectedRole: role,
              phone: normalizedPhone,
            )
          : await repository.signInWithEmail(
              email: emailText,
              password: password,
              selectedRole: role,
              phone: normalizedPhone,
            );
      state = state.copyWith(isLoading: false);
      return user;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanErrorMessage(error),
      );
      rethrow;
    }
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.startsWith('StateError:')) {
      return text.replaceFirst('StateError:', '').trim();
    }
    return text.isEmpty ? 'Authentication failed. Please try again.' : text;
  }

  UserRole _validatedRole() {
    final role = state.selectedRole;
    if (role == null) {
      const message = 'Please select Owner or Tenant role first.';
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }
    return role;
  }

  String _validatePhone(String phone) {
    final normalized = _normalizeIndianPhone(phone);
    if (normalized == null) {
      const message = 'Enter a valid phone number.';
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }
    return normalized;
  }

  String _normalizeOptionalPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final normalized = _normalizeIndianPhone(phone);
    if (normalized == null) {
      const message = 'Enter a valid phone number.';
      state = state.copyWith(errorMessage: message);
      throw StateError(message);
    }
    return normalized;
  }

  String? _normalizeIndianPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      if (RegExp(r'^[6-9]\d{9}$').hasMatch(local)) {
        return local;
      }
    }
    return null;
  }
}

import 'package:rentdone/core/constants/user_role.dart';

import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<void> sendOtp({required String phone});

  Future<AuthUser> verifyOtp({required String otp});

  Future<AuthUser?> getCurrentUser();

  Future<AuthUser> signInWithGoogle({
    required UserRole selectedRole,
    required String phone,
  });

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  });

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  });

  Future<UserRole?> getUserRole(String uid);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> sendPasswordResetCode({String? email});

  Future<void> signOut();
}

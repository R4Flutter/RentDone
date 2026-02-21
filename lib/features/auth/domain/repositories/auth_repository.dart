import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<void> sendOtp({required String phone});

  Future<AuthUser> verifyOtp({required String otp});

  Future<AuthUser?> getCurrentUser();

  Future<void> signOut();
}

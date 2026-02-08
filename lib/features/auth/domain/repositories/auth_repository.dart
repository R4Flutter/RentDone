import '../entities/auth_user.dart';

abstract class AuthRepository {
  /// Send OTP to phone number
  Future<void> sendOtp({
    required String phone,
  });

  /// Verify OTP and return logged-in user
  Future<AuthUser> verifyOtp({
    required String phone,
    required String otp,
  });

  /// Current logged-in user (null if not logged in)
  Future<AuthUser?> getCurrentUser();

  /// Logout user
  Future<void> signOut();
}
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';
import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';

class VerifyOtp {
  final AuthRepository _repository;

  const VerifyOtp(this._repository);

  Future<AuthUser> call({
    required String otp,
    UserRole? selectedRole,
    String? phone,
  }) {
    return _repository.verifyOtp(
      otp: otp,
      selectedRole: selectedRole,
      phone: phone,
    );
  }
}

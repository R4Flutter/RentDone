import 'package:rentdone/features/auth/data/models/auth_user_dto.dart';
import 'package:rentdone/features/auth/data/services/auth_firebase_services.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';
import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthFirebaseService _service;

  AuthRepositoryImpl(this._service);

  @override
  Future<void> sendOtp({required String phone}) {
    return _service.sendOtp(phoneNumber: phone);
  }

  @override
  Future<AuthUser> verifyOtp({required String otp}) async {
    final credential = await _service.verifyOtp(otp: otp);
    final user = credential.user;
    if (user == null) {
      throw const AuthException(
        message: 'Authentication failed. Please try again.',
      );
    }
    return AuthUserDto.fromFirebaseUser(user).toEntity();
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final user = _service.currentUser;
    if (user == null) {
      return null;
    }
    return AuthUserDto.fromFirebaseUser(user).toEntity();
  }

  @override
  Future<void> signOut() {
    return _service.signOut();
  }
}

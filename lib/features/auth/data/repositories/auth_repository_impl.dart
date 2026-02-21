import 'package:rentdone/core/constants/user_role.dart';
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
  Future<AuthUser> signInWithGoogle({
    required UserRole selectedRole,
    required String phone,
  }) {
    return _service.signInWithGoogle(selectedRole: selectedRole, phone: phone);
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) {
    return _service.signInWithEmail(
      email: email,
      password: password,
      selectedRole: selectedRole,
      phone: phone,
    );
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required UserRole selectedRole,
    required String phone,
  }) {
    return _service.registerWithEmail(
      email: email,
      password: password,
      selectedRole: selectedRole,
      phone: phone,
    );
  }

  @override
  Future<UserRole?> getUserRole(String uid) {
    return _service.getUserRole(uid);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> signOut() {
    return _service.signOut();
  }
}

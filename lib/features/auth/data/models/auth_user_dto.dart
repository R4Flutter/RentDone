import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/auth/domain/entities/auth_user.dart';

class AuthUserDto {
  final String uid;
  final String? name;
  final String? phone;
  final String? role;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool isProfileComplete;

  const AuthUserDto({
    required this.uid,
    this.name,
    this.phone,
    this.role,
    this.createdAt,
    this.lastLoginAt,
    required this.isProfileComplete,
  });

  factory AuthUserDto.fromFirebaseUser(User user) {
    return AuthUserDto(
      uid: user.uid,
      name: user.displayName,
      phone: user.phoneNumber,
      role: null,
      createdAt: user.metadata.creationTime,
      lastLoginAt: user.metadata.lastSignInTime,
      isProfileComplete:
          (user.displayName?.trim().isNotEmpty ?? false) ||
          (user.email?.trim().isNotEmpty ?? false),
    );
  }

  AuthUser toEntity() {
    return AuthUser(
      uid: uid,
      name: name,
      phone: phone,
      role: role,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      isProfileComplete: isProfileComplete,
    );
  }
}

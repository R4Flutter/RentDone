import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_profile/domain/entities/owner_profile.dart';

class OwnerProfileDto {
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String location;
  final String status;
  final String memberId;
  final String avatarCode;

  const OwnerProfileDto({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.location,
    required this.status,
    required this.memberId,
    required this.avatarCode,
  });

  factory OwnerProfileDto.fromFirebaseUser(User? user) {
    final uid = user?.uid.trim() ?? '';
    final memberSuffix = uid.isEmpty
        ? '----'
        : uid.substring(0, uid.length >= 4 ? 4 : uid.length).toUpperCase();

    return OwnerProfileDto(
      fullName: _resolveValue(user?.displayName, 'Owner'),
      email: _resolveValue(user?.email, ''),
      phone: _resolveValue(user?.phoneNumber, ''),
      role: 'Property Owner',
      location: '',
      status: 'Active',
      memberId: '#RD-$memberSuffix',
      avatarCode: 'male',
    );
  }

  OwnerProfile toEntity() {
    return OwnerProfile(
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      location: location,
      status: status,
      memberId: memberId,
      avatarCode: avatarCode,
    );
  }

  static String _resolveValue(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }
}

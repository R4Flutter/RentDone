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
  final String photoUrl;

  const OwnerProfileDto({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.location,
    required this.status,
    required this.memberId,
    required this.avatarCode,
    required this.photoUrl,
  });

  factory OwnerProfileDto.fromEntity(OwnerProfile profile) {
    return OwnerProfileDto(
      fullName: profile.fullName,
      email: profile.email,
      phone: profile.phone,
      role: profile.role,
      location: profile.location,
      status: profile.status,
      memberId: profile.memberId,
      avatarCode: profile.avatarCode,
      photoUrl: profile.photoUrl,
    );
  }

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
      photoUrl: _resolveValue(user?.photoURL, ''),
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
      photoUrl: photoUrl,
    );
  }

  OwnerProfileDto copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? location,
    String? status,
    String? memberId,
    String? avatarCode,
    String? photoUrl,
  }) {
    return OwnerProfileDto(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      location: location ?? this.location,
      status: status ?? this.status,
      memberId: memberId ?? this.memberId,
      avatarCode: avatarCode ?? this.avatarCode,
      photoUrl: photoUrl ?? this.photoUrl,
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

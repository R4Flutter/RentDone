import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_profile/di/owner_profile_di.dart';
import 'package:rentdone/features/owner/owner_profile/domain/entities/owner_profile.dart';

enum OwnerAvatar { male, female }

extension OwnerAvatarX on OwnerAvatar {
  String get label {
    switch (this) {
      case OwnerAvatar.male:
        return 'Male';
      case OwnerAvatar.female:
        return 'Female';
    }
  }

  String get assetPath {
    switch (this) {
      case OwnerAvatar.male:
        return 'assets/images/owner_final.png';
      case OwnerAvatar.female:
        return 'assets/images/tenant_final.png';
    }
  }
}

OwnerAvatar ownerAvatarFromCode(String avatarCode) {
  switch (avatarCode.trim().toLowerCase()) {
    case 'female':
      return OwnerAvatar.female;
    case 'male':
    default:
      return OwnerAvatar.male;
  }
}

@immutable
class OwnerProfileState {
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String location;
  final String status;
  final String memberId;
  final OwnerAvatar avatar;

  const OwnerProfileState({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.location,
    required this.status,
    required this.memberId,
    required this.avatar,
  });

  factory OwnerProfileState.fromEntity(OwnerProfile profile) {
    return OwnerProfileState(
      fullName: profile.fullName,
      email: profile.email,
      phone: profile.phone,
      role: profile.role,
      location: profile.location,
      status: profile.status,
      memberId: profile.memberId,
      avatar: ownerAvatarFromCode(profile.avatarCode),
    );
  }

  OwnerProfileState copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? location,
    String? status,
    String? memberId,
    OwnerAvatar? avatar,
  }) {
    return OwnerProfileState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      location: location ?? this.location,
      status: status ?? this.status,
      memberId: memberId ?? this.memberId,
      avatar: avatar ?? this.avatar,
    );
  }
}

class OwnerProfileNotifier extends Notifier<OwnerProfileState> {
  @override
  OwnerProfileState build() {
    final profile = ref.read(getOwnerProfileUseCaseProvider).call();
    return OwnerProfileState.fromEntity(profile);
  }

  void setAvatar(OwnerAvatar avatar) {
    state = state.copyWith(avatar: avatar);
  }

  void updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? role,
    String? location,
    String? status,
    String? memberId,
  }) {
    state = state.copyWith(
      fullName: fullName,
      email: email,
      phone: phone,
      role: role,
      location: location,
      status: status,
      memberId: memberId,
    );
  }
}

final ownerProfileProvider =
    NotifierProvider<OwnerProfileNotifier, OwnerProfileState>(
      OwnerProfileNotifier.new,
    );

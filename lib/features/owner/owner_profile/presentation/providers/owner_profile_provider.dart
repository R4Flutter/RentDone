import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    return OwnerProfileState(
      fullName: user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : 'Owner Name',
      email: user?.email?.trim().isNotEmpty == true
          ? user!.email!.trim()
          : 'owner@example.com',
      phone: user?.phoneNumber?.trim().isNotEmpty == true
          ? user!.phoneNumber!.trim()
          : '+91 90000 00000',
      role: 'Property Owner',
      location: 'India',
      status: 'Active',
      memberId: '#RD-0001',
      avatar: OwnerAvatar.male,
    );
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

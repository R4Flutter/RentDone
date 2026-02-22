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
  final String photoUrl;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  const OwnerProfileState({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.location,
    required this.status,
    required this.memberId,
    required this.avatar,
    required this.photoUrl,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
    required this.successMessage,
  });

  factory OwnerProfileState.initial() {
    return const OwnerProfileState(
      fullName: '',
      email: '',
      phone: '',
      role: 'Property Owner',
      location: '',
      status: 'Active',
      memberId: '',
      avatar: OwnerAvatar.male,
      photoUrl: '',
      isLoading: true,
      isSaving: false,
      errorMessage: null,
      successMessage: null,
    );
  }

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
      photoUrl: profile.photoUrl,
      isLoading: false,
      isSaving: false,
      errorMessage: null,
      successMessage: null,
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
    String? photoUrl,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
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
      photoUrl: photoUrl ?? this.photoUrl,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      successMessage: clearSuccessMessage
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

class OwnerProfileNotifier extends Notifier<OwnerProfileState> {
  @override
  OwnerProfileState build() {
    Future.microtask(loadProfile);
    return OwnerProfileState.initial();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    try {
      final profile = await ref.read(getOwnerProfileUseCaseProvider).call();
      state = OwnerProfileState.fromEntity(profile);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load profile. Please try again.',
        clearSuccessMessage: true,
      );
    }
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
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  Future<void> saveProfile({
    required String fullName,
    required String email,
    required String phone,
    required String location,
  }) async {
    final trimmedFullName = fullName.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phone.trim();
    final trimmedLocation = location.trim();

    if (trimmedFullName.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Full name is required.',
        clearSuccessMessage: true,
      );
      return;
    }

    if (trimmedEmail.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Email is required.',
        clearSuccessMessage: true,
      );
      return;
    }

    const emailPattern = r'^[\w.-]+@[\w-]+(?:\.[\w-]+)+$';
    if (!RegExp(emailPattern).hasMatch(trimmedEmail)) {
      state = state.copyWith(
        errorMessage: 'Enter a valid email address.',
        clearSuccessMessage: true,
      );
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );

    try {
      final profile = OwnerProfile(
        fullName: trimmedFullName,
        email: trimmedEmail,
        phone: trimmedPhone,
        role: state.role,
        location: trimmedLocation,
        status: state.status,
        memberId: state.memberId,
        avatarCode: state.avatar.name,
        photoUrl: state.photoUrl,
      );

      final saved = await ref
          .read(saveOwnerProfileUseCaseProvider)
          .call(profile);
      state = OwnerProfileState.fromEntity(saved).copyWith(
        successMessage:
            'Profile saved successfully. If email changed, verify it from your inbox.',
      );
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '').trim();
      state = state.copyWith(
        isSaving: false,
        errorMessage: message.isEmpty
            ? 'Unable to save profile. Please retry.'
            : message,
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearErrorMessage: true, clearSuccessMessage: true);
  }
}

final ownerProfileProvider =
    NotifierProvider<OwnerProfileNotifier, OwnerProfileState>(
      OwnerProfileNotifier.new,
    );

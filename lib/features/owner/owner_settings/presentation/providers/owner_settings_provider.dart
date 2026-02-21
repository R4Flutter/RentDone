import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_settings/di/owner_settings_di.dart';
import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';

@immutable
class OwnerSettingsState {
  final String fullName;
  final String email;
  final String phone;
  final String businessName;
  final String gstNumber;
  final String businessAddress;
  final String defaultPaymentMode;
  final String lateFeePercentage;
  final String rentDueDay;
  final bool enable2FA;
  final bool notificationsEnabled;
  final bool darkMode;

  const OwnerSettingsState({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.businessName,
    required this.gstNumber,
    required this.businessAddress,
    required this.defaultPaymentMode,
    required this.lateFeePercentage,
    required this.rentDueDay,
    required this.enable2FA,
    required this.notificationsEnabled,
    required this.darkMode,
  });

  factory OwnerSettingsState.fromEntity(OwnerSettings settings) {
    return OwnerSettingsState(
      fullName: settings.fullName,
      email: settings.email,
      phone: settings.phone,
      businessName: settings.businessName,
      gstNumber: settings.gstNumber,
      businessAddress: settings.businessAddress,
      defaultPaymentMode: settings.defaultPaymentMode,
      lateFeePercentage: settings.lateFeePercentage,
      rentDueDay: settings.rentDueDay,
      enable2FA: settings.enable2FA,
      notificationsEnabled: settings.notificationsEnabled,
      darkMode: settings.darkMode,
    );
  }

  OwnerSettings toEntity() {
    return OwnerSettings(
      fullName: fullName,
      email: email,
      phone: phone,
      businessName: businessName,
      gstNumber: gstNumber,
      businessAddress: businessAddress,
      defaultPaymentMode: defaultPaymentMode,
      lateFeePercentage: lateFeePercentage,
      rentDueDay: rentDueDay,
      enable2FA: enable2FA,
      notificationsEnabled: notificationsEnabled,
      darkMode: darkMode,
    );
  }

  OwnerSettingsState copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? businessName,
    String? gstNumber,
    String? businessAddress,
    String? defaultPaymentMode,
    String? lateFeePercentage,
    String? rentDueDay,
    bool? enable2FA,
    bool? notificationsEnabled,
    bool? darkMode,
  }) {
    return OwnerSettingsState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      gstNumber: gstNumber ?? this.gstNumber,
      businessAddress: businessAddress ?? this.businessAddress,
      defaultPaymentMode: defaultPaymentMode ?? this.defaultPaymentMode,
      lateFeePercentage: lateFeePercentage ?? this.lateFeePercentage,
      rentDueDay: rentDueDay ?? this.rentDueDay,
      enable2FA: enable2FA ?? this.enable2FA,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

class OwnerSettingsNotifier extends Notifier<OwnerSettingsState> {
  @override
  OwnerSettingsState build() {
    final settings = ref.read(getOwnerSettingsUseCaseProvider).call();
    return OwnerSettingsState.fromEntity(settings);
  }

  void updateFullName(String value) => _update(state.copyWith(fullName: value));
  void updateEmail(String value) => _update(state.copyWith(email: value));
  void updatePhone(String value) => _update(state.copyWith(phone: value));
  void updateBusinessName(String value) =>
      _update(state.copyWith(businessName: value));
  void updateGstNumber(String value) =>
      _update(state.copyWith(gstNumber: value));
  void updateBusinessAddress(String value) =>
      _update(state.copyWith(businessAddress: value));
  void updateDefaultPaymentMode(String value) =>
      _update(state.copyWith(defaultPaymentMode: value));
  void updateLateFeePercentage(String value) =>
      _update(state.copyWith(lateFeePercentage: value));
  void updateRentDueDay(String value) =>
      _update(state.copyWith(rentDueDay: value));
  void setEnable2FA(bool value) => _update(state.copyWith(enable2FA: value));
  void setNotificationsEnabled(bool value) =>
      _update(state.copyWith(notificationsEnabled: value));
  void setDarkMode(bool value) => _update(state.copyWith(darkMode: value));

  void _update(OwnerSettingsState next) {
    state = next;
    ref.read(saveOwnerSettingsUseCaseProvider).call(state.toEntity());
  }
}

final ownerSettingsProvider =
    NotifierProvider<OwnerSettingsNotifier, OwnerSettingsState>(
      OwnerSettingsNotifier.new,
    );

import 'package:rentdone/features/owner/owner_settings/domain/entities/owner_settings.dart';

class OwnerSettingsDto {
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

  const OwnerSettingsDto({
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

  factory OwnerSettingsDto.fromEntity(OwnerSettings settings) {
    return OwnerSettingsDto(
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
}

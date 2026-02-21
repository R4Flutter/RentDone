class OwnerSettings {
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
  final String locationAddress;
  final double? locationLatitude;
  final double? locationLongitude;

  const OwnerSettings({
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
    required this.locationAddress,
    required this.locationLatitude,
    required this.locationLongitude,
  });
}

class Tenant {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final DateTime moveInDate;
  final int rentAmount;
  final int securityDeposit;
  final double? monthlyIncome;
  final bool policeVerified;
  final bool backgroundChecked;
  final String? emergencyName;
  final String? emergencyPhone;

  const Tenant({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.moveInDate,
    required this.rentAmount,
    required this.securityDeposit,
    required this.policeVerified,
    required this.backgroundChecked,
    this.email,
    this.monthlyIncome,
    this.emergencyName,
    this.emergencyPhone,
  });
}
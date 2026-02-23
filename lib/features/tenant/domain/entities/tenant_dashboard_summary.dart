class TenantDashboardSummary {
  final int totalDueAmount;
  final int paidAmount;
  final int pendingAmount;
  final DateTime? nextDueDate;
  final String? propertyName;
  final String? roomNumber;
  final String? ownerName;
  final String? ownerPhone;
  final int rentAmount;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  final int totalTransactions;
  final int successfulPayments;

  const TenantDashboardSummary({
    required this.totalDueAmount,
    required this.paidAmount,
    required this.pendingAmount,
    this.nextDueDate,
    this.propertyName,
    this.roomNumber,
    this.ownerName,
    this.ownerPhone,
    required this.rentAmount,
    this.leaseStartDate,
    this.leaseEndDate,
    required this.totalTransactions,
    required this.successfulPayments,
  });

  static const empty = TenantDashboardSummary(
    totalDueAmount: 0,
    paidAmount: 0,
    pendingAmount: 0,
    rentAmount: 0,
    totalTransactions: 0,
    successfulPayments: 0,
  );
}

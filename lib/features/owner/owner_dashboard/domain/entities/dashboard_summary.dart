class DashboardSummary {
  final int totalProperties;
  final int vacantProperties;
  final int totalTenants;
  final int collectedAmount;
  final int collectedPayments;
  final int pendingAmount;
  final int pendingPayments;
  final int pendingTenants;
  final int cashAmount;
  final int onlineAmount;

  const DashboardSummary({
    required this.totalProperties,
    required this.vacantProperties,
    required this.totalTenants,
    required this.collectedAmount,
    required this.collectedPayments,
    required this.pendingAmount,
    required this.pendingPayments,
    required this.pendingTenants,
    required this.cashAmount,
    required this.onlineAmount,
  });

  static const empty = DashboardSummary(
    totalProperties: 0,
    vacantProperties: 0,
    totalTenants: 0,
    collectedAmount: 0,
    collectedPayments: 0,
    pendingAmount: 0,
    pendingPayments: 0,
    pendingTenants: 0,
    cashAmount: 0,
    onlineAmount: 0,
  );
}

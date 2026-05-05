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

  int get vacantRooms => vacantProperties;

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

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      totalProperties: (map['totalProperties'] as num?)?.toInt() ?? 0,
      vacantProperties: (map['vacantProperties'] as num?)?.toInt() ?? 0,
      totalTenants: (map['totalTenants'] as num?)?.toInt() ?? 0,
      collectedAmount: (map['collectedAmount'] as num?)?.toInt() ?? 0,
      collectedPayments: (map['collectedPayments'] as num?)?.toInt() ?? 0,
      pendingAmount: (map['pendingAmount'] as num?)?.toInt() ?? 0,
      pendingPayments: (map['pendingPayments'] as num?)?.toInt() ?? 0,
      pendingTenants: (map['pendingTenants'] as num?)?.toInt() ?? 0,
      cashAmount: (map['cashAmount'] as num?)?.toInt() ?? 0,
      onlineAmount: (map['onlineAmount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalProperties': totalProperties,
      'vacantProperties': vacantProperties,
      'totalTenants': totalTenants,
      'collectedAmount': collectedAmount,
      'collectedPayments': collectedPayments,
      'pendingAmount': pendingAmount,
      'pendingPayments': pendingPayments,
      'pendingTenants': pendingTenants,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
    };
  }
}

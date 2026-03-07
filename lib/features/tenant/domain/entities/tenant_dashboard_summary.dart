class TenantDashboardSummary {
  final String tenantId;
  final String tenantName;
  final String tenantEmail;
  final String tenantPhone;
  final String ownerId;
  final String roomNumber;
  final String propertyName;
  final int monthlyRent;
  final int? depositAmount;
  final DateTime? allocationDate;
  final int rentDueDay;
  final String ownerPhoneNumber;
  final int dueAmount;
  final int lifetimePaid;
  final String currentMonthName;
  final String? profileImageUrl;
  final int trustScore;
  final String trustBadge;
  final double onTimePaymentRate;
  final double latePaymentRate;
  final double tenureYears;

  const TenantDashboardSummary({
    required this.tenantId,
    required this.tenantName,
    required this.tenantEmail,
    required this.tenantPhone,
    required this.ownerId,
    required this.roomNumber,
    required this.propertyName,
    required this.monthlyRent,
    required this.depositAmount,
    required this.allocationDate,
    required this.rentDueDay,
    required this.ownerPhoneNumber,
    required this.dueAmount,
    required this.lifetimePaid,
    required this.currentMonthName,
    this.profileImageUrl,
    this.trustScore = 50,
    this.trustBadge = 'Average Tenant',
    this.onTimePaymentRate = 0,
    this.latePaymentRate = 0,
    this.tenureYears = 0,
  });

  static const empty = TenantDashboardSummary(
    tenantId: '',
    tenantName: 'Tenant',
    tenantEmail: '',
    tenantPhone: '',
    ownerId: '',
    roomNumber: '-',
    propertyName: '',
    monthlyRent: 0,
    depositAmount: null,
    allocationDate: null,
    rentDueDay: 1,
    ownerPhoneNumber: '',
    dueAmount: 0,
    lifetimePaid: 0,
    currentMonthName: '',
    trustScore: 50,
    trustBadge: 'Average Tenant',
    onTimePaymentRate: 0,
    latePaymentRate: 0,
    tenureYears: 0,
  );
}

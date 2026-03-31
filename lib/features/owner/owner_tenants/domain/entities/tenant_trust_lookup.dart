class TenantTrustLookup {
  final String tenantId;
  final String tenantName;
  final int trustScore;
  final String trustBadge;
  final double onTimePaymentRate;
  final double latePaymentRate;
  final double tenureYears;

  const TenantTrustLookup({
    required this.tenantId,
    required this.tenantName,
    required this.trustScore,
    required this.trustBadge,
    required this.onTimePaymentRate,
    required this.latePaymentRate,
    required this.tenureYears,
  });
}

class PaymentQuoteDto {
  const PaymentQuoteDto({
    required this.leaseId,
    required this.gateway,
    required this.baseAmountInRupees,
    required this.lateFeeAmountInRupees,
    required this.rentAmountInPaise,
    required this.convenienceFeeInPaise,
    required this.totalPayableInPaise,
    required this.estimatedGatewayCostInPaise,
    required this.gatewayPercent,
    required this.gstPercent,
    required this.currency,
    required this.isOverdue,
  });

  final String leaseId;
  final String gateway;
  final int baseAmountInRupees;
  final int lateFeeAmountInRupees;
  final int rentAmountInPaise;
  final int convenienceFeeInPaise;
  final int totalPayableInPaise;
  final int estimatedGatewayCostInPaise;
  final double gatewayPercent;
  final double gstPercent;
  final String currency;
  final bool isOverdue;

  factory PaymentQuoteDto.fromMap(Map<String, dynamic> data) {
    return PaymentQuoteDto(
      leaseId: (data['leaseId'] as String? ?? '').trim(),
      gateway: (data['gateway'] as String? ?? '').trim(),
      baseAmountInRupees: (data['baseAmountInRupees'] as num?)?.toInt() ?? 0,
      lateFeeAmountInRupees:
          (data['lateFeeAmountInRupees'] as num?)?.toInt() ?? 0,
      rentAmountInPaise: (data['rentAmountInPaise'] as num?)?.toInt() ?? 0,
      convenienceFeeInPaise:
          (data['convenienceFeeInPaise'] as num?)?.toInt() ?? 0,
      totalPayableInPaise: (data['totalPayableInPaise'] as num?)?.toInt() ?? 0,
      estimatedGatewayCostInPaise:
          (data['estimatedGatewayCostInPaise'] as num?)?.toInt() ?? 0,
      gatewayPercent: (data['gatewayPercent'] as num?)?.toDouble() ?? 0,
      gstPercent: (data['gstPercent'] as num?)?.toDouble() ?? 0,
      currency: (data['currency'] as String? ?? 'INR').trim(),
      isOverdue: data['isOverdue'] == true,
    );
  }
}

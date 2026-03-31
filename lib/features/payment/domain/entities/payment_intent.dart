class PaymentIntent {
  final String paymentId;
  final String gateway;
  final int amount;
  final int rentAmountInPaise;
  final int convenienceFeeInPaise;
  final int totalPayableInPaise;
  final int estimatedGatewayCostInPaise;
  final double gatewayPercent;
  final double gstPercent;
  final String currency;
  final String idempotencyKey;
  final String? orderId;
  final String? clientSecret;
  final String? keyId;
  final String? paymentSessionId;

  const PaymentIntent({
    required this.paymentId,
    required this.gateway,
    required this.amount,
    this.rentAmountInPaise = 0,
    this.convenienceFeeInPaise = 0,
    this.totalPayableInPaise = 0,
    this.estimatedGatewayCostInPaise = 0,
    this.gatewayPercent = 0,
    this.gstPercent = 0,
    required this.currency,
    required this.idempotencyKey,
    this.orderId,
    this.clientSecret,
    this.keyId,
    this.paymentSessionId,
  });
}

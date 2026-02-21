class PaymentIntent {
  final String paymentId;
  final String gateway;
  final int amount;
  final String currency;
  final String idempotencyKey;
  final String? orderId;
  final String? clientSecret;
  final String? keyId;

  const PaymentIntent({
    required this.paymentId,
    required this.gateway,
    required this.amount,
    required this.currency,
    required this.idempotencyKey,
    this.orderId,
    this.clientSecret,
    this.keyId,
  });
}

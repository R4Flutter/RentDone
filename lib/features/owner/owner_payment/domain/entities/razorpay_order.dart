class RazorpayOrder {
  final String orderId;
  final String keyId;
  final int amount;
  final String currency;

  const RazorpayOrder({
    required this.orderId,
    required this.keyId,
    required this.amount,
    required this.currency,
  });
}

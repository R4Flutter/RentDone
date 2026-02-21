class PaymentGatewayRequest {
  final String orderId;
  final String gatewayKey;
  final int amount;
  final String currency;
  final String paymentId;
  final String tenantEmail;
  final String tenantPhone;

  const PaymentGatewayRequest({
    required this.orderId,
    required this.gatewayKey,
    required this.amount,
    required this.currency,
    required this.paymentId,
    required this.tenantEmail,
    required this.tenantPhone,
  });
}

class PaymentGatewayResult {
  final bool isSuccess;
  final String? gatewayPaymentId;
  final String? orderId;
  final String? signature;
  final String? failureReason;

  const PaymentGatewayResult({
    required this.isSuccess,
    this.gatewayPaymentId,
    this.orderId,
    this.signature,
    this.failureReason,
  });
}

abstract class PaymentGateway {
  Future<PaymentGatewayResult> initializePayment(PaymentGatewayRequest request);

  Future<void> verifyPayment(Map<String, dynamic> payload);

  Future<void> handleWebhook(Map<String, dynamic> payload);
}

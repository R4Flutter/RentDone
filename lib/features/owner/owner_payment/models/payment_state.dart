/// Enum representing the state of a payment transaction
enum PaymentState {
  idle, // No payment in progress
  processing, // Payment is being processed
  success, // Payment completed successfully
  failed, // Payment failed
  cancelled, // User cancelled payment
}

/// Model representing payment response from Razorpay
class PaymentResponse {
  const PaymentResponse({
    required this.transactionId,
    required this.orderId,
    required this.signature,
    this.error,
    this.errorCode,
  });

  final String transactionId;
  final String orderId;
  final String signature;
  final String? error;
  final String? errorCode;

  bool get isSuccess => error == null;
}

/// Model for payment request to Razorpay
class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.key,
    this.description,
    this.metadata,
    this.email,
    this.phone,
  });

  final String orderId;
  final int amount; // in paise
  final String currency;
  final String key;
  final String? description;
  final Map<String, dynamic>? metadata;
  final String? email;
  final String? phone;
}

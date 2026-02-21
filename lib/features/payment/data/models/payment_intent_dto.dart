import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';

class PaymentIntentDto {
  final String paymentId;
  final String gateway;
  final int amount;
  final String currency;
  final String idempotencyKey;
  final String? orderId;
  final String? clientSecret;
  final String? keyId;

  const PaymentIntentDto({
    required this.paymentId,
    required this.gateway,
    required this.amount,
    required this.currency,
    required this.idempotencyKey,
    this.orderId,
    this.clientSecret,
    this.keyId,
  });

  factory PaymentIntentDto.fromMap(Map<String, dynamic> data) {
    return PaymentIntentDto(
      paymentId: (data['paymentId'] as String?) ?? '',
      gateway: (data['gateway'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: (data['currency'] as String?) ?? 'INR',
      idempotencyKey: (data['idempotencyKey'] as String?) ?? '',
      orderId: data['orderId'] as String?,
      clientSecret: data['clientSecret'] as String?,
      keyId: data['keyId'] as String?,
    );
  }

  PaymentIntent toEntity() {
    return PaymentIntent(
      paymentId: paymentId,
      gateway: gateway,
      amount: amount,
      currency: currency,
      idempotencyKey: idempotencyKey,
      orderId: orderId,
      clientSecret: clientSecret,
      keyId: keyId,
    );
  }
}

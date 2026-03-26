import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';

class PaymentIntentDto {
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

  const PaymentIntentDto({
    required this.paymentId,
    required this.gateway,
    required this.amount,
    required this.rentAmountInPaise,
    required this.convenienceFeeInPaise,
    required this.totalPayableInPaise,
    required this.estimatedGatewayCostInPaise,
    required this.gatewayPercent,
    required this.gstPercent,
    required this.currency,
    required this.idempotencyKey,
    this.orderId,
    this.clientSecret,
    this.keyId,
    this.paymentSessionId,
  });

  factory PaymentIntentDto.fromMap(Map<String, dynamic> data) {
    return PaymentIntentDto(
      paymentId: (data['paymentId'] as String?) ?? '',
      gateway: (data['gateway'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      rentAmountInPaise: (data['rentAmountInPaise'] as num?)?.toInt() ?? 0,
      convenienceFeeInPaise:
          (data['convenienceFeeInPaise'] as num?)?.toInt() ?? 0,
      totalPayableInPaise: (data['totalPayableInPaise'] as num?)?.toInt() ?? 0,
      estimatedGatewayCostInPaise:
          (data['estimatedGatewayCostInPaise'] as num?)?.toInt() ?? 0,
      gatewayPercent: (data['gatewayPercent'] as num?)?.toDouble() ?? 0,
      gstPercent: (data['gstPercent'] as num?)?.toDouble() ?? 0,
      currency: (data['currency'] as String?) ?? 'INR',
      idempotencyKey: (data['idempotencyKey'] as String?) ?? '',
      orderId: data['orderId'] as String?,
      clientSecret: data['clientSecret'] as String?,
      keyId: data['keyId'] as String?,
      paymentSessionId: data['paymentSessionId'] as String?,
    );
  }

  PaymentIntent toEntity() {
    return PaymentIntent(
      paymentId: paymentId,
      gateway: gateway,
      amount: amount,
      rentAmountInPaise: rentAmountInPaise,
      convenienceFeeInPaise: convenienceFeeInPaise,
      totalPayableInPaise: totalPayableInPaise,
      estimatedGatewayCostInPaise: estimatedGatewayCostInPaise,
      gatewayPercent: gatewayPercent,
      gstPercent: gstPercent,
      currency: currency,
      idempotencyKey: idempotencyKey,
      orderId: orderId,
      clientSecret: clientSecret,
      keyId: keyId,
      paymentSessionId: paymentSessionId,
    );
  }
}

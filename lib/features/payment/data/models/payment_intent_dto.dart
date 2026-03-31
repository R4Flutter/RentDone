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

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  factory PaymentIntentDto.fromMap(Map<String, dynamic> data) {
    final source = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : data;
    return PaymentIntentDto(
      paymentId: (source['paymentId'] ?? source['payment_id'] ?? '').toString(),
      gateway: (source['gateway'] ?? 'razorpay').toString(),
      amount: _asInt(source['amount'] ?? source['amountInPaise'] ?? source['amount_in_paise'] ?? source['totalPayableInPaise'] ?? source['total_payable_in_paise']),
      rentAmountInPaise: _asInt(source['rentAmountInPaise'] ?? source['rent_amount_in_paise']),
      convenienceFeeInPaise: _asInt(source['convenienceFeeInPaise'] ?? source['convenience_fee_in_paise']),
      totalPayableInPaise: _asInt(source['totalPayableInPaise'] ?? source['total_payable_in_paise']),
      estimatedGatewayCostInPaise: _asInt(source['estimatedGatewayCostInPaise'] ?? source['estimated_gateway_cost_in_paise']),
      gatewayPercent: _asDouble(source['gatewayPercent'] ?? source['gateway_percent']),
      gstPercent: _asDouble(source['gstPercent'] ?? source['gst_percent']),
      currency: (source['currency'] ?? 'INR').toString(),
      idempotencyKey: (source['idempotencyKey'] ?? source['idempotency_key'] ?? '').toString(),
      orderId: _asNullableString(source['orderId'] ?? source['order_id']),
      clientSecret: _asNullableString(source['clientSecret'] ?? source['client_secret']),
      keyId: _asNullableString(source['keyId'] ?? source['key_id']),
      paymentSessionId: _asNullableString(source['paymentSessionId'] ?? source['payment_session_id']),
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

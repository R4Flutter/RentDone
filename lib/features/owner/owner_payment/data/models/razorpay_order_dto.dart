import 'package:rentdone/features/owner/owner_payment/domain/entities/razorpay_order.dart';

class RazorpayOrderDto {
  final String orderId;
  final String keyId;
  final int amount;
  final String currency;

  const RazorpayOrderDto({
    required this.orderId,
    required this.keyId,
    required this.amount,
    required this.currency,
  });

  factory RazorpayOrderDto.fromMap(Map<String, dynamic> map) {
    return RazorpayOrderDto(
      orderId: (map['orderId'] as String?) ?? '',
      keyId: (map['keyId'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String?) ?? 'INR',
    );
  }

  RazorpayOrder toEntity() {
    return RazorpayOrder(
      orderId: orderId,
      keyId: keyId,
      amount: amount,
      currency: currency,
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';

class OwnerRazorpayPaymentIntent {
  const OwnerRazorpayPaymentIntent({
    required this.paymentId,
    required this.orderId,
    required this.keyId,
    required this.amountInPaise,
    required this.currency,
    required this.idempotencyKey,
  });

  final String paymentId;
  final String orderId;
  final String keyId;
  final int amountInPaise;
  final String currency;
  final String idempotencyKey;

  factory OwnerRazorpayPaymentIntent.fromMap(Map<String, dynamic> map) {
    return OwnerRazorpayPaymentIntent(
      paymentId: (map['paymentId'] as String? ?? '').trim(),
      orderId: (map['orderId'] as String? ?? '').trim(),
      keyId: (map['keyId'] as String? ?? '').trim(),
      amountInPaise: (map['amountInPaise'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String? ?? 'INR').trim(),
      idempotencyKey: (map['idempotencyKey'] as String? ?? '').trim(),
    );
  }
}

class OwnerRazorpayPaymentService {
  OwnerRazorpayPaymentService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<OwnerRazorpayPaymentIntent> createPaymentIntent({
    required String tenantId,
    required String propertyId,
    required int amount,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable(
      'createOwnerRazorpayPaymentIntent',
    );
    final result = await callable.call(<String, dynamic>{
      'tenantId': tenantId,
      'propertyId': propertyId,
      'amount': amount,
      'idempotencyKey': idempotencyKey,
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final intent = OwnerRazorpayPaymentIntent.fromMap(data);

    if (intent.paymentId.isEmpty ||
        intent.orderId.isEmpty ||
        intent.keyId.isEmpty ||
        intent.amountInPaise <= 0) {
      throw StateError('Invalid payment intent returned by backend.');
    }

    return intent;
  }

  Future<void> verifyPayment({
    required String paymentId,
    required String orderId,
    required String razorpayPaymentId,
    required String signature,
  }) async {
    final callable = _functions.httpsCallable('verifyOwnerRazorpayPayment');
    await callable.call(<String, dynamic>{
      'paymentId': paymentId,
      'payload': <String, dynamic>{
        'orderId': orderId,
        'paymentId': razorpayPaymentId,
        'signature': signature,
      },
    });
  }
}

import 'package:cloud_functions/cloud_functions.dart';

class OwnerRazorpayPaymentIntent {
  const OwnerRazorpayPaymentIntent({
    required this.paymentId,
    required this.orderId,
    required this.keyId,
    required this.amountInPaise,
    required this.rentAmountInPaise,
    required this.convenienceFeeInPaise,
    required this.totalPayableInPaise,
    required this.currency,
    required this.idempotencyKey,
  });

  final String paymentId;
  final String orderId;
  final String keyId;
  final int amountInPaise;
  final int rentAmountInPaise;
  final int convenienceFeeInPaise;
  final int totalPayableInPaise;
  final String currency;
  final String idempotencyKey;

  factory OwnerRazorpayPaymentIntent.fromMap(Map<String, dynamic> map) {
    return OwnerRazorpayPaymentIntent(
      paymentId: (map['paymentId'] as String? ?? '').trim(),
      orderId: (map['orderId'] as String? ?? '').trim(),
      keyId: (map['keyId'] as String? ?? '').trim(),
      amountInPaise: (map['amountInPaise'] as num?)?.toInt() ?? 0,
      rentAmountInPaise: (map['rentAmountInPaise'] as num?)?.toInt() ?? 0,
      convenienceFeeInPaise:
          (map['convenienceFeeInPaise'] as num?)?.toInt() ?? 0,
      totalPayableInPaise: (map['totalPayableInPaise'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] as String? ?? 'INR').trim(),
      idempotencyKey: (map['idempotencyKey'] as String? ?? '').trim(),
    );
  }
}

class OwnerPaymentQuote {
  const OwnerPaymentQuote({
    required this.rentAmountInPaise,
    required this.convenienceFeeInPaise,
    required this.totalPayableInPaise,
    required this.gatewayPercent,
    required this.gstPercent,
  });

  final int rentAmountInPaise;
  final int convenienceFeeInPaise;
  final int totalPayableInPaise;
  final double gatewayPercent;
  final double gstPercent;

  factory OwnerPaymentQuote.fromMap(Map<String, dynamic> map) {
    return OwnerPaymentQuote(
      rentAmountInPaise: (map['rentAmountInPaise'] as num?)?.toInt() ?? 0,
      convenienceFeeInPaise:
          (map['convenienceFeeInPaise'] as num?)?.toInt() ?? 0,
      totalPayableInPaise: (map['totalPayableInPaise'] as num?)?.toInt() ?? 0,
      gatewayPercent: (map['gatewayPercent'] as num?)?.toDouble() ?? 0,
      gstPercent: (map['gstPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OwnerRazorpayPaymentService {
  OwnerRazorpayPaymentService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<OwnerPaymentQuote> quotePayment({required int amount}) async {
    final callable = _functions.httpsCallable('quoteOwnerRazorpayPayment');
    final result = await callable.call(<String, dynamic>{'amount': amount});

    final data = Map<String, dynamic>.from(result.data as Map);
    final quote = OwnerPaymentQuote.fromMap(data);
    if (quote.rentAmountInPaise <= 0 || quote.totalPayableInPaise <= 0) {
      throw StateError('Invalid payment quote returned by backend.');
    }
    return quote;
  }

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
        intent.amountInPaise <= 0 ||
        intent.totalPayableInPaise <= 0) {
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

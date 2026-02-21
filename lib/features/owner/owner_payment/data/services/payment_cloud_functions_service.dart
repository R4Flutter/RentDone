import 'package:cloud_functions/cloud_functions.dart';

class PaymentCloudFunctionsService {
  final FirebaseFunctions _functions;

  PaymentCloudFunctionsService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> createRazorpayOrder({
    required String paymentId,
    required int amount,
    required String currency,
    required String receipt,
  }) async {
    final callable = _functions.httpsCallable('createRazorpayOrder');
    final result = await callable.call({
      'paymentId': paymentId,
      'amount': amount,
      'currency': currency,
      'receipt': receipt,
    });

    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> confirmRazorpayPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callable = _functions.httpsCallable('confirmRazorpayPayment');
    await callable.call({
      'paymentId': paymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
  }
}

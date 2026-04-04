import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/payment/data/models/payment_intent_dto.dart';
import 'package:rentdone/features/payment/data/models/payment_quote_dto.dart';

class PaymentFunctionsDataSource {
  final FirebaseFunctions _paymentFunctions;
  final FirebaseFunctions _paymentFunctionsFallback;
  final FirebaseFunctions _quoteFunctions;
  final FirebaseFunctions _razorpayFallbackFunctions;

  PaymentFunctionsDataSource({
    FirebaseFunctions? paymentFunctions,
    FirebaseFunctions? paymentFunctionsFallback,
    FirebaseFunctions? quoteFunctions,
    FirebaseFunctions? razorpayFallbackFunctions,
  }) : _paymentFunctions =
           paymentFunctions ??
           FirebaseFunctions.instanceFor(region: 'us-central1'),
       _paymentFunctionsFallback =
           paymentFunctionsFallback ??
           FirebaseFunctions.instanceFor(region: 'asia-south1'),
       _quoteFunctions =
           quoteFunctions ??
           FirebaseFunctions.instanceFor(region: 'us-central1'),
       _razorpayFallbackFunctions =
           razorpayFallbackFunctions ??
           FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<PaymentIntentDto> createPaymentIntent({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
    int? enteredRentAmountInRupees,
    int? lateFeeAmountInRupees,
  }) async {
    final payload = <String, dynamic>{
      'leaseId': leaseId,
      'month': month,
      'year': year,
      'gateway': gateway,
      'idempotencyKey': idempotencyKey,
    };
    if (enteredRentAmountInRupees != null) {
      payload['enteredRentAmountInRupees'] = enteredRentAmountInRupees;
    }
    if (lateFeeAmountInRupees != null) {
      payload['lateFeeAmountInRupees'] = lateFeeAmountInRupees;
    }

    final result = await _callWithRegionalFallback<Map<dynamic, dynamic>>(
      functionName: 'createPaymentIntent',
      payload: payload,
    );

    return PaymentIntentDto.fromMap(Map<String, dynamic>.from(result));
  }

  Future<PaymentQuoteDto> quotePayment({
    required String leaseId,
    required String gateway,
    int? enteredRentAmountInRupees,
  }) async {
    final callable = _quoteFunctions.httpsCallable('quotePayment');
    final payload = <String, dynamic>{'leaseId': leaseId, 'gateway': gateway};
    if (enteredRentAmountInRupees != null) {
      payload['enteredRentAmountInRupees'] = enteredRentAmountInRupees;
    }

    final result = await callable.call(payload);

    return PaymentQuoteDto.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<void> verifyPayment({
    required String paymentId,
    required String gateway,
    required Map<String, dynamic> payload,
  }) async {
    await _callWithRegionalFallback<dynamic>(
      functionName: 'verifyPayment',
      payload: {'paymentId': paymentId, 'gateway': gateway, 'payload': payload},
    );
  }

  Future<void> confirmRazorpayPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final callable = _razorpayFallbackFunctions.httpsCallable(
      'confirmRazorpayPayment',
    );
    await callable.call({
      'paymentId': paymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
  }

  Future<T> _callWithRegionalFallback<T>({
    required String functionName,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final callable = _paymentFunctions.httpsCallable(functionName);
      final result = await callable.call(payload);
      return result.data as T;
    } on FirebaseFunctionsException catch (primaryError) {
      if (!_shouldTryRegionalFallback(primaryError)) {
        rethrow;
      }
      final fallbackCallable = _paymentFunctionsFallback.httpsCallable(
        functionName,
      );
      final fallbackResult = await fallbackCallable.call(payload);
      return fallbackResult.data as T;
    }
  }

  bool _shouldTryRegionalFallback(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unavailable':
      case 'not-found':
      case 'failed-precondition':
      case 'deadline-exceeded':
      case 'internal':
        return true;
      default:
        return false;
    }
  }
}

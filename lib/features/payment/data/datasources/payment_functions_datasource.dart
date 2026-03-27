import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/payment/data/models/payment_intent_dto.dart';
import 'package:rentdone/features/payment/data/models/payment_quote_dto.dart';

class PaymentFunctionsDataSource {
  final FirebaseFunctions _functions;

  PaymentFunctionsDataSource({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<PaymentIntentDto> createPaymentIntent({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
    int? enteredRentAmountInRupees,
    int? lateFeeAmountInRupees,
  }) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
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

    final result = await callable.call(payload);

    return PaymentIntentDto.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<PaymentQuoteDto> quotePayment({
    required String leaseId,
    required String gateway,
    int? enteredRentAmountInRupees,
  }) async {
    final callable = _functions.httpsCallable('quotePayment');
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
    final callable = _functions.httpsCallable('verifyPayment');
    await callable.call({
      'paymentId': paymentId,
      'gateway': gateway,
      'payload': payload,
    });
  }
}

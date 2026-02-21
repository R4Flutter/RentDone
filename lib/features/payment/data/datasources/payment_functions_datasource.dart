import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/payment/data/models/payment_intent_dto.dart';

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
  }) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
    final result = await callable.call({
      'leaseId': leaseId,
      'month': month,
      'year': year,
      'gateway': gateway,
      'idempotencyKey': idempotencyKey,
    });

    return PaymentIntentDto.fromMap(
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

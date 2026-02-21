import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class CreatePaymentIntent {
  final PaymentRepository _repository;

  const CreatePaymentIntent(this._repository);

  Future<PaymentIntent> call({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
  }) {
    return _repository.createPaymentIntent(
      leaseId: leaseId,
      month: month,
      year: year,
      gateway: gateway,
      idempotencyKey: idempotencyKey,
    );
  }
}

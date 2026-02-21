import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class MarkPaymentPaidCash {
  final PaymentRepository _repository;

  const MarkPaymentPaidCash(this._repository);

  Future<void> call(String paymentId) {
    return _repository.markPaymentPaidCash(paymentId);
  }
}

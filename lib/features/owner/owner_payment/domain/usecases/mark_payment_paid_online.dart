import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class MarkPaymentPaidOnline {
  final PaymentRepository _repository;

  const MarkPaymentPaidOnline(this._repository);

  Future<void> call(String paymentId, {String? transactionId}) {
    return _repository.markPaymentPaidOnline(
      paymentId,
      transactionId: transactionId,
    );
  }
}

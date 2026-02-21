import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class PreventDuplicatePayment {
  final PaymentRepository _repository;

  const PreventDuplicatePayment(this._repository);

  Future<bool> call({
    required String leaseId,
    required int month,
    required int year,
  }) {
    return _repository.preventDuplicatePayment(
      leaseId: leaseId,
      month: month,
      year: year,
    );
  }
}

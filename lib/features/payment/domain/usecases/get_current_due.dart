import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class GetCurrentDue {
  final PaymentRepository _repository;

  const GetCurrentDue(this._repository);

  Future<PaymentDue?> call({required String tenantId}) {
    return _repository.getCurrentDue(tenantId: tenantId);
  }
}

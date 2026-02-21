import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class WatchPayments {
  final PaymentRepository _repository;

  const WatchPayments(this._repository);

  Stream<List<Payment>> call() {
    return _repository.watchPayments();
  }
}

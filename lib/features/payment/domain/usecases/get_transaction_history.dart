import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class GetTransactionHistory {
  final PaymentRepository _repository;

  const GetTransactionHistory(this._repository);

  Future<TransactionPage> call({
    required TransactionActor actor,
    required String actorId,
    required int limit,
    int? year,
    String? status,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  }) {
    return _repository.getTransactionHistory(
      actor: actor,
      actorId: actorId,
      limit: limit,
      year: year,
      status: status,
      startAfterCreatedAt: startAfterCreatedAt,
      startAfterDocId: startAfterDocId,
    );
  }
}

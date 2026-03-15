import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/payment/data/datasources/transaction_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/repositories/payment_failure_mapper.dart';
import 'package:rentdone/features/payment/data/repositories/transaction_page_builder.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class TransactionHistoryLoader {
  final TransactionFirestoreDataSource _transaction;

  TransactionHistoryLoader(this._transaction);

  Future<TransactionPage> load({
    required TransactionActor actor,
    required String actorId,
    required int limit,
    int? year,
    String? status,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  }) async {
    try {
      final field = actor == TransactionActor.tenant ? 'tenantId' : 'ownerId';
      final snap = await _transaction.getTransactions(
        field: field,
        value: actorId,
        limit: limit,
        year: year,
        status: status,
        startAfterCreatedAt: startAfterCreatedAt,
        startAfterDocId: startAfterDocId,
      );
      return TransactionPageBuilder(
        snapshot: snap,
        year: year ?? 0,
        status: status,
        limit: limit,
        startAfterCreatedAt: startAfterCreatedAt,
        startAfterDocId: startAfterDocId,
      ).build();
    } on FirebaseException catch (error) {
      throw PaymentFailureMapper.mapFirebaseFailure(error);
    } catch (_) {
      throw const ServerFailure('Unable to load transactions');
    }
  }
}

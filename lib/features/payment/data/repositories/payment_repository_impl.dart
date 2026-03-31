import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/payment/data/datasources/index.dart';
import 'package:rentdone/features/payment/data/repositories/index.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl
    with PaymentRepositoryDuplicateMixin
    implements PaymentRepository {
  final PaymentDueBuilder _dueBuilder;
  final PaymentIntentService _intentService;
  final PaymentDuplicateChecker _duplicateChecker;
  final TransactionHistoryLoader _historyLoader;

  @override
  PaymentDuplicateChecker get duplicateChecker => _duplicateChecker;

  PaymentRepositoryImpl(
    LeaseFirestoreDataSource lease,
    PaymentFirestoreDataSource payment,
    TransactionFirestoreDataSource transaction,
    PaymentFunctionsDataSource functions,
    FirebaseAuth auth,
  ) : _dueBuilder = PaymentDueBuilder(lease, payment, transaction),
      _intentService = PaymentIntentService(functions, auth),
      _duplicateChecker = PaymentDuplicateChecker(payment),
      _historyLoader = TransactionHistoryLoader(transaction);

  @override
  Future<PaymentDue?> getCurrentDue({required String tenantId}) =>
      _dueBuilder.build(tenantId);

  @override
  Future<PaymentIntent> createPaymentIntent({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
  }) => _intentService.create(
    leaseId: leaseId,
    month: month,
    year: year,
    gateway: gateway,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> verifyPayment({
    required String paymentId,
    required String gateway,
    required Map<String, dynamic> payload,
  }) => _intentService.verify(
    paymentId: paymentId,
    gateway: gateway,
    payload: payload,
  );

  @override
  Future<TransactionPage> getTransactionHistory({
    required TransactionActor actor,
    required String actorId,
    required int limit,
    int? year,
    String? status,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  }) => _historyLoader.load(
    actor: actor,
    actorId: actorId,
    limit: limit,
    year: year,
    status: status,
    startAfterCreatedAt: startAfterCreatedAt,
    startAfterDocId: startAfterDocId,
  );
}

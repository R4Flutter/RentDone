import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_actor.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';

class TransactionPage {
  final List<TransactionRecord> items;
  final DateTime? nextCreatedAt;
  final String? nextDocId;
  final bool hasMore;

  const TransactionPage({
    required this.items,
    required this.nextCreatedAt,
    required this.nextDocId,
    required this.hasMore,
  });
}

abstract class PaymentRepository {
  Future<PaymentDue?> getCurrentDue({required String tenantId});

  Future<PaymentIntent> createPaymentIntent({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
  });

  Future<void> verifyPayment({
    required String paymentId,
    required String gateway,
    required Map<String, dynamic> payload,
  });

  Future<TransactionPage> getTransactionHistory({
    required TransactionActor actor,
    required String actorId,
    required int limit,
    int? year,
    String? status,
    DateTime? startAfterCreatedAt,
    String? startAfterDocId,
  });

  Future<bool> preventDuplicatePayment({
    required String leaseId,
    required int month,
    required int year,
  });
}

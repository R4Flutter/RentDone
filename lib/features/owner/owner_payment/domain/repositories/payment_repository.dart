import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';

abstract class PaymentRepository {
  Stream<List<Payment>> watchPayments();

  Future<void> markPaymentPaidCash(String paymentId);

  Future<void> markPaymentPaidOnline(String paymentId, {String? transactionId});
}

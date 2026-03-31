import '../entities/payment_entity.dart';

/// Repository interface for payment management
abstract class PaymentRepository {
  /// Record a payment
  Future<void> recordPayment(PaymentEntity payment);

  /// Get payment history for tenant
  Future<List<PaymentEntity>> getPaymentHistory(
    String tenantId, {
    required int limit,
    required int page,
  });

  /// Get all unpaid/pending payments for owner
  Future<List<PaymentEntity>> getPendingPayments(String ownerId);

  /// Get payments by month
  Future<List<PaymentEntity>> getPaymentsByMonth(
    String ownerId,
    String monthFor,
  );

  /// Update payment status
  Future<void> updatePaymentStatus(String paymentId, String status);

  /// Get total amount received in month
  Future<int> getMonthlyRevenue(String ownerId);

  /// Get pending amount due
  Future<int> getPendingAmount(String ownerId);

  /// Get overdue amount
  Future<int> getOverdueAmount(String ownerId);
}

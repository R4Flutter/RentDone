import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/payment_entity.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../data/di/tenant_management_di.dart';

/// Use case: Record payment
final recordPaymentUseCaseProvider = Provider<RecordPaymentUseCase>((ref) {
  final repository = ref.watch(paymentRepositoryProvider);
  return RecordPaymentUseCase(repository);
});

class RecordPaymentUseCase {
  final PaymentRepository _repository;

  RecordPaymentUseCase(this._repository);

  Future<void> call(PaymentEntity payment) {
    return _repository.recordPayment(payment);
  }
}

/// Use case: Get payment history
final getPaymentHistoryUseCaseProvider = Provider<GetPaymentHistoryUseCase>((
  ref,
) {
  final repository = ref.watch(paymentRepositoryProvider);
  return GetPaymentHistoryUseCase(repository);
});

class GetPaymentHistoryUseCase {
  final PaymentRepository _repository;

  GetPaymentHistoryUseCase(this._repository);

  Future<List<PaymentEntity>> call(
    String tenantId, {
    required int limit,
    required int page,
  }) {
    return _repository.getPaymentHistory(tenantId, limit: limit, page: page);
  }
}

/// Use case: Get pending payments
final getPendingPaymentsUseCaseProvider = Provider<GetPendingPaymentsUseCase>((
  ref,
) {
  final repository = ref.watch(paymentRepositoryProvider);
  return GetPendingPaymentsUseCase(repository);
});

class GetPendingPaymentsUseCase {
  final PaymentRepository _repository;

  GetPendingPaymentsUseCase(this._repository);

  Future<List<PaymentEntity>> call(String ownerId) {
    return _repository.getPendingPayments(ownerId);
  }
}

/// Use case: Get payment analytics
final getPaymentAnalyticsUseCaseProvider = Provider<GetPaymentAnalyticsUseCase>(
  (ref) {
    final repository = ref.watch(paymentRepositoryProvider);
    return GetPaymentAnalyticsUseCase(repository);
  },
);

class GetPaymentAnalyticsUseCase {
  final PaymentRepository _repository;

  GetPaymentAnalyticsUseCase(this._repository);

  Future<({int monthlyRevenue, int pending, int overdue})> call(
    String ownerId,
  ) async {
    final monthlyRevenue = await _repository.getMonthlyRevenue(ownerId);
    final pending = await _repository.getPendingAmount(ownerId);
    final overdue = await _repository.getOverdueAmount(ownerId);

    return (monthlyRevenue: monthlyRevenue, pending: pending, overdue: overdue);
  }
}

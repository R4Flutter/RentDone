import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/payment_entity.dart';
import '../../domain/usecases/payment_usecases.dart';

/// Provider: Get payment history for tenant
final paymentHistoryProvider =
    FutureProvider.family<List<PaymentEntity>, ({String tenantId, int page})>((
      ref,
      params,
    ) async {
      final useCase = ref.watch(getPaymentHistoryUseCaseProvider);
      return useCase.call(params.tenantId, limit: 20, page: params.page);
    });

/// Provider: Get pending payments
final pendingPaymentsProvider =
    FutureProvider.family<List<PaymentEntity>, String>((ref, ownerId) async {
      final useCase = ref.watch(getPendingPaymentsUseCaseProvider);
      return useCase.call(ownerId);
    });

/// Provider: Payment analytics
final paymentAnalyticsProvider =
    FutureProvider.family<
      ({int monthlyRevenue, int pending, int overdue}),
      String
    >((ref, ownerId) async {
      final useCase = ref.watch(getPaymentAnalyticsUseCaseProvider);
      return useCase.call(ownerId);
    });

/// Notifier for managing payments
class PaymentNotifier extends Notifier<AsyncValue<void>> {
  late RecordPaymentUseCase _recordUseCase;

  @override
  AsyncValue<void> build() {
    _recordUseCase = ref.watch(recordPaymentUseCaseProvider);
    return const AsyncValue.data(null);
  }

  Future<void> recordPayment(PaymentEntity payment) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _recordUseCase.call(payment));
  }
}

final paymentNotifierProvider =
    NotifierProvider<PaymentNotifier, AsyncValue<void>>(() {
      return PaymentNotifier();
    });

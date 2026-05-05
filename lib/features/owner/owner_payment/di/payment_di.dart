import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_payment/data/repositories/payment_repository_impl.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_analytics_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_query_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_write_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/mark_payment_paid_cash.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/mark_payment_paid_online.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/watch_payments.dart';

// Specialized Services
final paymentQueryServiceProvider = Provider<PaymentQueryService>((ref) => PaymentQueryService());
final paymentWriteServiceProvider = Provider<PaymentWriteService>((ref) => PaymentWriteService());
final paymentAnalyticsServiceProvider = Provider<PaymentAnalyticsService>((ref) => PaymentAnalyticsService());

// Repository
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(
    queryService: ref.watch(paymentQueryServiceProvider),
    writeService: ref.watch(paymentWriteServiceProvider),
    analyticsService: ref.watch(paymentAnalyticsServiceProvider),
  );
});

// Use Cases
final watchPaymentsUseCaseProvider = Provider<WatchPayments>((ref) {
  return WatchPayments(ref.watch(paymentRepositoryProvider));
});

final markPaymentPaidCashUseCaseProvider = Provider<MarkPaymentPaidCash>((ref) {
  return MarkPaymentPaidCash(ref.watch(paymentRepositoryProvider));
});

final markPaymentPaidOnlineUseCaseProvider = Provider<MarkPaymentPaidOnline>((ref) {
  return MarkPaymentPaidOnline(ref.watch(paymentRepositoryProvider));
});

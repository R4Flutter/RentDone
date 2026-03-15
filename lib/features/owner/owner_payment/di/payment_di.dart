import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_payment/data/repositories/payment_repository_impl.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_firebase_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/mark_payment_paid_cash.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/mark_payment_paid_online.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/watch_payments.dart';

final paymentFirebaseServiceProvider = Provider<PaymentFirebaseService>((ref) {
  return PaymentFirebaseService();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final firebaseService = ref.watch(paymentFirebaseServiceProvider);
  return PaymentRepositoryImpl(firebaseService);
});

final watchPaymentsUseCaseProvider = Provider<WatchPayments>((ref) {
  return WatchPayments(ref.watch(paymentRepositoryProvider));
});

final markPaymentPaidCashUseCaseProvider = Provider<MarkPaymentPaidCash>((ref) {
  return MarkPaymentPaidCash(ref.watch(paymentRepositoryProvider));
});

final markPaymentPaidOnlineUseCaseProvider = Provider<MarkPaymentPaidOnline>((
  ref,
) {
  return MarkPaymentPaidOnline(ref.watch(paymentRepositoryProvider));
});

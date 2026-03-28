import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_payment/di/payment_di.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';

export 'package:rentdone/features/owner/owner_payment/di/payment_di.dart'
    show
        markPaymentPaidCashUseCaseProvider,
        markPaymentPaidOnlineUseCaseProvider;

final paymentsProvider = StreamProvider.autoDispose<List<Payment>>((ref) {
  final watchPayments = ref.watch(watchPaymentsUseCaseProvider);
  return watchPayments();
});

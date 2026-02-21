import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_payment/data/repositories/payment_repository_impl.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_cloud_functions_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_firebase_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/confirm_razorpay_payment.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/create_razorpay_order.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/mark_payment_paid_cash.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/mark_payment_paid_online.dart';
import 'package:rentdone/features/owner/owner_payment/domain/usecases/watch_payments.dart';

final paymentFirebaseServiceProvider = Provider<PaymentFirebaseService>((ref) {
  return PaymentFirebaseService();
});

final paymentCloudFunctionsServiceProvider =
    Provider<PaymentCloudFunctionsService>((ref) {
      return PaymentCloudFunctionsService();
    });

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final firebaseService = ref.watch(paymentFirebaseServiceProvider);
  final functionsService = ref.watch(paymentCloudFunctionsServiceProvider);
  return PaymentRepositoryImpl(firebaseService, functionsService);
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

final createRazorpayOrderUseCaseProvider = Provider<CreateRazorpayOrder>((ref) {
  return CreateRazorpayOrder(ref.watch(paymentRepositoryProvider));
});

final confirmRazorpayPaymentUseCaseProvider = Provider<ConfirmRazorpayPayment>((
  ref,
) {
  return ConfirmRazorpayPayment(ref.watch(paymentRepositoryProvider));
});

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/payment/data/datasources/lease_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/datasources/payment_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/datasources/payment_functions_datasource.dart';
import 'package:rentdone/features/payment/data/datasources/transaction_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/gateways/stripe_service.dart';
import 'package:rentdone/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';
import 'package:rentdone/features/payment/domain/usecases/calculate_late_fee.dart';
import 'package:rentdone/features/payment/domain/usecases/create_payment_intent.dart';
import 'package:rentdone/features/payment/domain/usecases/get_current_due.dart';
import 'package:rentdone/features/payment/domain/usecases/get_transaction_history.dart';
import 'package:rentdone/features/payment/domain/usecases/prevent_duplicate_payment.dart';
import 'package:rentdone/features/payment/domain/usecases/verify_payment.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/razorpay_service.dart';

final leaseFirestoreDataSourceProvider = Provider<LeaseFirestoreDataSource>(
  (ref) => LeaseFirestoreDataSource(),
);

final paymentFirestoreDataSourceProvider = Provider<PaymentFirestoreDataSource>(
  (ref) => PaymentFirestoreDataSource(),
);

final transactionFirestoreDataSourceProvider =
    Provider<TransactionFirestoreDataSource>(
      (ref) => TransactionFirestoreDataSource(),
    );

final paymentFunctionsDataSourceProvider = Provider<PaymentFunctionsDataSource>(
  (ref) => PaymentFunctionsDataSource(),
);

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(
    ref.watch(leaseFirestoreDataSourceProvider),
    ref.watch(paymentFirestoreDataSourceProvider),
    ref.watch(transactionFirestoreDataSourceProvider),
    ref.watch(paymentFunctionsDataSourceProvider),
    FirebaseAuth.instance,
  );
});

final stripeGatewayProvider = Provider<StripeService>((ref) {
  return StripeService();
});

final getCurrentDueUseCaseProvider = Provider<GetCurrentDue>((ref) {
  return GetCurrentDue(ref.watch(paymentRepositoryProvider));
});

final createPaymentIntentUseCaseProvider = Provider<CreatePaymentIntent>((ref) {
  return CreatePaymentIntent(ref.watch(paymentRepositoryProvider));
});

final verifyPaymentUseCaseProvider = Provider<VerifyPayment>((ref) {
  return VerifyPayment(ref.watch(paymentRepositoryProvider));
});

final getTransactionHistoryUseCaseProvider = Provider<GetTransactionHistory>((
  ref,
) {
  return GetTransactionHistory(ref.watch(paymentRepositoryProvider));
});

final preventDuplicatePaymentUseCaseProvider =
    Provider<PreventDuplicatePayment>((ref) {
      return PreventDuplicatePayment(ref.watch(paymentRepositoryProvider));
    });

final calculateLateFeeUseCaseProvider = Provider<CalculateLateFee>((ref) {
  return CalculateLateFee();
});

final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  const key = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_SWZErkO7aPAnNO',
  );
  final service = RazorpayService(razorpayKey: key);
  ref.onDispose(service.dispose);
  return service;
});

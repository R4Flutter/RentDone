import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_payment/data/models/payment_model.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_firebase_service.dart';

final paymentFirebaseServiceProvider = Provider<PaymentFirebaseService>((ref) {
  return PaymentFirebaseService();
});

final paymentsProvider = StreamProvider<List<Payment>>((ref) {
  final service = ref.watch(paymentFirebaseServiceProvider);
  return service.watchPayments();
});

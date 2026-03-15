import 'package:rentdone/features/owner/owner_payment/data/services/payment_firebase_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentFirebaseService _firebaseService;

  PaymentRepositoryImpl(this._firebaseService);

  @override
  Stream<List<Payment>> watchPayments() {
    return _firebaseService.watchPayments().map((dtos) {
      return dtos.map((dto) => dto.toEntity()).toList();
    });
  }

  @override
  Future<void> markPaymentPaidCash(String paymentId) {
    return _firebaseService.markPaymentPaidCash(paymentId);
  }

  @override
  Future<void> markPaymentPaidOnline(
    String paymentId, {
    String? transactionId,
  }) {
    return _firebaseService.markPaymentPaidOnline(
      paymentId,
      transactionId: transactionId,
    );
  }
}

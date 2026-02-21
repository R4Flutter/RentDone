import 'package:rentdone/features/owner/owner_payment/data/models/razorpay_order_dto.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_cloud_functions_service.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/payment_firebase_service.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/razorpay_order.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentFirebaseService _firebaseService;
  final PaymentCloudFunctionsService _functionsService;

  PaymentRepositoryImpl(this._firebaseService, this._functionsService);

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

  @override
  Future<RazorpayOrder> createRazorpayOrder({
    required String paymentId,
    required int amountInPaise,
    required String currency,
    required String receipt,
  }) async {
    final data = await _functionsService.createRazorpayOrder(
      paymentId: paymentId,
      amount: amountInPaise,
      currency: currency,
      receipt: receipt,
    );
    final dto = RazorpayOrderDto.fromMap(data);
    return dto.toEntity();
  }

  @override
  Future<void> confirmRazorpayPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) {
    return _functionsService.confirmRazorpayPayment(
      paymentId: paymentId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
  }
}

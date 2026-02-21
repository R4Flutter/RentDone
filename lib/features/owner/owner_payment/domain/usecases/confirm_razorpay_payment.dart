import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class ConfirmRazorpayPayment {
  final PaymentRepository _repository;

  const ConfirmRazorpayPayment(this._repository);

  Future<void> call({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) {
    return _repository.confirmRazorpayPayment(
      paymentId: paymentId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
    );
  }
}

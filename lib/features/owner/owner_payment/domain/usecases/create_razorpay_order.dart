import 'package:rentdone/features/owner/owner_payment/domain/entities/razorpay_order.dart';
import 'package:rentdone/features/owner/owner_payment/domain/repositories/payment_repository.dart';

class CreateRazorpayOrder {
  final PaymentRepository _repository;

  const CreateRazorpayOrder(this._repository);

  Future<RazorpayOrder> call({
    required String paymentId,
    required int amountInPaise,
    required String currency,
    required String receipt,
  }) {
    return _repository.createRazorpayOrder(
      paymentId: paymentId,
      amountInPaise: amountInPaise,
      currency: currency,
      receipt: receipt,
    );
  }
}

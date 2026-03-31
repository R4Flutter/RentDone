import 'package:rentdone/features/payment/domain/repositories/payment_repository.dart';

class VerifyPayment {
  final PaymentRepository _repository;

  const VerifyPayment(this._repository);

  Future<void> call({
    required String paymentId,
    required String gateway,
    required Map<String, dynamic> payload,
  }) {
    return _repository.verifyPayment(
      paymentId: paymentId,
      gateway: gateway,
      payload: payload,
    );
  }
}

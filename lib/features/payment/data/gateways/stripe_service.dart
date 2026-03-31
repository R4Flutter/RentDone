import 'payment_gateway.dart';

class StripeService implements PaymentGateway {
  @override
  Future<PaymentGatewayResult> initializePayment(
    PaymentGatewayRequest request,
  ) async {
    return const PaymentGatewayResult(
      isSuccess: false,
      failureReason: 'Stripe client not configured',
    );
  }

  @override
  Future<void> verifyPayment(Map<String, dynamic> payload) async {
    return;
  }

  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {
    return;
  }
}

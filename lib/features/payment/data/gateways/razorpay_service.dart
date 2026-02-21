import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_gateway.dart';

class RazorpayService implements PaymentGateway {
  final Razorpay _razorpay = Razorpay();

  @override
  Future<PaymentGatewayResult> initializePayment(
    PaymentGatewayRequest request,
  ) async {
    final completer = Completer<PaymentGatewayResult>();

    void handleSuccess(PaymentSuccessResponse response) {
      if (completer.isCompleted) return;
      completer.complete(
        PaymentGatewayResult(
          isSuccess: true,
          gatewayPaymentId: response.paymentId,
          orderId: response.orderId,
          signature: response.signature,
        ),
      );
    }

    void handleError(PaymentFailureResponse response) {
      if (completer.isCompleted) return;
      completer.complete(
        PaymentGatewayResult(
          isSuccess: false,
          failureReason: response.message ?? 'Payment failed',
        ),
      );
    }

    void handleExternal(ExternalWalletResponse response) {
      if (completer.isCompleted) return;
      completer.complete(
        PaymentGatewayResult(
          isSuccess: false,
          failureReason: 'External wallet selected',
        ),
      );
    }

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handleError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternal);

    _razorpay.open({
      'key': request.gatewayKey,
      'amount': request.amount,
      'currency': request.currency,
      'order_id': request.orderId,
      'name': 'RentDone',
      'description': 'Rent payment',
      'prefill': {'email': request.tenantEmail, 'contact': request.tenantPhone},
      'notes': {'paymentId': request.paymentId},
    });

    final result = await completer.future;
    _razorpay.clear();
    return result;
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

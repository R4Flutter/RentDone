import 'dart:async';

import 'package:rentdone/features/payment/data/gateways/payment_gateway.dart';
import 'package:rentdone/features/owner/owner_payment/data/services/razorpay_service.dart';
import 'package:rentdone/features/owner/owner_payment/models/payment_state.dart';

class TenantRazorpayGatewayAdapter implements PaymentGateway {
  TenantRazorpayGatewayAdapter(this._razorpayService);

  final RazorpayService _razorpayService;

  static const Duration _paymentTimeout = Duration(minutes: 5);

  @override
  Future<PaymentGatewayResult> initializePayment(
    PaymentGatewayRequest request,
  ) async {
    StreamSubscription<PaymentResponse>? responseSub;

    try {
      final completer = Completer<PaymentGatewayResult>();

      responseSub = _razorpayService.paymentResponseStream.listen((response) {
        if (completer.isCompleted) {
          return;
        }

        if (!response.isSuccess) {
          completer.complete(
            PaymentGatewayResult(
              isSuccess: false,
              failureReason: response.error ?? 'Payment failed',
            ),
          );
          return;
        }

        final paymentId = response.transactionId.trim();
        final orderId = response.orderId.trim();
        final signature = response.signature.trim();

        if (paymentId.isEmpty || orderId.isEmpty || signature.isEmpty) {
          completer.complete(
            const PaymentGatewayResult(
              isSuccess: false,
              failureReason: 'Incomplete payment response from gateway',
            ),
          );
          return;
        }

        completer.complete(
          PaymentGatewayResult(
            isSuccess: true,
            gatewayPaymentId: paymentId,
            orderId: orderId,
            signature: signature,
          ),
        );
      });

      final initiated = await _razorpayService.initiatePayment(
        paymentRequest: PaymentRequest(
          orderId: request.orderId,
          key: request.gatewayKey,
          amount: request.amount,
          currency: request.currency,
          email: request.tenantEmail,
          phone: request.tenantPhone,
          description: 'Monthly rent payment',
          metadata: {'paymentId': request.paymentId},
        ),
        tenantId: '',
        propertyId: '',
      );

      if (!initiated) {
        final message = _razorpayService.lastPaymentError?.message.trim() ?? '';
        return PaymentGatewayResult(
          isSuccess: false,
          failureReason: message.isEmpty
              ? 'Unable to start payment right now.'
              : message,
        );
      }

      return await completer.future.timeout(
        _paymentTimeout,
        onTimeout: () => const PaymentGatewayResult(
          isSuccess: false,
          failureReason: 'Payment timed out. Please try again.',
        ),
      );
    } catch (error) {
      return PaymentGatewayResult(
        isSuccess: false,
        failureReason: error.toString(),
      );
    } finally {
      await responseSub?.cancel();
    }
  }

  @override
  Future<void> verifyPayment(Map<String, dynamic> payload) async {}

  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {}
}

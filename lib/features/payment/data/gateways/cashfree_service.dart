import 'dart:async';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'payment_gateway.dart';

class CashfreeService implements PaymentGateway {
  final bool isSandbox;

  CashfreeService({this.isSandbox = false});

  @override
  Future<PaymentGatewayResult> initializePayment(
    PaymentGatewayRequest request,
  ) async {
    final paymentSessionId = request.paymentSessionId;
    if (paymentSessionId == null || paymentSessionId.isEmpty) {
      return const PaymentGatewayResult(
        isSuccess: false,
        failureReason: 'Cashfree payment session ID is missing',
      );
    }

    try {
      final session = CFSessionBuilder()
          .setEnvironment(
            isSandbox ? CFEnvironment.SANDBOX : CFEnvironment.PRODUCTION,
          )
          .setOrderId(request.orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final cfPayment = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .build();
      final completer = Completer<PaymentGatewayResult>();

      CFPaymentGatewayService().setCallback(
        (orderId) {
          if (!completer.isCompleted) {
            completer.complete(
              PaymentGatewayResult(
                isSuccess: true,
                orderId: orderId,
                gatewayPaymentId: orderId,
              ),
            );
          }
        },
        (CFErrorResponse error, String orderId) {
          if (!completer.isCompleted) {
            completer.complete(
              PaymentGatewayResult(
                isSuccess: false,
                orderId: orderId.isNotEmpty ? orderId : request.orderId,
                failureReason: error.getMessage() ?? 'Payment failed',
              ),
            );
          }
        },
      );

      CFPaymentGatewayService().doPayment(cfPayment);
      return completer.future;
    } catch (e) {
      return PaymentGatewayResult(
        isSuccess: false,
        failureReason: e.toString(),
      );
    }
  }

  @override
  Future<void> verifyPayment(Map<String, dynamic> payload) async {}

  @override
  Future<void> handleWebhook(Map<String, dynamic> payload) async {}
}

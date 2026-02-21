import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/razorpay_order.dart';

abstract class PaymentRepository {
  Stream<List<Payment>> watchPayments();

  Future<void> markPaymentPaidCash(String paymentId);

  Future<void> markPaymentPaidOnline(String paymentId, {String? transactionId});

  Future<RazorpayOrder> createRazorpayOrder({
    required String paymentId,
    required int amountInPaise,
    required String currency,
    required String receipt,
  });

  Future<void> confirmRazorpayPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/payment/data/datasources/payment_functions_datasource.dart';
import 'package:rentdone/features/payment/data/repositories/payment_failure_mapper.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:rentdone/features/payment/domain/entities/payment_intent.dart';

class PaymentIntentService {
  final PaymentFunctionsDataSource _functions;
  final FirebaseAuth _auth;

  PaymentIntentService(this._functions, this._auth);

  Future<PaymentIntent> create({
    required String leaseId,
    required int month,
    required int year,
    required String gateway,
    required String idempotencyKey,
  }) async {
    _requireAuth();
    try {
      final dto = await _functions.createPaymentIntent(
        leaseId: leaseId,
        month: month,
        year: year,
        gateway: gateway,
        idempotencyKey: idempotencyKey,
      );
      return dto.toEntity();
    } on FirebaseFunctionsException catch (error) {
      throw PaymentFailureMapper.mapFunctionsFailure(error);
    } catch (error) {
      throw const ServerFailure('Unable to create payment intent');
    }
  }

  Future<void> verify({
    required String paymentId,
    required String gateway,
    required Map<String, dynamic> payload,
  }) async {
    _requireAuth();
    try {
      await _functions.verifyPayment(
        paymentId: paymentId,
        gateway: gateway,
        payload: payload,
      );
    } on FirebaseFunctionsException catch (error) {
      final normalizedGateway = gateway.trim().toLowerCase();
      if (normalizedGateway == 'razorpay' &&
          _shouldTryRazorpayFallback(error)) {
        final orderId = (payload['orderId'] ?? '').toString().trim();
        final razorpayPaymentId = (payload['paymentId'] ?? '')
            .toString()
            .trim();
        final signature = (payload['signature'] ?? '').toString().trim();

        if (orderId.isNotEmpty &&
            razorpayPaymentId.isNotEmpty &&
            signature.isNotEmpty) {
          try {
            await _functions.confirmRazorpayPayment(
              paymentId: paymentId,
              razorpayOrderId: orderId,
              razorpayPaymentId: razorpayPaymentId,
              razorpaySignature: signature,
            );
            return;
          } on FirebaseFunctionsException catch (fallbackError) {
            throw PaymentFailureMapper.mapFunctionsFailure(fallbackError);
          }
        }
      }
      throw PaymentFailureMapper.mapFunctionsFailure(error);
    } catch (error) {
      throw const ServerFailure('Payment verification failed');
    }
  }

  bool _shouldTryRazorpayFallback(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unavailable':
      case 'not-found':
      case 'failed-precondition':
      case 'permission-denied':
      case 'invalid-argument':
        return true;
      default:
        return false;
    }
  }

  void _requireAuth() {
    if (_auth.currentUser == null) {
      throw const UnauthorizedFailure();
    }
  }
}

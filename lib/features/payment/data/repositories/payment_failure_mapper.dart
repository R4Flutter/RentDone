import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';

class PaymentFailureMapper {
  static String _normalizeFunctionMessage(String? message) {
    return (message ?? '').trim().toLowerCase();
  }

  static String _friendlyFunctionsMessage(FirebaseFunctionsException error) {
    final message = _normalizeFunctionMessage(error.message);

    if (error.code == 'unavailable') {
      return 'Payment backend unavailable. If testing locally, start Firebase emulators and run app with USE_FUNCTIONS_EMULATOR=true.';
    }

    if (error.code == 'failed-precondition') {
      if (message.contains('email-not-verified')) {
        return 'Verify your email first, then retry payment.';
      }
      if (message.contains('app check') ||
          message.contains('app-check') ||
          message.contains('app_check')) {
        return 'App integrity check failed. Update the app to latest version and try again.';
      }
      if (message.contains('maintenance-mode')) {
        return 'Payments are temporarily paused for maintenance.';
      }
      if (message.contains('payments-disabled')) {
        return 'Payments are currently disabled by admin settings.';
      }
      if (message.contains('razorpay-disabled')) {
        return 'Razorpay is currently disabled by admin settings.';
      }
      if (message.contains('invalid-owner') ||
          message.contains('tenant-link') ||
          message.contains('property-name-mismatch')) {
        return 'Tenant-property link is invalid. Ask owner to reassign tenant to the correct property.';
      }
      if (message.contains('duplicate-payment') ||
          message.contains('already-exists')) {
        return 'A previous payment attempt is still being processed. Wait 20-30 seconds and try again.';
      }
      if (message.contains('razorpay secret not configured') ||
          message.contains('razorpay keys not configured')) {
        return 'Payment gateway is not configured on backend. Contact support.';
      }
      if (message.contains('razorpay mode-key mismatch')) {
        return 'Razorpay test/live configuration mismatch on backend. Switch backend mode to test or update keys.';
      }
      if (message.contains('order id does not match')) {
        return 'Payment verification failed due to order mismatch. Please retry from Pay Now.';
      }
    }

    if (error.code == 'internal') {
      if (message.contains('verification-failed')) {
        return 'Payment verification is taking longer than expected. Please wait a moment; the backend will auto-reconcile this payment. Do not retry immediately to avoid duplicates.';
      }
    }

    if (error.code == 'permission-denied') {
      if (message.contains('invalid razorpay signature') ||
          message.contains('invalid-signature')) {
        return 'Razorpay verification failed. If money was deducted, it will be reconciled automatically or you can contact support with your Razorpay payment ID.';
      }
    }

    if (error.code == 'not-found') {
      return 'Payment service not found. Deploy Cloud Functions or switch to emulator mode.';
    }

    if (error.code == 'resource-exhausted') {
      return 'Too many payment attempts. Please wait a minute and try again.';
    }

    if (message.isNotEmpty) {
      return error.message!.trim();
    }
    return 'Payment service error. Please try again.';
  }

  static PaymentFailure mapFirebaseFailure(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return const UnauthorizedFailure();
      case 'unavailable':
        return const NetworkFailure();
      default:
        return ServerFailure(error.message ?? 'Database error');
    }
  }

  static PaymentFailure mapFunctionsFailure(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return const UnauthorizedFailure();
      case 'permission-denied':
        return UnauthorizedFailure(_friendlyFunctionsMessage(error));
      case 'unavailable':
        return NetworkFailure(_friendlyFunctionsMessage(error));
      case 'invalid-argument':
        return ValidationFailure(_friendlyFunctionsMessage(error));
      case 'failed-precondition':
        return ValidationFailure(_friendlyFunctionsMessage(error));
      case 'not-found':
        return NotFoundFailure(_friendlyFunctionsMessage(error));
      case 'resource-exhausted':
        return ValidationFailure(_friendlyFunctionsMessage(error));
      default:
        return ServerFailure(_friendlyFunctionsMessage(error));
    }
  }
}

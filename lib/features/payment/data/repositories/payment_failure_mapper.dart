import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';

class PaymentFailureMapper {
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
      case 'unavailable':
        return const NetworkFailure();
      case 'invalid-argument':
        return ValidationFailure(error.message ?? 'Invalid input');
      case 'not-found':
        return NotFoundFailure(error.message ?? 'Not found');
      default:
        return ServerFailure(error.message ?? 'Function error');
    }
  }
}

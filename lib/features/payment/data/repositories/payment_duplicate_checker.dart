import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/payment/data/datasources/payment_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/repositories/payment_failure_mapper.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';

class PaymentDuplicateChecker {
  final PaymentFirestoreDataSource _payment;

  PaymentDuplicateChecker(this._payment);

  Future<bool> isDuplicate({
    required String leaseId,
    required int month,
    required int year,
  }) async {
    try {
      final existing = await _payment.getPaymentForLeaseMonth(
        leaseId: leaseId,
        month: month,
        year: year,
      );
      final status = existing?['status'] as String? ?? '';
      return status == 'paid' || status == 'success';
    } on FirebaseException catch (error) {
      throw PaymentFailureMapper.mapFirebaseFailure(error);
    } catch (error) {
      throw const ServerFailure('Unable to check payment status');
    }
  }
}

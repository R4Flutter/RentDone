import 'package:rentdone/features/payment/data/datasources/lease_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/datasources/payment_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/datasources/transaction_firestore_datasource.dart';
import 'package:rentdone/features/payment/data/repositories/datetime_converter.dart';
import 'package:rentdone/features/payment/data/repositories/payment_failure_mapper.dart';
import 'package:rentdone/features/payment/domain/entities/payment_due.dart';
import 'package:rentdone/features/payment/domain/entities/payment_failure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentDueBuilder {
  final LeaseFirestoreDataSource _lease;
  final PaymentFirestoreDataSource _payment;
  final TransactionFirestoreDataSource _transaction;

  PaymentDueBuilder(this._lease, this._payment, this._transaction);

  Future<PaymentDue?> build(String tenantId) async {
    try {
      final lease = await _lease.getActiveLeaseForTenant(tenantId);
      if (lease == null) return null;

      final now = DateTime.now();
      final payment = await _payment.getPaymentForLeaseMonth(
        leaseId: lease['id'],
        month: now.month,
        year: now.year,
      );

      final rentAmount = (lease['rentAmount'] as num?)?.toInt() ?? 0;
      final lateFeePercentage =
          (lease['lateFeePercentage'] as num?)?.toDouble() ?? 0.0;
      final dueDate = DateTimeConverter.toDate(lease['dueDate']) ?? now;
      final isOverdue = now.isAfter(dueDate);
      final lateFeeAmount = isOverdue
          ? (rentAmount * lateFeePercentage / 100).round()
          : 0;

      final paymentId = payment?['id']?.toString();
      Map<String, dynamic>? lastTx;
      if (paymentId != null) {
        lastTx = await _transaction.getLatestTransactionForPayment(paymentId);
      }

      return PaymentDue(
        leaseId: lease['id'],
        paymentId: paymentId ?? '',
        tenantId: tenantId,
        ownerId: lease['ownerId'] ?? '',
        propertyId: lease['propertyId'] ?? '',
        propertyName: lease['propertyName'] ?? 'Property',
        ownerName: lease['ownerName'] ?? 'Owner',
        monthlyRent: rentAmount,
        dueDate: dueDate,
        lateFeeAmount: lateFeeAmount,
        totalPayable: rentAmount + lateFeeAmount,
        daysRemaining: dueDate
            .difference(DateTime(now.year, now.month, now.day))
            .inDays,
        paymentStatus: payment?['status'] ?? 'pending',
        lastTransactionStatus: lastTx?['status'],
        receiptUrl: payment?['receiptUrl'],
      );
    } on FirebaseException catch (error) {
      throw PaymentFailureMapper.mapFirebaseFailure(error);
    } catch (error) {
      throw const ServerFailure('Failed to load due payment');
    }
  }
}

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
      final openPayment = await _payment.getOldestOpenPaymentForLease(
        leaseId: lease['id'],
      );

      final payment =
          openPayment ??
          await _payment.getPaymentForLeaseMonth(
            leaseId: lease['id'],
            month: now.month,
            year: now.year,
          );

      final rentAmount = (lease['rentAmount'] as num?)?.toInt() ?? 0;
      final lateFeePercentage =
          (lease['lateFeePercentage'] as num?)?.toDouble() ?? 0.0;

      final leaseDueDay = _resolveLeaseDueDay(lease);
      final fallbackDueDate = DateTime(now.year, now.month, leaseDueDay, 9);
      final cycleDueDate = _resolveDueDateForPayment(
        payment: payment,
        fallback: fallbackDueDate,
      );

      final dueDate = cycleDueDate;
      final isOverdue = now.isAfter(dueDate);
      final paymentLateFee = (payment?['lateFeeAmount'] as num?)?.toInt() ?? 0;
      final lateFeeAmount = paymentLateFee > 0
          ? paymentLateFee
          : (isOverdue ? (rentAmount * lateFeePercentage / 100).round() : 0);

      final paymentRentAmount = (payment?['rentAmount'] as num?)?.toInt() ?? 0;
      final effectiveRentAmount = paymentRentAmount > 0
          ? paymentRentAmount
          : rentAmount;

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
        monthlyRent: effectiveRentAmount,
        dueDate: dueDate,
        lateFeeAmount: lateFeeAmount,
        totalPayable: effectiveRentAmount + lateFeeAmount,
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

  int _resolveLeaseDueDay(Map<String, dynamic> lease) {
    final rentDueDay = (lease['rentDueDay'] as num?)?.toInt();
    if (rentDueDay != null && rentDueDay >= 1 && rentDueDay <= 31) {
      return rentDueDay;
    }

    final leaseDueDate = DateTimeConverter.toDate(lease['dueDate']);
    if (leaseDueDate != null) {
      return leaseDueDate.day;
    }

    return 1;
  }

  DateTime _resolveDueDateForPayment({
    required Map<String, dynamic>? payment,
    required DateTime fallback,
  }) {
    final paymentDueDate = DateTimeConverter.toDate(payment?['dueDate']);
    if (paymentDueDate != null) {
      return DateTime(
        paymentDueDate.year,
        paymentDueDate.month,
        paymentDueDate.day,
        9,
      );
    }

    final year = (payment?['year'] as num?)?.toInt();
    final month = (payment?['month'] as num?)?.toInt();
    if (year != null && month != null && month >= 1 && month <= 12) {
      final day = fallback.day;
      final lastDay = DateTime(year, month + 1, 0).day;
      final safeDay = day.clamp(1, lastDay);
      return DateTime(year, month, safeDay, 9);
    }

    return fallback;
  }
}

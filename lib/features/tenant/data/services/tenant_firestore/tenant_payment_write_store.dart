import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TenantPaymentWriteStore {
  final FirebaseFirestore firestore;

  const TenantPaymentWriteStore(this.firestore);

  Future<void> markPaid({
    required String tenantId,
    required int amountPaid,
    required DateTime paymentDate,
    required String paymentMethod,
    required int monthlyRent,
  }) async {
    if (amountPaid <= 0) {
      throw Exception('Amount paid must be greater than zero.');
    }
    if (monthlyRent > 0 && amountPaid != monthlyRent) {
      throw Exception('Amount must match monthly rent for this tenant.');
    }

    final monthKey =
        '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}';
    final paymentRef = firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(monthKey);
    final tenantRef = firestore.collection('tenants').doc(tenantId);
    await firestore.runTransaction((tx) async {
      final existingPayment = await tx.get(paymentRef);
      final previousAmount =
          (existingPayment.data()?['amount'] as num?)?.toInt() ?? 0;
      final delta = amountPaid - previousAmount;
      tx.set(paymentRef, {
        'paymentMonth': monthKey,
        'month': DateFormat.MMMM().format(paymentDate),
        'amount': amountPaid,
        'paidDate': Timestamp.fromDate(paymentDate),
        'paymentDate': Timestamp.fromDate(paymentDate),
        'paymentMethod': paymentMethod,
        'status': 'paid',
        'monthlyRentSnapshot': monthlyRent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (delta != 0) {
        tx.set(tenantRef, {
          'totalPaid': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  Future<bool> isMarked(String tenantId, DateTime date) async {
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final snapshot = await firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(monthKey)
        .get();
    return snapshot.exists &&
        (snapshot.data()?['status'] as String? ?? '').toLowerCase() == 'paid';
  }
}

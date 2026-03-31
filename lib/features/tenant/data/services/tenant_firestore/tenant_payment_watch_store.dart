import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';

class TenantPaymentWatchStore {
  final FirebaseFirestore firestore;

  const TenantPaymentWatchStore(this.firestore);

  DateTime _safeDateFrom(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Stream<TenantPayment?> watchCurrentMonthPayment(String tenantId) {
    final now = DateTime.now();
    final monthName = DateFormat.MMMM().format(now);
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('payments')
        .doc(monthKey)
        .snapshots()
        .asyncMap((doc) async {
          if (doc.exists) return TenantPayment.fromDocument(doc);

          QuerySnapshot<Map<String, dynamic>> legacy;
          try {
            legacy = await firestore
                .collection('tenants')
                .doc(tenantId)
                .collection('payments')
                .where('month', isEqualTo: monthName)
                .orderBy('paidDate', descending: true)
                .limit(1)
                .get();
          } on FirebaseException catch (error) {
            if (error.code != 'failed-precondition') rethrow;

            // Fallback while index is building: fetch filtered docs and sort locally.
            final fallback = await firestore
                .collection('tenants')
                .doc(tenantId)
                .collection('payments')
                .where('month', isEqualTo: monthName)
                .get();

            if (fallback.docs.isEmpty) {
              return null;
            }

            final sorted = [...fallback.docs]
              ..sort((a, b) {
                final aDate = _safeDateFrom(a.data()['paidDate']);
                final bDate = _safeDateFrom(b.data()['paidDate']);
                return bDate.compareTo(aDate);
              });

            return TenantPayment.fromFirestore(sorted.first);
          }

          return legacy.docs.isEmpty
              ? null
              : TenantPayment.fromFirestore(legacy.docs.first);
        });
  }
}

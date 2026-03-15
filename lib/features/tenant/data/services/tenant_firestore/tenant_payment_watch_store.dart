import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rentdone/features/tenant/data/models/tenant_payment.dart';

class TenantPaymentWatchStore {
  final FirebaseFirestore firestore;

  const TenantPaymentWatchStore(this.firestore);

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
          final legacy = await firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('payments')
              .where('month', isEqualTo: monthName)
              .orderBy('paidDate', descending: true)
              .limit(1)
              .get();
          return legacy.docs.isEmpty
              ? null
              : TenantPayment.fromFirestore(legacy.docs.first);
        });
  }
}

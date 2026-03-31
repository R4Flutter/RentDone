import 'package:cloud_firestore/cloud_firestore.dart';

class TenantDashboardPaymentDocs {
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> load(
    FirebaseFirestore firestore,
    String tenantId,
  ) async {
    try {
      return (await firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('payments')
              .get())
          .docs;
    } on FirebaseException {
      return const [];
    }
  }

  static int dynamicTotal(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs,
  ) => paymentDocs.fold<int>(
    0,
    (total, doc) => total + ((doc.data()['amount'] as num?)?.toInt() ?? 0),
  );
}

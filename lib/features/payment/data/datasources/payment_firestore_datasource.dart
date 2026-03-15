import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentFirestoreDataSource {
  final FirebaseFirestore _firestore;

  PaymentFirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getPaymentForLeaseMonth({
    required String leaseId,
    required int month,
    required int year,
  }) async {
    final snap = await _firestore
        .collection('payments')
        .where('leaseId', isEqualTo: leaseId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }
}

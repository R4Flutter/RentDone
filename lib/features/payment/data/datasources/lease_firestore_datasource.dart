import 'package:cloud_firestore/cloud_firestore.dart';

class LeaseFirestoreDataSource {
  final FirebaseFirestore _firestore;

  LeaseFirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getActiveLeaseForTenant(String tenantId) async {
    final snap = await _firestore
        .collection('leases')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaseFirestoreDataSource {
  final FirebaseFirestore _firestore;

  LeaseFirestoreDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getActiveLeaseForTenant(String authUid) async {
    final tenantDoc = await _firestore.collection('tenants').doc(authUid).get();

    if (!tenantDoc.exists) return null;

    final data = tenantDoc.data()!;

    return {
      'tenantId': authUid,
      'rentAmount': data['rentAmount'] ?? 0,
      'dueAmount': data['dueAmount'] ?? data['rentAmount'] ?? 0,
      'status': data['isActive'] == true ? 'active' : 'inactive',
    };
  }
}

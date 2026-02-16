import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_payment_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_property_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/message_model.dart';

class DashboardFirebaseService {
  final FirebaseFirestore _firestore;

  DashboardFirebaseService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<DashboardPropertyDto>> fetchProperties() async {
    final snapshot = await _firestore.collection('properties').get();
    return snapshot.docs
        .map((doc) => DashboardPropertyDto.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<DashboardPaymentDto>> fetchPayments() async {
    final snapshot = await _firestore.collection('payments').get();
    return snapshot.docs
        .map((doc) => DashboardPaymentDto.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<int> fetchTenantCount() async {
    final snapshot = await _firestore.collection('tenants').get();
    return snapshot.size;
  }

  Stream<List<AppMessageDto>> watchRecentMessages({int limit = 6}) {
    return _firestore
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppMessageDto.fromDoc).toList());
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_payment_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/dashboard_property_dto.dart';
import 'package:rentdone/features/owner/owner_dashboard/data/models/message_model.dart';

class DashboardFirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DashboardFirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  String? get _ownerId => _auth.currentUser?.uid;

  Future<List<DashboardPropertyDto>> fetchProperties() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return <DashboardPropertyDto>[];

    final snapshot = await _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snapshot.docs
        .map((doc) => DashboardPropertyDto.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<DashboardPaymentDto>> fetchPayments() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return <DashboardPaymentDto>[];

    final snapshot = await _firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snapshot.docs
        .map((doc) => DashboardPaymentDto.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<int> fetchTenantCount() async {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) return 0;

    final snapshot = await _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snapshot.size;
  }

  Stream<List<AppMessageDto>> watchRecentMessages({int limit = 6}) {
    final ownerId = _ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<AppMessageDto>>.empty();
    }

    return _firestore
        .collection('messages')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppMessageDto.fromDoc).toList());
  }
}

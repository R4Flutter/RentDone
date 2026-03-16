import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_property_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/owner_tenant_summary.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_history_page.dart';
import 'package:rentdone/features/owner/owner_payment/models/tenant_payment_record.dart';

class TenantPaymentHistoryFirebaseService {
  TenantPaymentHistoryFirebaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _ownerIdOrThrow() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.trim().isEmpty) {
      throw StateError('Owner is not authenticated.');
    }
    return ownerId.trim();
  }

  Stream<List<OwnerPropertySummary>> watchOwnerProperties() {
    final ownerId = _ownerIdOrThrow();

    return _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .asyncMap((propertySnapshot) async {
          final tenantSnapshot = await _firestore
              .collection('tenants')
              .where('ownerId', isEqualTo: ownerId)
              .get();

          final tenantsByProperty = <String, List<Map<String, dynamic>>>{};
          for (final doc in tenantSnapshot.docs) {
            final data = doc.data();
            final propertyId = (data['propertyId'] as String? ?? '').trim();
            if (propertyId.isEmpty) continue;
            tenantsByProperty
                .putIfAbsent(propertyId, () => <Map<String, dynamic>>[])
                .add(data);
          }

          return propertySnapshot.docs.map((doc) {
            final data = doc.data();
            final linkedTenants =
                tenantsByProperty[doc.id] ?? const <Map<String, dynamic>>[];
            final estimatedCollection = linkedTenants.fold<int>(
              0,
              (total, tenant) =>
                  total + ((tenant['rentAmount'] as num?)?.toInt() ?? 0),
            );

            return OwnerPropertySummary(
              id: doc.id,
              name: (data['name'] as String? ?? 'Unnamed Property').trim(),
              location: ((data['location'] ?? data['address'] ?? '') as String)
                  .trim(),
              totalTenants: linkedTenants.length,
              estimatedMonthlyCollection: estimatedCollection,
            );
          }).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        });
  }

  Stream<List<OwnerTenantSummary>> watchPropertyTenants(String propertyId) {
    final ownerId = _ownerIdOrThrow();

    return _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs.map((doc) {
                final data = doc.data();
                final isActive = data['isActive'] != false;

                return OwnerTenantSummary(
                  id: doc.id,
                  propertyId: propertyId,
                  name:
                      ((data['fullName'] ?? data['name'] ?? 'Tenant') as String)
                          .trim(),
                  roomNumber:
                      ((data['roomNumber'] ?? data['roomId'] ?? 'NA') as String)
                          .trim(),
                  rentAmount: (data['rentAmount'] as num?)?.toInt() ?? 0,
                  status: isActive ? 'active' : 'vacant',
                  phone:
                      ((data['phone'] ?? data['phoneNumber'] ?? '') as String)
                          .trim(),
                );
              }).toList()..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

          return list;
        });
  }

  Future<TenantPaymentHistoryPage> fetchTenantPayments({
    required String tenantId,
    int limit = 20,
    DateTime? cursor,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('payments')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('date', descending: true)
        .limit(limit);

    if (cursor != null) {
      query = query.startAfter([Timestamp.fromDate(cursor)]);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => TenantPaymentRecord.fromFirestore(doc.id, doc.data()))
        .toList();

    final hasMore = items.length == limit;
    final nextCursor = hasMore ? items.last.date : null;

    return TenantPaymentHistoryPage(
      items: items,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  Future<void> addPayment({
    required String tenantId,
    required String propertyId,
    required int amount,
    required DateTime date,
    required String method,
    required String status,
    String? transactionId,
    String? notes,
  }) async {
    final ownerId = _ownerIdOrThrow();

    final docRef = _firestore.collection('payments').doc();
    final payload = TenantPaymentRecord(
      id: docRef.id,
      tenantId: tenantId,
      propertyId: propertyId,
      amount: amount,
      date: date,
      method: method,
      status: status,
      createdAt: DateTime.now(),
      transactionId: transactionId,
      notes: notes,
    ).toFirestore(ownerId: ownerId);

    await docRef.set(payload);
  }
}

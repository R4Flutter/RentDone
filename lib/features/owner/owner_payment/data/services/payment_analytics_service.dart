import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/owner_property_summary.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/owner_tenant_summary.dart';

class PaymentAnalyticsService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PaymentAnalyticsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const int _ownerPropertiesStreamLimit = 50;
  static const int _ownerTenantsStreamLimit = 50;
  static const int _propertyTenantsStreamLimit = 50;

  String _ownerIdOrThrow() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.trim().isEmpty) {
      throw StateError('Owner is not authenticated.');
    }
    return ownerId.trim();
  }

  Stream<List<OwnerPropertySummary>> watchOwnerProperties() {
    final ownerId = _ownerIdOrThrow();
    final propertiesStream = _firestore
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(_ownerPropertiesStreamLimit)
        .snapshots();
    final tenantsStream = _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(_ownerTenantsStreamLimit)
        .snapshots();

    return Stream<List<OwnerPropertySummary>>.multi((multi) {
      QuerySnapshot<Map<String, dynamic>>? latestProperties;
      QuerySnapshot<Map<String, dynamic>>? latestTenants;

      void emitIfReady() {
        final propertySnapshot = latestProperties;
        final tenantSnapshot = latestTenants;
        if (propertySnapshot == null || tenantSnapshot == null) {
          return;
        }

        multi.add(
          _buildOwnerPropertySummaries(
            propertySnapshot: propertySnapshot,
            tenantSnapshot: tenantSnapshot,
          ),
        );
      }

      final propertiesSub = propertiesStream.listen(
        (snapshot) {
          latestProperties = snapshot;
          emitIfReady();
        },
        onError: multi.addError,
      );

      final tenantsSub = tenantsStream.listen(
        (snapshot) {
          latestTenants = snapshot;
          emitIfReady();
        },
        onError: multi.addError,
      );

      multi.onCancel = () async {
        await propertiesSub.cancel();
        await tenantsSub.cancel();
      };
    });
  }

  Stream<List<OwnerTenantSummary>> watchPropertyTenants(String propertyId) {
    final ownerId = _ownerIdOrThrow();
    final propertyRef = _firestore.collection('properties').doc(propertyId);
    final tenantsStream = _firestore
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .limit(_propertyTenantsStreamLimit)
        .snapshots();
    final propertyStream = propertyRef.snapshots();

    return Stream<List<OwnerTenantSummary>>.multi((multi) {
      QuerySnapshot<Map<String, dynamic>>? latestTenants;
      Map<String, dynamic>? latestPropertyData;
      var hasPropertySnapshot = false;

      void emitIfReady() {
        final tenantSnapshot = latestTenants;
        if (tenantSnapshot == null || !hasPropertySnapshot) {
          return;
        }

        final roomNameById = _extractRoomNameById(latestPropertyData);
        multi.add(
          _buildOwnerTenantSummaries(
            tenantSnapshot: tenantSnapshot,
            propertyId: propertyId,
            roomNameById: roomNameById,
          ),
        );
      }

      final tenantsSub = tenantsStream.listen(
        (snapshot) {
          latestTenants = snapshot;
          emitIfReady();
        },
        onError: multi.addError,
      );

      final propertySub = propertyStream.listen(
        (snapshot) {
          hasPropertySnapshot = true;
          latestPropertyData = snapshot.data();
          emitIfReady();
        },
        onError: multi.addError,
      );

      multi.onCancel = () async {
        await tenantsSub.cancel();
        await propertySub.cancel();
      };
    });
  }

  List<OwnerPropertySummary> _buildOwnerPropertySummaries({
    required QuerySnapshot<Map<String, dynamic>> propertySnapshot,
    required QuerySnapshot<Map<String, dynamic>> tenantSnapshot,
  }) {
    final tenantsByProperty = <String, List<Map<String, dynamic>>>{};
    for (final doc in tenantSnapshot.docs) {
      final data = doc.data();
      final propertyId = (data['propertyId'] as String? ?? '').trim();
      if (propertyId.isEmpty) continue;
      tenantsByProperty
          .putIfAbsent(propertyId, () => <Map<String, dynamic>>[])
          .add(data);
    }

    final summaries = propertySnapshot.docs.map((doc) {
      final data = doc.data();
      final linkedTenants =
          tenantsByProperty[doc.id] ?? const <Map<String, dynamic>>[];
      final estimatedCollection = linkedTenants.fold<int>(
        0,
        (total, tenant) => total + ((tenant['rentAmount'] as num?)?.toInt() ?? 0),
      );

      return OwnerPropertySummary(
        id: doc.id,
        name: (data['name'] as String? ?? 'Unnamed Property').trim(),
        location: ((data['location'] ?? data['address'] ?? '') as String).trim(),
        totalTenants: linkedTenants.length,
        estimatedMonthlyCollection: estimatedCollection,
      );
    }).toList();

    summaries.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return summaries;
  }

  List<OwnerTenantSummary> _buildOwnerTenantSummaries({
    required QuerySnapshot<Map<String, dynamic>> tenantSnapshot,
    required String propertyId,
    required Map<String, String> roomNameById,
  }) {
    final list = tenantSnapshot.docs.map((doc) {
      final data = doc.data();
      final isActive = data['isActive'] != false;

      return OwnerTenantSummary(
        id: doc.id,
        propertyId: propertyId,
        name: ((data['fullName'] ?? data['name'] ?? 'Tenant') as String).trim(),
        roomNumber: _resolveTenantRoomLabel(data, roomNameById),
        rentAmount: (data['rentAmount'] as num?)?.toInt() ?? 0,
        status: isActive ? 'active' : 'vacant',
        phone: ((data['phone'] ?? data['phoneNumber'] ?? '') as String).trim(),
      );
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Map<String, String> _extractRoomNameById(Map<String, dynamic>? propertyData) {
    final byId = <String, String>{};
    final roomsRaw = propertyData?['rooms'];
    if (roomsRaw is! List) return byId;

    for (final roomRaw in roomsRaw) {
      if (roomRaw is! Map) continue;

      final room = roomRaw.map((k, v) => MapEntry(k.toString(), v));
      final id = (room['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      final roomName = (room['name'] ?? '').toString().trim();
      final roomNumber = (room['roomNumber'] ?? '').toString().trim();
      final label = roomName.isNotEmpty ? roomName : roomNumber;

      if (label.isNotEmpty) {
        byId[id] = label;
      }
    }

    return byId;
  }

  String _resolveTenantRoomLabel(
    Map<String, dynamic> tenantData,
    Map<String, String> roomNameById,
  ) {
    final rawRoomNumber = (tenantData['roomNumber'] as String? ?? '').trim();
    final roomId = (tenantData['roomId'] as String? ?? '').trim();

    if (roomId.isNotEmpty) {
      final mappedRoomName = roomNameById[roomId]?.trim();
      if (mappedRoomName != null && mappedRoomName.isNotEmpty) {
        return mappedRoomName;
      }
    }

    if (rawRoomNumber.isNotEmpty && rawRoomNumber.toLowerCase() != 'na') {
      return rawRoomNumber;
    }

    return 'NA';
  }
}

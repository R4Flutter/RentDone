import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';

class PropertyFirebaseService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  PropertyFirebaseService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

  String _requireOwnerId() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('Owner session not found. Please sign in again.');
    }
    return ownerId;
  }

  Stream<List<PropertyDto>> watchAllProperties() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<PropertyDto>>.empty();
    }

    return _db
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PropertyDto.fromMap({'id': doc.id, ...doc.data()}))
              .toList();
        });
  }

  Stream<PropertyDto> watchProperty(String propertyId) {
    return _db.collection('properties').doc(propertyId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) {
        throw StateError('Property $propertyId not found');
      }
      return PropertyDto.fromMap({'id': doc.id, ...data});
    });
  }

  Future<void> addProperty(PropertyDto property) async {
    final ownerId = _requireOwnerId();
    await _db.collection('properties').doc(property.id).set({
      ...property.toMap(),
      'ownerId': ownerId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProperty(PropertyDto property) async {
    final ownerId = _requireOwnerId();
    await _db.collection('properties').doc(property.id).update({
      ...property.toMap(),
      'ownerId': ownerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProperty(String propertyId) async {
    await _db.collection('properties').doc(propertyId).delete();
  }

  Stream<List<TenantDto>> watchAllTenants() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<TenantDto>>.empty();
    }

    return _db
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(TenantDto.fromDoc).toList();
        });
  }

  Stream<List<TenantDto>> watchPropertyTenants(String propertyId) {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      return const Stream<List<TenantDto>>.empty();
    }

    return _db
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TenantDto.fromDoc).toList());
  }

  Future<TenantDto?> getTenantById(String tenantId) async {
    final doc = await _db.collection('tenants').doc(tenantId).get();
    if (!doc.exists) return null;
    return TenantDto.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  Future<void> addTenant(TenantDto tenant) async {
    final tenantRef = _db.collection('tenants').doc(tenant.id);
    final propertyRef = _db.collection('properties').doc(tenant.propertyId);

    await _db.runTransaction((txn) async {
      final propertyDoc = await txn.get(propertyRef);
      if (!propertyDoc.exists) {
        throw StateError('Selected property does not exist');
      }

      final data = propertyDoc.data();
      final rooms = _normalizeRooms(data?['rooms']);
      final roomIndex = rooms.indexWhere((room) => room['id'] == tenant.roomId);

      if (roomIndex == -1) {
        throw StateError('Selected room does not exist in this property');
      }

      final room = rooms[roomIndex];
      final currentTenantId = room['tenantId']?.toString();
      if (room['isOccupied'] == true &&
          currentTenantId != null &&
          currentTenantId.isNotEmpty) {
        throw StateError('Selected room is already occupied');
      }

      rooms[roomIndex] = {...room, 'isOccupied': true, 'tenantId': tenant.id};

      txn.set(tenantRef, tenant.toMap());
      txn.update(propertyRef, {'rooms': rooms});
    });
  }

  Future<void> removeTenant({
    required String tenantId,
    required String propertyId,
    required String roomId,
  }) async {
    final tenantRef = _db.collection('tenants').doc(tenantId);
    final propertyRef = _db.collection('properties').doc(propertyId);

    await _db.runTransaction((txn) async {
      final propertyDoc = await txn.get(propertyRef);
      if (!propertyDoc.exists) {
        throw StateError('Selected property does not exist');
      }

      final data = propertyDoc.data();
      final rooms = _normalizeRooms(data?['rooms']);
      final roomIndex = rooms.indexWhere((room) => room['id'] == roomId);

      if (roomIndex == -1) {
        throw StateError('Selected room does not exist in this property');
      }

      final room = rooms[roomIndex];
      rooms[roomIndex] = {...room, 'isOccupied': false, 'tenantId': null};

      txn.update(propertyRef, {'rooms': rooms});
      txn.delete(tenantRef);
    });
  }

  List<Map<String, dynamic>> _normalizeRooms(dynamic roomsRaw) {
    if (roomsRaw is! List) return <Map<String, dynamic>>[];

    return roomsRaw
        .whereType<Map>()
        .map((room) => Map<String, dynamic>.from(room))
        .toList();
  }
}

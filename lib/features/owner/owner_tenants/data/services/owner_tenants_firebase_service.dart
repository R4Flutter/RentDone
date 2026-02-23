import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';

class OwnerTenantsFirebaseService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  OwnerTenantsFirebaseService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance;

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
          return snapshot.docs.map((doc) {
            return PropertyDto.fromMap({'id': doc.id, ...doc.data()});
          }).toList();
        });
  }

  Future<int> cleanupOrphanTenants() async {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('Owner session not found. Please sign in again.');
    }

    final propertiesSnapshot = await _db
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final validPropertyIds = propertiesSnapshot.docs
        .map((doc) => doc.id)
        .toSet();

    final tenantsSnapshot = await _db
        .collection('tenants')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final orphanDocs = tenantsSnapshot.docs.where((doc) {
      final propertyId = doc.data()['propertyId']?.toString() ?? '';
      if (propertyId.isEmpty) {
        return true;
      }
      return !validPropertyIds.contains(propertyId);
    }).toList();

    if (orphanDocs.isEmpty) {
      return 0;
    }

    const chunkSize = 400;
    for (var start = 0; start < orphanDocs.length; start += chunkSize) {
      final end = (start + chunkSize) > orphanDocs.length
          ? orphanDocs.length
          : start + chunkSize;
      final batch = _db.batch();
      for (final doc in orphanDocs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    return orphanDocs.length;
  }
}

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
}

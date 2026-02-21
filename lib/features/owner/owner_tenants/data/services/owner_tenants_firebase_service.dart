import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';

class OwnerTenantsFirebaseService {
  final FirebaseFirestore _db;

  OwnerTenantsFirebaseService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Stream<List<TenantDto>> watchAllTenants() {
    return _db.collection('tenants').snapshots().map((snapshot) {
      return snapshot.docs.map(TenantDto.fromDoc).toList();
    });
  }

  Stream<List<PropertyDto>> watchAllProperties() {
    return _db.collection('properties').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return PropertyDto.fromMap({'id': doc.id, ...doc.data()});
      }).toList();
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/ui_models/tenant_model.dart';
import 'package:rentdone/features/owner/owners_properties/ui_models/property_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ===== TENANT OPERATIONS =====

  Future<void> addTenant(Tenant tenant) async {
    await _db.collection('tenants').doc(tenant.id).set(tenant.toMap());

    // Update room status
    await _db
        .collection('properties')
        .doc(tenant.propertyId)
        .collection('rooms')
        .doc(tenant.roomId)
        .update({'isOccupied': true, 'tenantId': tenant.id});
  }

  Future<void> updateTenant(Tenant tenant) async {
    await _db.collection('tenants').doc(tenant.id).update(tenant.toMap());
  }

  Future<void> removeTenant(
    String tenantId,
    String propertyId,
    String roomId,
  ) async {
    // Mark room as vacant
    await _db
        .collection('properties')
        .doc(propertyId)
        .collection('rooms')
        .doc(roomId)
        .update({'isOccupied': false, 'tenantId': null});

    // Option: Delete or archive tenant
    await _db.collection('tenants').doc(tenantId).delete();
  }

  Future<void> updateProperty(Property property) async {
    await _db
        .collection('properties')
        .doc(property.id)
        .update(property.toMap());
  }

  Future<Tenant?> getTenant(String tenantId) async {
    final doc = await _db.collection('tenants').doc(tenantId).get();
    if (!doc.exists) return null;
    return _tenantFromFirestore(doc);
  }

  Future<void> deleteProperty(String propertyId) async {
    await _db.collection('properties').doc(propertyId).delete();
  }

  Stream<List<Tenant>> getTenantsForProperty(String propertyId) {
    return _db
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _tenantFromFirestore(doc)).toList(),
        );
  }

  Stream<List<Tenant>> getAllTenants() {
    return _db
        .collection('tenants')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _tenantFromFirestore(doc)).toList(),
        );
  }

  // ===== PROPERTY OPERATIONS =====

  Future<void> addProperty(Property property) async {
    await _db.collection('properties').doc(property.id).set(property.toMap());
  }

  Future<Property?> getProperty(String propertyId) async {
    final doc = await _db.collection('properties').doc(propertyId).get();
    if (!doc.exists) return null;
    return Property.fromMap({'id': doc.id, ...doc.data()!});
  }

  Stream<List<Property>> getAllProperties() {
    return _db
        .collection('properties')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Property.fromMap({'id': doc.id, ...doc.data()}))
              .toList(),
        );
  }

  Stream<Property> getPropertyStream(String propertyId) {
    return _db
        .collection('properties')
        .doc(propertyId)
        .snapshots()
        .map((doc) => Property.fromMap({'id': doc.id, ...doc.data()!}));
  }

  // ===== HELPER METHODS =====

  Tenant _tenantFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tenant(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      alternatePhone: data['alternatePhone'],
      email: data['email'],
      dateOfBirth: data['dateOfBirth'] != null
          ? DateTime.parse(data['dateOfBirth'])
          : null,
      tenantType: data['tenantType'] ?? 'Individual',
      primaryIdType: data['primaryIdType'],
      primaryIdNumber: data['primaryIdNumber'],
      aadhaarNumber: data['aadhaarNumber'],
      panNumber: data['panNumber'],
      photoUrl: data['photoUrl'],
      idDocumentUrl: data['idDocumentUrl'],
      companyName: data['companyName'],
      jobTitle: data['jobTitle'],
      officeAddress: data['officeAddress'],
      monthlyIncome: data['monthlyIncome']?.toDouble(),
      propertyId: data['propertyId'] ?? '',
      roomId: data['roomId'] ?? '',
      moveInDate: DateTime.parse(data['moveInDate']),
      agreementEndDate: data['agreementEndDate'] != null
          ? DateTime.parse(data['agreementEndDate'])
          : null,
      rentAmount: data['rentAmount'] ?? 0,
      securityDeposit: data['securityDeposit'] ?? 0,
      rentFrequency: data['rentFrequency'] ?? 'Monthly',
      rentDueDay: data['rentDueDay'] ?? 1,
      paymentMode: data['paymentMode'] ?? 'UPI',
      lateFinePercentage: (data['lateFinePercentage'] ?? 0).toDouble(),
      noticePeriodDays: data['noticePeriodDays'] ?? 30,
      maintenanceCharge: (data['maintenanceCharge'] ?? 0).toDouble(),
      emergencyName: data['emergencyName'],
      emergencyPhone: data['emergencyPhone'],
      emergencyRelation: data['emergencyRelation'],
      previousAddress: data['previousAddress'],
      previousLandlordName: data['previousLandlordName'],
      previousLandlordPhone: data['previousLandlordPhone'],
      policeVerified: data['policeVerified'] ?? false,
      backgroundChecked: data['backgroundChecked'] ?? false,
      isActive: data['isActive'] ?? true,
      createdAt: DateTime.parse(data['createdAt']),
    );
  }
}

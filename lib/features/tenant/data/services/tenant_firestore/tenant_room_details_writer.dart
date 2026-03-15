import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';

class TenantRoomDetailsWriter {
  final FirebaseFirestore firestore;

  const TenantRoomDetailsWriter(this.firestore);

  Future<void> save(String tenantId, TenantRoomDetails details) async {
    if (details.monthlyRent <= 0) {
      throw Exception('Monthly rent must be greater than zero.');
    }
    if (details.rentDueDay < 1 || details.rentDueDay > 31) {
      throw Exception('Rent due day must be between 1 and 31.');
    }
    if (details.allocationDate.isAfter(DateTime.now())) {
      throw Exception('Allocation date cannot be in the future.');
    }

    try {
      await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('room_details')
          .doc('current')
          .set(details.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    await firestore.collection('tenants').doc(tenantId).set({
      'propertyName': details.propertyName,
      'roomNumber': details.roomNumber,
      'rentAmount': details.monthlyRent,
      if (details.depositAmount != null) 'depositAmount': details.depositAmount,
      'rentDueDay': details.rentDueDay,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

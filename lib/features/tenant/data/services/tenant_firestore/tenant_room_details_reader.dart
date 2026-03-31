import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';

class TenantRoomDetailsReader {
  final FirebaseFirestore firestore;

  const TenantRoomDetailsReader(this.firestore);

  Future<TenantRoomDetails?> get(String tenantId) async {
    try {
      final doc = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('room_details')
          .doc('current')
          .get();
      final data = doc.data();
      if (data != null) return TenantRoomDetails.fromMap(data);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    final tenantData =
        (await firestore.collection('tenants').doc(tenantId).get()).data();
    if (tenantData == null) return null;
    final propertyName = (tenantData['propertyName'] as String? ?? '').trim();
    final roomNumber = (tenantData['roomNumber'] as String? ?? '').trim();
    final monthlyRent = (tenantData['rentAmount'] as num?)?.toInt() ?? 0;
    if (propertyName.isEmpty && roomNumber.isEmpty && monthlyRent <= 0) {
      return null;
    }

    return TenantRoomDetails(
      propertyName: propertyName,
      roomNumber: roomNumber,
      monthlyRent: monthlyRent,
      depositAmount: (tenantData['depositAmount'] as num?)?.toInt(),
      allocationDate: DateTime.now(),
      rentDueDay: (tenantData['rentDueDay'] as num?)?.toInt() ?? 1,
    );
  }
}

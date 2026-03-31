import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';

class TenantOwnerDetailsWriter {
  final FirebaseFirestore firestore;

  const TenantOwnerDetailsWriter(this.firestore);

  Future<void> save(String tenantId, TenantOwnerDetails details) async {
    try {
      await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('owner_details')
          .doc('current')
          .set(details.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    await firestore.collection('tenants').doc(tenantId).set({
      'ownerPhoneNumber': details.ownerPhoneNumber,
      if (details.ownerUpiId.isNotEmpty) 'ownerUpiId': details.ownerUpiId,
      if (details.ownerName.isNotEmpty) 'ownerName': details.ownerName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

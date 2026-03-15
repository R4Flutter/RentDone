import 'package:cloud_firestore/cloud_firestore.dart';

class TenantOwnerRawDataReader {
  final FirebaseFirestore firestore;

  const TenantOwnerRawDataReader(this.firestore);

  Future<Map<String, dynamic>> currentDetails(String tenantId) async {
    try {
      return (await firestore
                  .collection('tenants')
                  .doc(tenantId)
                  .collection('owner_details')
                  .doc('current')
                  .get())
              .data() ??
          const <String, dynamic>{};
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> ownerProfile(String ownerId) async {
    try {
      return (await firestore.collection('owners').doc(ownerId).get()).data() ??
          const <String, dynamic>{};
    } on FirebaseException {
      return const <String, dynamic>{};
    }
  }
}

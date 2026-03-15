import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';

class TenantDocumentsStore {
  final FirebaseFirestore firestore;

  const TenantDocumentsStore(this.firestore);

  Future<List<TenantDocument>> getPage(
    String tenantId, {
    String? lastDocumentId,
    int limit = 20,
  }) async {
    var query = firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .limit(limit);
    if (lastDocumentId != null && lastDocumentId.isNotEmpty) {
      final lastDoc = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('documents')
          .doc(lastDocumentId)
          .get();
      if (lastDoc.exists) query = query.startAfterDocument(lastDoc);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(TenantDocument.fromFirestore).toList();
  }

  Future<void> saveUploaded({
    required String tenantId,
    required String fileUrl,
    required String fileType,
    required String publicId,
    required String description,
    required int fileSizeBytes,
    String? deleteToken,
  }) {
    return firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('documents')
        .add({
          'fileUrl': fileUrl,
          'fileType': fileType,
          'publicId': publicId,
          'uploadedAt': FieldValue.serverTimestamp(),
          'description': description,
          'fileSizeBytes': fileSizeBytes,
          if (deleteToken != null && deleteToken.isNotEmpty)
            'deleteToken': deleteToken,
        });
  }

  Future<void> delete(String tenantId, String documentId) => firestore
      .collection('tenants')
      .doc(tenantId)
      .collection('documents')
      .doc(documentId)
      .delete();
}

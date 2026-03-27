import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';

class TenantDocumentsStore {
  static const int _maxDocumentsPerTenant = 5;

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
    String? thumbnailUrl,
    required String fileType,
    required String publicId,
    required String storagePath,
    String? thumbnailStoragePath,
    required String description,
    required int fileSizeBytes,
    int? thumbnailSizeBytes,
    String category = 'other',
    int? currentDocumentCount,
  }) {
    final tenantRef = firestore.collection('tenants').doc(tenantId);
    final docRef = tenantRef.collection('documents').doc();

    return firestore.runTransaction((tx) async {
      final tenantSnap = await tx.get(tenantRef);
      final tenantData = tenantSnap.data() ?? <String, dynamic>{};
      final storedCount = (tenantData['documentsCount'] as num?)?.toInt();
      final effectiveCount = (storedCount ?? currentDocumentCount ?? 0).clamp(
        0,
        _maxDocumentsPerTenant,
      );

      if (effectiveCount >= _maxDocumentsPerTenant) {
        throw Exception(
          'Maximum 5 documents are allowed. Delete one to upload a new file.',
        );
      }

      tx.set(docRef, {
        'fileUrl': fileUrl,
        'originalUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'fileType': fileType,
        'publicId': publicId,
        'storagePath': storagePath,
        'thumbnailStoragePath': thumbnailStoragePath,
        'uploadedAt': FieldValue.serverTimestamp(),
        'description': description,
        'category': category,
        'fileSizeBytes': fileSizeBytes,
        if (thumbnailSizeBytes != null)
          'thumbnailSizeBytes': thumbnailSizeBytes,
        'status': 'active',
      });

      tx.set(tenantRef, {
        'documentsCount': effectiveCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> delete(String tenantId, String documentId) {
    final tenantRef = firestore.collection('tenants').doc(tenantId);
    final docRef = tenantRef.collection('documents').doc(documentId);

    return firestore.runTransaction((tx) async {
      final tenantSnap = await tx.get(tenantRef);
      final tenantData = tenantSnap.data() ?? <String, dynamic>{};
      final storedCount = (tenantData['documentsCount'] as num?)?.toInt() ?? 0;
      final nextCount = storedCount > 0 ? storedCount - 1 : 0;

      tx.delete(docRef);
      tx.set(tenantRef, {
        'documentsCount': nextCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}

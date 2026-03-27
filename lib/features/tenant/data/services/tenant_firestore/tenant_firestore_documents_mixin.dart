import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_complaint.dart';
import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/models/tenant_reminder.dart';

import 'tenant_complaints_store.dart';
import 'tenant_documents_store.dart';
import 'tenant_reminders_store.dart';

mixin TenantFirestoreDocumentsMixin {
  FirebaseFirestore get firestore;

  Future<List<TenantDocument>> getDocumentsPage(
    String tenantId, {
    String? lastDocumentId,
    int limit = 20,
  }) => TenantDocumentsStore(
    firestore,
  ).getPage(tenantId, lastDocumentId: lastDocumentId, limit: limit);

  Future<List<TenantReminder>> getRecentReminders(
    String tenantId, {
    int limit = 5,
  }) => TenantRemindersStore(firestore).recent(tenantId, limit: limit);

  Future<void> saveUploadedDocument({
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
  }) => TenantDocumentsStore(firestore).saveUploaded(
    tenantId: tenantId,
    fileUrl: fileUrl,
    thumbnailUrl: thumbnailUrl,
    fileType: fileType,
    publicId: publicId,
    storagePath: storagePath,
    thumbnailStoragePath: thumbnailStoragePath,
    description: description,
    fileSizeBytes: fileSizeBytes,
    thumbnailSizeBytes: thumbnailSizeBytes,
    category: category,
    currentDocumentCount: currentDocumentCount,
  );

  Future<void> deleteDocument(String tenantId, String documentId) =>
      TenantDocumentsStore(firestore).delete(tenantId, documentId);

  Future<void> saveComplaint({
    required String tenantId,
    required TenantComplaint complaint,
  }) => TenantComplaintsStore(
    firestore,
  ).save(tenantId: tenantId, complaint: complaint);
}

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
    required String fileType,
    required String publicId,
    required String description,
    required int fileSizeBytes,
    String? deleteToken,
  }) => TenantDocumentsStore(firestore).saveUploaded(
    tenantId: tenantId,
    fileUrl: fileUrl,
    fileType: fileType,
    publicId: publicId,
    description: description,
    fileSizeBytes: fileSizeBytes,
    deleteToken: deleteToken,
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

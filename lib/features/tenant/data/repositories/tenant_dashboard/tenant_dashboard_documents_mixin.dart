import 'dart:io';

import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/repositories/tenant_dashboard/tenant_dashboard_documents_coordinator.dart';
import 'package:rentdone/features/tenant/data/services/firebase_document_storage_service.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';

mixin TenantDashboardDocumentsMixin {
  TenantFirestoreService get firestoreService;
  FirebaseDocumentStorageService get documentStorageService;

  Future<List<TenantDocument>> getDocumentsPage(
    String tenantId, {
    String? lastDocumentId,
    int limit = 20,
  }) => firestoreService.getDocumentsPage(
    tenantId,
    lastDocumentId: lastDocumentId,
    limit: limit,
  );

  Future<TenantDocument> uploadDocument({
    required String tenantId,
    required File file,
    required String fileName,
    required String description,
    required int fileSizeBytes,
    String category = 'other',
  }) =>
      TenantDashboardDocumentsCoordinator(
        firestoreService: firestoreService,
        documentStorageService: documentStorageService,
      ).upload(
        tenantId: tenantId,
        file: file,
        fileName: fileName,
        description: description,
        fileSizeBytes: fileSizeBytes,
        category: category,
      );

  Future<void> deleteDocument({
    required String tenantId,
    required TenantDocument document,
  }) => TenantDashboardDocumentsCoordinator(
    firestoreService: firestoreService,
    documentStorageService: documentStorageService,
  ).delete(tenantId: tenantId, document: document);
}

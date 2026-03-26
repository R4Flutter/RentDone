import 'dart:io';

import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/services/firebase_document_storage_service.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';

import 'tenant_document_file_type.dart';

class TenantDashboardDocumentsCoordinator {
  final TenantFirestoreService firestoreService;
  final FirebaseDocumentStorageService documentStorageService;

  const TenantDashboardDocumentsCoordinator({
    required this.firestoreService,
    required this.documentStorageService,
  });

  Future<TenantDocument> upload({
    required String tenantId,
    required File file,
    required String fileName,
    required String description,
    required int fileSizeBytes,
  }) async {
    final uploadResult = await documentStorageService.uploadTenantDocument(
      tenantId: tenantId,
      file: file,
      fileName: fileName,
    );
    final fileType = resolveTenantDocumentFileType(fileName);
    try {
      await firestoreService.saveUploadedDocument(
        tenantId: tenantId,
        fileUrl: uploadResult.downloadUrl,
        thumbnailUrl: uploadResult.thumbnailUrl,
        fileType: fileType,
        publicId: uploadResult.storagePath,
        storagePath: uploadResult.storagePath,
        thumbnailStoragePath: uploadResult.thumbnailStoragePath,
        description: description,
        fileSizeBytes: uploadResult.uploadedBytes,
        thumbnailSizeBytes: uploadResult.thumbnailSizeBytes,
      );
    } catch (_) {
      try {
        await documentStorageService.deleteByStoragePath(
          uploadResult.storagePath,
        );
        if ((uploadResult.thumbnailStoragePath ?? '').isNotEmpty) {
          await documentStorageService.deleteByStoragePath(
            uploadResult.thumbnailStoragePath!,
          );
        }
      } catch (_) {
        // Ignore cleanup failure to preserve original Firestore error.
      }
      rethrow;
    }
    return TenantDocument(
      id: '',
      fileUrl: uploadResult.downloadUrl,
      fileType: fileType,
      uploadedAt: uploadResult.createdAt,
      description: description,
      publicId: uploadResult.storagePath,
      fileSizeBytes: uploadResult.uploadedBytes,
      thumbnailUrl: uploadResult.thumbnailUrl,
      storagePath: uploadResult.storagePath,
      thumbnailStoragePath: uploadResult.thumbnailStoragePath,
      thumbnailSizeBytes: uploadResult.thumbnailSizeBytes,
    );
  }

  Future<void> delete({
    required String tenantId,
    required TenantDocument document,
  }) async {
    final storagePath = document.storagePath.trim().isEmpty
        ? document.publicId.trim()
        : document.storagePath.trim();
    if (storagePath.isNotEmpty) {
      try {
        await documentStorageService.deleteByStoragePath(storagePath);
      } catch (_) {
        // Allow deleting Firestore reference even if remote file cleanup fails.
      }
    }
    if ((document.thumbnailStoragePath ?? '').trim().isNotEmpty) {
      try {
        await documentStorageService.deleteByStoragePath(
          document.thumbnailStoragePath!.trim(),
        );
      } catch (_) {
        // Ignore thumbnail cleanup failure.
      }
    }
    await firestoreService.deleteDocument(tenantId, document.id);
  }
}

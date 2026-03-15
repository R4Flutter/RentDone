import 'dart:io';

import 'package:rentdone/features/tenant/data/models/tenant_document.dart';
import 'package:rentdone/features/tenant/data/services/cloudinary_document_service.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';

import 'tenant_document_file_type.dart';

class TenantDashboardDocumentsCoordinator {
  final TenantFirestoreService firestoreService;
  final CloudinaryDocumentService cloudinaryService;

  const TenantDashboardDocumentsCoordinator({
    required this.firestoreService,
    required this.cloudinaryService,
  });

  Future<TenantDocument> upload({
    required String tenantId,
    required File file,
    required String fileName,
    required String description,
    required int fileSizeBytes,
  }) async {
    final uploadResult = await cloudinaryService.uploadTenantDocument(
      tenantId: tenantId,
      file: file,
      fileName: fileName,
    );
    final fileType = resolveTenantDocumentFileType(fileName);
    try {
      await firestoreService.saveUploadedDocument(
        tenantId: tenantId,
        fileUrl: uploadResult.secureUrl,
        fileType: fileType,
        publicId: uploadResult.publicId,
        description: description,
        fileSizeBytes: fileSizeBytes,
        deleteToken: uploadResult.deleteToken,
      );
    } catch (_) {
      final deleteToken = uploadResult.deleteToken;
      if (deleteToken != null && deleteToken.isNotEmpty) {
        try {
          await cloudinaryService.deleteWithToken(deleteToken);
        } catch (_) {}
      }
      rethrow;
    }
    return TenantDocument(
      id: '',
      fileUrl: uploadResult.secureUrl,
      fileType: fileType,
      uploadedAt: uploadResult.createdAt,
      description: description,
      publicId: uploadResult.publicId,
      fileSizeBytes: fileSizeBytes,
      deleteToken: uploadResult.deleteToken,
    );
  }

  Future<void> delete({
    required String tenantId,
    required TenantDocument document,
  }) async {
    if (document.deleteToken == null || document.deleteToken!.isEmpty) {
      throw Exception(
        'Delete token missing. Upload should be deleted by backend Cloudinary signature flow.',
      );
    }
    await cloudinaryService.deleteWithToken(document.deleteToken!);
    await firestoreService.deleteDocument(tenantId, document.id);
  }
}

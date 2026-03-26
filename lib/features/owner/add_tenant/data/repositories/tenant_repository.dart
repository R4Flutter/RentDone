import 'dart:io';

import '../exceptions/document_upload_exceptions.dart';
import '../services/firebase_storage_service.dart';

class TenantDocumentRepository {
  TenantDocumentRepository({
    required FirebaseDocumentStorageService storageService,
  }) : _storageService = storageService;

  static const int _maxSourceBytes = 12 * 1024 * 1024;
  static const Set<String> _allowedFormats = {
    'jpg',
    'jpeg',
    'png',
    'pdf',
    'webp',
  };

  final FirebaseDocumentStorageService _storageService;

  FirebaseDocumentStorageService get storageService => _storageService;

  Future<String> uploadTenantDocument({
    required File file,
    required String tenantId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      if (!_allowedFormats.contains(extension)) {
        throw const StorageUploadException(
          'Only jpg, jpeg, png, webp and pdf files are allowed.',
        );
      }

      final size = await file.length();
      if (size > _maxSourceBytes) {
        throw const StorageUploadException(
          'File too large. Maximum allowed source size is 12MB.',
        );
      }

      final secureUrl = await _storageService.uploadDocument(
        file: file,
        tenantId: tenantId,
        onProgress: onProgress,
      );

      // Note: Document URLs are stored in the tenant document created during tenant save,
      // not here. This method uploads to Firebase Storage and returns the URL.
      return secureUrl;
    } catch (error) {
      rethrow;
    }
  }
}

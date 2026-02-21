import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../exceptions/document_upload_exceptions.dart';
import '../services/cloudinary_service.dart';

class TenantDocumentRepository {
  TenantDocumentRepository({required CloudinaryService cloudinaryService})
    : _cloudinaryService = cloudinaryService;

  static const int _maxBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedFormats = {'jpg', 'jpeg', 'png', 'pdf'};

  final CloudinaryService _cloudinaryService;

  Future<String> uploadTenantDocument({
    required File file,
    required String tenantId,
    void Function(double progress)? onProgress,
  }) async {
    File? compressedFile;
    try {
      final extension = file.path.split('.').last.toLowerCase();
      if (!_allowedFormats.contains(extension)) {
        throw const CloudinaryUploadException(
          'Only jpg, jpeg, png and pdf files are allowed.',
        );
      }

      final size = await file.length();
      if (size > _maxBytes) {
        throw const CloudinaryUploadException('File size must be 5MB or less.');
      }

      compressedFile = await _compressIfImage(file, extension, tenantId);
      final secureUrl = await _cloudinaryService.uploadDocument(
        file: compressedFile,
        tenantId: tenantId,
        onProgress: onProgress,
      );

      // Note: Document URLs are stored in the tenant document created during tenant save,
      // not here. This method only uploads to Cloudinary and returns the URL.
      return secureUrl;
    } catch (error) {
      rethrow;
    } finally {
      // Clean up compressed temp file if it was created and is different from original
      if (compressedFile != null && compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
  }

  Future<File> _compressIfImage(
    File original,
    String extension,
    String tenantId,
  ) async {
    if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
      return original;
    }

    final tempPath =
        '${Directory.systemTemp.path}/rentdone_${tenantId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      original.absolute.path,
      tempPath,
      quality: 80,
      minWidth: 1280,
      minHeight: 1280,
      keepExif: false,
    );

    if (compressed == null) return original;
    return File(compressed.path);
  }
}

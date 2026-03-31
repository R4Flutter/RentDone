import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../exceptions/document_upload_exceptions.dart';

class FirebaseDocumentStorageService {
  final FirebaseStorage _storage;
  final FirebaseStorage? _fallbackStorage;
  final FirebaseAuth _auth;

  String get bucket => _storage.bucket;

  static const _maxSourceFileSizeBytes = 12 * 1024 * 1024;
  static const _targetImageCompressedBytes = 200 * 1024;
  static const _targetPdfUploadBytes = 500 * 1024;
  static const _maxUploadBytes = 2 * 1024 * 1024;
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'pdf', 'webp'};

  FirebaseDocumentStorageService({FirebaseStorage? storage, FirebaseAuth? auth})
    : _storage = _resolvePrimaryStorage(storage),
      _fallbackStorage = _resolveFallbackStorage(storage),
      _auth = auth ?? FirebaseAuth.instance;

  static FirebaseStorage _resolvePrimaryStorage(FirebaseStorage? override) {
    if (override != null) {
      return override;
    }

    final options = Firebase.app().options;
    final configuredBucket = (options.storageBucket ?? '').trim();
    if (configuredBucket.isEmpty) {
      return FirebaseStorage.instance;
    }

    return FirebaseStorage.instanceFor(bucket: configuredBucket);
  }

  static FirebaseStorage? _resolveFallbackStorage(FirebaseStorage? override) {
    if (override != null) {
      return null;
    }

    final options = Firebase.app().options;
    final projectId = options.projectId.trim();
    final configuredBucket = (options.storageBucket ?? '').trim();

    if (projectId.isEmpty || configuredBucket.isEmpty) {
      return null;
    }

    final fallbackBucket = configuredBucket.endsWith('.firebasestorage.app')
        ? '$projectId.appspot.com'
        : '$projectId.firebasestorage.app';

    if (fallbackBucket == configuredBucket) {
      return null;
    }

    return FirebaseStorage.instanceFor(bucket: fallbackBucket);
  }

  bool _isNotFoundStorageError(FirebaseException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();
    return code == 'object-not-found' ||
        code == 'bucket-not-found' ||
        message.contains('404') ||
        message.contains('not found');
  }

  Future<String> _uploadAndGetUrl({
    required FirebaseStorage storage,
    required String storagePath,
    required File uploadFile,
    required String extension,
    void Function(double progress)? onProgress,
  }) async {
    final ref = storage.ref().child(storagePath);
    final task = ref.putFile(
      uploadFile,
      SettableMetadata(contentType: _contentType(extension)),
    );

    final sub = task.snapshotEvents.listen((snapshot) {
      if (onProgress == null || snapshot.totalBytes == 0) {
        return;
      }
      onProgress((snapshot.bytesTransferred / snapshot.totalBytes).clamp(0, 1));
    });

    try {
      await task.timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL();
    } finally {
      await sub.cancel();
    }
  }

  Future<String> uploadDocument({
    required File file,
    required String tenantId,
    void Function(double progress)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw const StorageUploadException('File does not exist.');
    }

    final extension = file.path.split('.').last.toLowerCase();

    if (!_allowedExtensions.contains(extension)) {
      throw StorageUploadException(
        'Invalid file type: .$extension. Allowed: ${_allowedExtensions.join(', ')}',
      );
    }

    final sourceBytes = await file.length();
    if (sourceBytes > _maxSourceFileSizeBytes) {
      throw StorageUploadException(
        'File too large. Maximum allowed source size is 12MB.',
      );
    }

    File uploadFile = file;
    if (_isImage(extension)) {
      uploadFile = await _compressImageToBudget(
        file,
        extension,
        tenantId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final uploadBytes = await uploadFile.length();
    if (_isImage(extension) && uploadBytes > _targetImageCompressedBytes) {
      throw const StorageUploadException(
        'Image could not be compressed to 200KB. Please choose a clearer or smaller image.',
      );
    }
    if (extension == 'pdf' && uploadBytes > _targetPdfUploadBytes) {
      throw const StorageUploadException(
        'PDF must be 500KB or below. Please upload a smaller PDF.',
      );
    }
    if (uploadBytes > _maxUploadBytes) {
      throw const StorageUploadException(
        'Compressed file exceeds 2MB. Please upload a clearer or smaller file.',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw const StorageUploadException('User not authenticated.');
    }
    final safeName = file.path
        .split(Platform.pathSeparator)
        .last
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        'images/users/$userId/tenants/$tenantId/documents/${timestamp}_$safeName';

    if (kDebugMode) {
      debugPrint('--- Firebase Storage Upload Debug ---');
      debugPrint('Bucket: ${_storage.bucket}');
      debugPrint('StoragePath: $storagePath');
      debugPrint('File: ${file.path}');
      debugPrint('Source Size: ${sourceBytes / 1024} KB');
      debugPrint('Upload Size: ${uploadBytes / 1024} KB');
      debugPrint('--------------------------------');
    }

    try {
      String downloadUrl;
      try {
        downloadUrl = await _uploadAndGetUrl(
          storage: _storage,
          storagePath: storagePath,
          uploadFile: uploadFile,
          extension: extension,
          onProgress: onProgress,
        );
      } on FirebaseException catch (e) {
        final fallbackStorage = _fallbackStorage;
        if (fallbackStorage == null || !_isNotFoundStorageError(e)) {
          rethrow;
        }

        if (kDebugMode) {
          debugPrint(
            'Primary bucket upload failed (${_storage.bucket}); retrying fallback bucket ${fallbackStorage.bucket}',
          );
        }

        downloadUrl = await _uploadAndGetUrl(
          storage: fallbackStorage,
          storagePath: storagePath,
          uploadFile: uploadFile,
          extension: extension,
          onProgress: onProgress,
        );
      }

      onProgress?.call(1.0);
      return downloadUrl;
    } on TimeoutException {
      throw const StorageUploadException(
        'Upload took too long (>60s). Please check your connection and try again.',
      );
    } on FirebaseException catch (e) {
      if (_isNotFoundStorageError(e)) {
        final fallbackStorage = _fallbackStorage;
        final attemptedBuckets = <String>{
          _storage.bucket,
          if (fallbackStorage != null) fallbackStorage.bucket,
        };
        throw StorageUploadException(
          'Storage bucket not found for ${attemptedBuckets.join(' or ')}. Create Firebase Storage bucket in Firebase Console > Build > Storage.',
        );
      }
      throw StorageUploadException('Upload failed: ${e.message ?? e.code}');
    } catch (e) {
      throw StorageUploadException('Upload failed: $e');
    } finally {
      if (uploadFile.path != file.path) {
        try {
          await uploadFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> _compressImageToBudget(
    File source,
    String extension,
    String tenantId, {
    required int timestamp,
  }) async {
    var quality = 82;
    var width = 1600;
    var height = 1600;
    File current = source;

    for (var i = 0; i < 6; i++) {
      final targetPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}owner_tenant_${tenantId}_${timestamp}_$i.$extension';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        current.path,
        targetPath,
        quality: quality,
        minWidth: width,
        minHeight: height,
        keepExif: false,
        format: _compressFormat(extension),
      );

      if (compressed == null) {
        break;
      }

      current = File(compressed.path);
      final size = await current.length();
      if (size <= _targetImageCompressedBytes) {
        return current;
      }

      quality = (quality - 10).clamp(45, 82);
      width = (width * 0.85).round();
      height = (height * 0.85).round();
    }

    return current;
  }

  bool _isImage(String extension) {
    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  CompressFormat _compressFormat(String extension) {
    switch (extension) {
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      case 'jpg':
      case 'jpeg':
      default:
        return CompressFormat.jpeg;
    }
  }
}

import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class FirebaseDocumentUploadResult {
  final String downloadUrl;
  final String storagePath;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final String? thumbnailStoragePath;
  final int uploadedBytes;
  final int? thumbnailSizeBytes;

  const FirebaseDocumentUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.createdAt,
    this.thumbnailUrl,
    this.thumbnailStoragePath,
    required this.uploadedBytes,
    this.thumbnailSizeBytes,
  });
}

class FirebaseDocumentStorageService {
  FirebaseDocumentStorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _storage = _resolvePrimaryStorage(storage),
       _fallbackStorage = _resolveFallbackStorage(storage),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseStorage? _fallbackStorage;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const int _maxSourceFileSizeBytes = 100 * 1024 * 1024;
  static const int _targetImageCompressedBytes = 200 * 1024;
  static const int _targetPdfUploadBytes = 500 * 1024;
  static const int _maxUploadBytes = 2 * 1024 * 1024;
  static const int _maxThumbnailBytes = 120 * 1024;
  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  };

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
    required File file,
    required String contentType,
    void Function(TaskSnapshot snapshot)? onSnapshot,
  }) async {
    final ref = storage.ref().child(storagePath);
    final task = ref.putFile(file, SettableMetadata(contentType: contentType));
    final sub = task.snapshotEvents.listen((snapshot) {
      onSnapshot?.call(snapshot);
    });

    try {
      await task.timeout(const Duration(seconds: 60));
      return await ref.getDownloadURL();
    } finally {
      await sub.cancel();
    }
  }

  Future<FirebaseDocumentUploadResult> uploadTenantDocument({
    required String tenantId,
    required File file,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw Exception('Selected file does not exist.');
    }

    final extension = _extensionFromFileName(fileName);
    if (!_allowedExtensions.contains(extension)) {
      throw Exception('Only jpg, jpeg, png, webp and pdf files are allowed.');
    }

    final sourceSize = await file.length();
    if (sourceSize > _maxSourceFileSizeBytes) {
      throw Exception(
        'File too large. Maximum selectable source size is 100MB.',
      );
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not authenticated.');
    }

    final now = DateTime.now();
    final millis = now.millisecondsSinceEpoch;
    final safeName = _safeFileName(fileName);
    final docId = '${millis}_${safeName.replaceAll('.', '_')}';
    final storagePath =
        'images/users/$userId/tenants/$tenantId/documents/$docId/original.$extension';
    final thumbnailStoragePath =
        'images/users/$userId/tenants/$tenantId/documents/$docId/thumb.jpg';

    File uploadFile = file;
    File? thumbnailFile;
    if (_isImage(extension)) {
      onProgress?.call(0.1);
      uploadFile = await _compressImageToBudget(
        file,
        extension,
        tenantId,
        millis,
      );
      thumbnailFile = await _createThumbnail(file, tenantId, millis);
    }

    final uploadBytes = await uploadFile.length();
    if (_isImage(extension) && uploadBytes > _targetImageCompressedBytes) {
      throw Exception(
        'Image could not be compressed to 200KB. Please choose a clearer or smaller image.',
      );
    }
    if (extension == 'pdf' && uploadBytes > _targetPdfUploadBytes) {
      throw Exception(
        'PDF must be 500KB or below. Please upload a smaller PDF.',
      );
    }
    if (uploadBytes > _maxUploadBytes) {
      throw Exception(
        'Compressed file exceeds 2MB. Please upload a clearer or smaller file.',
      );
    }

    try {
      onProgress?.call(0.2);
      String downloadUrl;
      try {
        downloadUrl = await _uploadAndGetUrl(
          storage: _storage,
          storagePath: storagePath,
          file: uploadFile,
          contentType: _contentType(extension),
          onSnapshot: (snapshot) {
            if (onProgress == null || snapshot.totalBytes == 0) {
              return;
            }
            final uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(0.2 + (uploadProgress * 0.7));
          },
        );
      } on FirebaseException catch (e) {
        final fallbackStorage = _fallbackStorage;
        if (fallbackStorage == null || !_isNotFoundStorageError(e)) {
          rethrow;
        }

        downloadUrl = await _uploadAndGetUrl(
          storage: fallbackStorage,
          storagePath: storagePath,
          file: uploadFile,
          contentType: _contentType(extension),
          onSnapshot: (snapshot) {
            if (onProgress == null || snapshot.totalBytes == 0) {
              return;
            }
            final uploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(0.2 + (uploadProgress * 0.7));
          },
        );
      }

      String? thumbUrl;
      int? thumbBytes;
      String? thumbPath;
      if (thumbnailFile != null) {
        thumbBytes = await thumbnailFile.length();
        thumbPath = thumbnailStoragePath;
        try {
          thumbUrl = await _uploadAndGetUrl(
            storage: _storage,
            storagePath: thumbnailStoragePath,
            file: thumbnailFile,
            contentType: 'image/jpeg',
          );
        } on FirebaseException catch (e) {
          final fallbackStorage = _fallbackStorage;
          if (fallbackStorage == null || !_isNotFoundStorageError(e)) {
            rethrow;
          }
          thumbUrl = await _uploadAndGetUrl(
            storage: fallbackStorage,
            storagePath: thumbnailStoragePath,
            file: thumbnailFile,
            contentType: 'image/jpeg',
          );
        }
      }

      onProgress?.call(0.95);

      await _firestore.collection('user_images').add({
        'userId': userId,
        'imageUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'thumbnailUrl': thumbUrl,
        'storagePath': storagePath,
        'thumbnailStoragePath': thumbPath,
        'tenantId': tenantId,
        'fileName': fileName,
        'fileSizeBytes': uploadBytes,
        if (thumbBytes != null) 'thumbnailSizeBytes': thumbBytes,
      });

      onProgress?.call(1.0);

      return FirebaseDocumentUploadResult(
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        createdAt: now,
        thumbnailUrl: thumbUrl,
        thumbnailStoragePath: thumbPath,
        uploadedBytes: uploadBytes,
        thumbnailSizeBytes: thumbBytes,
      );
    } on TimeoutException {
      throw Exception(
        'Upload timed out after 60 seconds. Please check your network and retry.',
      );
    } on FirebaseException catch (e) {
      if (_isNotFoundStorageError(e)) {
        final fallbackStorage = _fallbackStorage;
        final attemptedBuckets = <String>{
          _storage.bucket,
          if (fallbackStorage != null) fallbackStorage.bucket,
        };
        throw Exception(
          'Storage bucket not found for ${attemptedBuckets.join(' or ')}. Create Firebase Storage bucket in Firebase Console > Build > Storage.',
        );
      }
      throw Exception('Storage upload failed: ${e.message ?? e.code}');
    } finally {
      if (uploadFile.path != file.path) {
        try {
          await uploadFile.delete();
        } catch (_) {}
      }
      if (thumbnailFile != null && thumbnailFile.path != file.path) {
        try {
          await thumbnailFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> deleteByStoragePath(String storagePath) async {
    if (storagePath.isEmpty) {
      throw Exception('Storage path missing for document deletion.');
    }
    await _storage.ref().child(storagePath).delete();
  }

  Future<File> _compressImageToBudget(
    File source,
    String extension,
    String tenantId,
    int millis,
  ) async {
    var quality = 82;
    var width = 1600;
    var height = 1600;
    File current = source;

    for (var i = 0; i < 6; i++) {
      final targetPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}tenant_${tenantId}_${millis}_$i.$extension';

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

  Future<File> _createThumbnail(
    File source,
    String tenantId,
    int millis,
  ) async {
    final targetPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}tenant_${tenantId}_${millis}_thumb.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      source.path,
      targetPath,
      quality: 58,
      minWidth: 360,
      minHeight: 360,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) {
      throw Exception('Thumbnail generation failed.');
    }

    final thumb = File(compressed.path);
    if (await thumb.length() > _maxThumbnailBytes) {
      final tuned = await FlutterImageCompress.compressAndGetFile(
        source.path,
        targetPath,
        quality: 48,
        minWidth: 300,
        minHeight: 300,
        keepExif: false,
        format: CompressFormat.jpeg,
      );
      if (tuned != null) {
        return File(tuned.path);
      }
    }

    return thumb;
  }

  bool _isImage(String extension) {
    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp';
  }

  String _safeFileName(String fileName) {
    return fileName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  String _extensionFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) {
      return 'jpg';
    }
    return fileName.substring(dot + 1).toLowerCase();
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

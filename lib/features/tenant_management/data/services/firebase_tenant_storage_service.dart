import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for uploading profile and tenant documents to Firebase Storage.
class FirebaseTenantStorageService {
  FirebaseTenantStorageService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  }) : _storage = _resolvePrimaryStorage(storage),
       _fallbackStorage = _resolveFallbackStorage(storage),
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseStorage? _fallbackStorage;
  final FirebaseFirestore _firestore;

  static const int _maxSourceFileSizeBytes = 12 * 1024 * 1024;
  static const int _targetImageCompressedBytes = 200 * 1024;
  static const int _targetPdfUploadBytes = 500 * 1024;
  static const int _maxUploadBytes = 2 * 1024 * 1024;
  static const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

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

  Future<String> uploadProfileImage({
    required File imageFile,
    required String tenantId,
    String? userId,
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFileWithRetry(
      file: imageFile,
      userId: userId,
      tenantId: tenantId,
      fileKind: 'profile',
      onProgress: onProgress,
    );
  }

  Future<String> uploadIdProof({
    required File documentFile,
    required String tenantId,
    required String idType,
    String? userId,
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFileWithRetry(
      file: documentFile,
      userId: userId,
      tenantId: tenantId,
      fileKind: idType,
      onProgress: onProgress,
    );
  }

  Future<String> uploadAgreement({
    required File documentFile,
    required String tenantId,
    String? userId,
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFileWithRetry(
      file: documentFile,
      userId: userId,
      tenantId: tenantId,
      fileKind: 'agreement',
      onProgress: onProgress,
    );
  }

  Future<String> uploadDocument({
    required File documentFile,
    required String tenantId,
    required String documentType,
    String? userId,
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFileWithRetry(
      file: documentFile,
      userId: userId,
      tenantId: tenantId,
      fileKind: documentType,
      onProgress: onProgress,
    );
  }

  Future<String> _uploadFileWithRetry({
    required File file,
    required String? userId,
    required String tenantId,
    required String fileKind,
    void Function(double progress)? onProgress,
  }) async {
    const retryableCodes = {
      'aborted',
      'cancelled',
      'deadline-exceeded',
      'network-request-failed',
      'retry-limit-exceeded',
      'unavailable',
      'unknown',
    };

    const retryDelays = <Duration>[
      Duration(milliseconds: 400),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1600),
    ];

    Object? lastError;
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        return await _uploadFile(
          file: file,
          userId: userId,
          tenantId: tenantId,
          fileKind: fileKind,
          onProgress: onProgress,
        );
      } on FirebaseException catch (e) {
        lastError = e;
        if (!retryableCodes.contains(e.code) || attempt == retryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      } catch (e) {
        lastError = e;
        if (attempt == retryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }

    throw Exception('Upload failed after retries: $lastError');
  }

  Future<String> _uploadFile({
    required File file,
    required String? userId,
    required String tenantId,
    required String fileKind,
    void Function(double progress)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final rawSize = await file.length();
    if (rawSize > _maxSourceFileSizeBytes) {
      throw Exception('File too large. Maximum allowed source size is 12MB.');
    }

    final extension = _extensionFromPath(file.path);
    final effectiveUserId = (userId == null || userId.isEmpty)
        ? 'unknown_user'
        : userId;
    final now = DateTime.now().millisecondsSinceEpoch;
    final objectName = '${fileKind}_${tenantId}_$now.$extension';
    final storagePath =
        'images/users/$effectiveUserId/tenants/$tenantId/$objectName';

    File uploadFile = file;
    if (_imageExtensions.contains(extension)) {
      uploadFile = await _compressImageToBudget(
        source: file,
        extension: extension,
        objectName: objectName,
      );
    }

    final uploadBytes = await uploadFile.length();
    if (_imageExtensions.contains(extension) &&
        uploadBytes > _targetImageCompressedBytes) {
      throw Exception(
        'Image could not be compressed to 200KB. Please choose a clearer or smaller image.',
      );
    }
    if (extension == 'pdf' && uploadBytes > _targetPdfUploadBytes) {
      throw Exception('PDF must be 500KB or below. Please upload a smaller PDF.');
    }
    if (uploadBytes > _maxUploadBytes) {
      throw Exception(
        'Compressed file exceeds 2MB. Please upload a clearer or smaller file.',
      );
    }

    try {
      final metadata = SettableMetadata(
        contentType: _contentTypeForExtension(extension),
      );

      String downloadUrl;
      try {
        downloadUrl = await _uploadAndGetUrl(
          storage: _storage,
          storagePath: storagePath,
          file: uploadFile,
          contentType: metadata.contentType ?? 'application/octet-stream',
          onSnapshot: (event) {
            if (onProgress == null || event.totalBytes <= 0) {
              return;
            }
            onProgress(event.bytesTransferred / event.totalBytes);
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
          contentType: metadata.contentType ?? 'application/octet-stream',
          onSnapshot: (event) {
            if (onProgress == null || event.totalBytes <= 0) {
              return;
            }
            onProgress(event.bytesTransferred / event.totalBytes);
          },
        );
      }

      await _firestore.collection('user_images').add({
        'userId': effectiveUserId,
        'imageUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'thumbnailUrl': null,
        'storagePath': storagePath,
        'tenantId': tenantId,
        'fileKind': fileKind,
        'fileSizeBytes': uploadBytes,
      });

      return downloadUrl;
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
    }
  }

  Future<File> _compressImageToBudget({
    required File source,
    required String extension,
    required String objectName,
  }) async {
    var quality = 82;
    var width = 1600;
    var height = 1600;
    File current = source;

    for (var i = 0; i < 6; i++) {
      final targetPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}rentdone_${objectName}_$i.$extension';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        current.path,
        targetPath,
        quality: quality,
        minWidth: width,
        minHeight: height,
        keepExif: false,
        format: _compressFormatForExtension(extension),
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

  String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return 'jpg';
    }
    return path.substring(dot + 1).toLowerCase();
  }

  CompressFormat _compressFormatForExtension(String extension) {
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

  String _contentTypeForExtension(String extension) {
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
}

final firebaseTenantStorageServiceProvider =
    Provider<FirebaseTenantStorageService>((ref) {
      return FirebaseTenantStorageService();
    });

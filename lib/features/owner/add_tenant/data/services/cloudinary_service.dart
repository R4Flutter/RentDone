import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../exceptions/document_upload_exceptions.dart';

class CloudinaryService {
  final http.Client _client;
  final String _cloudName;
  final String _uploadPreset;

  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'pdf', 'webp'};

  CloudinaryService({
    required String cloudName,
    required String uploadPreset,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _cloudName = cloudName.trim(),
       _uploadPreset = uploadPreset.trim() {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary configuration is missing.',
      );
    }
  }

  Future<String> uploadDocument({
    required File file,
    required String tenantId,
    void Function(double progress)? onProgress,
  }) async {
    // Validate configuration first
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary configuration is missing. Contact support.',
      );
    }

    if (!await file.exists()) {
      throw const CloudinaryUploadException('File does not exist.');
    }

    final extension = file.path.split('.').last.toLowerCase();

    if (!_allowedExtensions.contains(extension)) {
      throw CloudinaryUploadException(
        'Invalid file type: .$extension. Allowed: ${_allowedExtensions.join(', ')}',
      );
    }

    final totalBytes = await file.length();

    if (totalBytes > _maxFileSizeBytes) {
      throw CloudinaryUploadException(
        'File too large. Maximum size is ${_maxFileSizeBytes ~/ (1024 * 1024)}MB.',
      );
    }

    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
    );

    final folder = 'rentdone/tenants/$tenantId/documents';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final publicId = '${tenantId}_$timestamp';

    int sentBytes = 0;

    final stream = http.ByteStream(
      file.openRead().transform(
        StreamTransformer.fromHandlers(
          handleData: (chunk, sink) {
            sentBytes += chunk.length;
            if (onProgress != null && totalBytes > 0) {
              onProgress((sentBytes / totalBytes).clamp(0.0, 1.0));
            }
            sink.add(chunk);
          },
        ),
      ),
    );

    final request = http.MultipartRequest('POST', endpoint)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = publicId
      ..files.add(
        http.MultipartFile(
          'file',
          stream,
          totalBytes,
          filename: '$publicId.$extension',
        ),
      );

    if (kDebugMode) {
      debugPrint('--- Cloudinary Upload Debug ---');
      debugPrint('CloudName: $_cloudName');
      debugPrint('UploadPreset: $_uploadPreset');
      debugPrint('Endpoint: $endpoint');
      debugPrint('Folder: $folder');
      debugPrint('File: ${file.path}');
      debugPrint('Size: ${totalBytes / 1024} KB');
      debugPrint('--------------------------------');
    }

    http.StreamedResponse response;

    try {
      response = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const CloudinaryUploadException(
        'Upload took too long (>60s). Please check your connection and try again.',
      );
    } on SocketException catch (e) {
      throw CloudinaryUploadException(
        'Network error: ${e.message}. Check your internet connection.',
      );
    } catch (e) {
      throw CloudinaryUploadException('Upload failed: $e');
    }

    final responseBody = await response.stream.bytesToString();

    if (kDebugMode) {
      debugPrint(
        'Cloudinary response: ${response.statusCode} -> $responseBody',
      );
    }

    if (response.statusCode != 200) {
      try {
        final errorJson = jsonDecode(responseBody);
        final errorMsg = errorJson['error']?['message'] ?? 'Unknown error';
        throw CloudinaryUploadException(
          'Upload failed: $errorMsg (${response.statusCode})',
          statusCode: response.statusCode,
        );
      } catch (e) {
        // If JSON parsing fails, use generic message
        throw CloudinaryUploadException(
          'Upload failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }

    late final Map<String, dynamic> json;

    try {
      json = jsonDecode(responseBody);
    } catch (_) {
      throw const CloudinaryUploadException(
        'Invalid upload response format. Contact support.',
      );
    }

    final secureUrl = json['secure_url']?.toString();

    if (secureUrl == null || secureUrl.isEmpty) {
      if (kDebugMode) {
        debugPrint('Full response: $json');
      }
      throw const CloudinaryUploadException(
        'Upload succeeded but no file URL returned.',
      );
    }

    onProgress?.call(1.0);
    return secureUrl;
  }

  void dispose() {
    _client.close();
  }
}

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
  final String _apiHost;

  String get cloudName => _cloudName;
  String get uploadPreset => _uploadPreset;
  String get apiHost => _apiHost;

  static const _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'pdf', 'webp'};

  CloudinaryService({
    required String cloudName,
    required String uploadPreset,
    String apiHost = 'api.cloudinary.com',
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _cloudName = cloudName.trim(),
       _uploadPreset = uploadPreset.trim(),
       _apiHost = _normalizeApiHost(apiHost) {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw const CloudinaryUploadException(
        'Cloudinary configuration is missing.',
      );
    }
  }

  static String _normalizeApiHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'api.cloudinary.com';
    }
    final withoutScheme = trimmed.replaceFirst(RegExp(r'^https?://'), '');
    return withoutScheme.split('/').first;
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

    final endpoint = Uri.https(_apiHost, '/v1_1/$_cloudName/auto/upload');

    final folder = 'rentdone/tenants/$tenantId/documents';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final publicId = '${tenantId}_$timestamp';

    if (kDebugMode) {
      debugPrint('--- Cloudinary Upload Debug ---');
      debugPrint('CloudName: $_cloudName');
      debugPrint('UploadPreset: $_uploadPreset');
      debugPrint('ApiHost: $_apiHost');
      debugPrint('Endpoint: $endpoint');
      debugPrint('Folder: $folder');
      debugPrint('File: ${file.path}');
      debugPrint('Size: ${totalBytes / 1024} KB');
      debugPrint('--------------------------------');
    }

    http.StreamedResponse response;
    var progressBase = 0.0;

    try {
      response = await _sendUploadRequest(
        endpoint: endpoint,
        file: file,
        totalBytes: totalBytes,
        fileName: '$publicId.$extension',
        folder: folder,
        publicId: publicId,
        onProgress: (progress) {
          if (onProgress == null) {
            return;
          }
          final normalized = (progressBase + (progress * 0.5)).clamp(0.0, 1.0);
          onProgress(normalized);
        },
      );

      if (_isRedirect(response.statusCode)) {
        final redirectUri = _resolveRedirectUri(response, endpoint);
        if (redirectUri != null) {
          if (kDebugMode) {
            debugPrint(
              'Cloudinary redirect (${response.statusCode}) -> $redirectUri',
            );
          }
          progressBase = 0.5;
          await response.stream.drain();
          response = await _sendUploadRequest(
            endpoint: redirectUri,
            file: file,
            totalBytes: totalBytes,
            fileName: '$publicId.$extension',
            folder: folder,
            publicId: publicId,
            onProgress: (progress) {
              if (onProgress == null) {
                return;
              }
              final normalized = (progressBase + (progress * 0.5)).clamp(
                0.0,
                1.0,
              );
              onProgress(normalized);
            },
          );
        }
      }
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

  Future<http.StreamedResponse> _sendUploadRequest({
    required Uri endpoint,
    required File file,
    required int totalBytes,
    required String fileName,
    required String folder,
    required String publicId,
    void Function(double progress)? onProgress,
  }) {
    var sentBytes = 0;
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
        http.MultipartFile('file', stream, totalBytes, filename: fileName),
      );

    return _client.send(request).timeout(const Duration(seconds: 60));
  }

  bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  Uri? _resolveRedirectUri(
    http.StreamedResponse response,
    Uri originalEndpoint,
  ) {
    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) {
      return null;
    }
    final redirected = Uri.tryParse(location.trim());
    if (redirected == null) {
      return null;
    }
    if (redirected.hasScheme) {
      return redirected;
    }
    return originalEndpoint.resolveUri(redirected);
  }

  void dispose() {
    _client.close();
  }
}

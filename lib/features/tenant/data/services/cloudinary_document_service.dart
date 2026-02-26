import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CloudinaryUploadResult {
  final String secureUrl;
  final String publicId;
  final DateTime? createdAt;
  final String? deleteToken;

  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.createdAt,
    this.deleteToken,
  });
}

class CloudinaryDocumentService {
  static const int maxFileSizeBytes = 50 * 1024 * 1024;
  static const int _maxRetryAttempts = 3;

  static const String _cloudNamePrimary = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String _uploadPresetPrimary = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
  static const String _cloudNameLegacy = String.fromEnvironment(
    'CLOUDINARY_CLOUD',
    defaultValue: 'dmvogtrcg',
  );
  static const String _uploadPresetLegacy = String.fromEnvironment(
    'CLOUDINARY_PRESET',
    defaultValue: 'rentdoneapp',
  );
  static const String _apiHostPrimary = String.fromEnvironment(
    'CLOUDINARY_API_HOST',
    defaultValue: '',
  );
  static const String _apiHostLegacy = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_API_HOST',
    defaultValue: '',
  );

  final String cloudName;
  final String unsignedUploadPreset;
  final String _apiHost;
  final Dio _dio;

  CloudinaryDocumentService({
    Dio? dio,
    String? cloudName,
    String? unsignedUploadPreset,
    String? apiHost,
  }) : _dio = dio ?? Dio(),
       cloudName =
           cloudName ??
           (_cloudNamePrimary.isNotEmpty
               ? _cloudNamePrimary
               : _cloudNameLegacy),
       unsignedUploadPreset =
           unsignedUploadPreset ??
           (_uploadPresetPrimary.isNotEmpty
               ? _uploadPresetPrimary
               : _uploadPresetLegacy),
       _apiHost = _normalizeApiHost(
         apiHost ??
             (_apiHostPrimary.isNotEmpty ? _apiHostPrimary : _apiHostLegacy),
       );

  Future<CloudinaryUploadResult> uploadTenantDocument({
    required String tenantId,
    required File file,
    required String fileName,
  }) async {
    final preparedFile = await _prepareFile(file, fileName);
    final fileSize = await preparedFile.length();
    if (fileSize > maxFileSizeBytes) {
      throw Exception('File exceeds 50MB limit');
    }

    return _uploadWithUnsignedFallbacks(
      tenantId: tenantId,
      preparedFile: preparedFile,
      fileName: fileName,
    );
  }

  Future<CloudinaryUploadResult> _uploadWithUnsignedFallbacks({
    required String tenantId,
    required File preparedFile,
    required String fileName,
  }) async {
    final cloudCandidates = _candidateCloudNames();
    final presetCandidates = _candidateUploadPresets();

    if (presetCandidates.isEmpty) {
      throw Exception('Cloudinary upload preset is missing');
    }

    final folder = 'rentdone/tenants/$tenantId/documents';
    final publicId =
        '${DateTime.now().millisecondsSinceEpoch}_${_safeName(fileName)}';
    final attempts = <String>[];

    for (final candidateCloud in cloudCandidates) {
      final uploadEndpoint = Uri.https(
        _apiHost,
        '/v1_1/$candidateCloud/auto/upload',
      ).toString();

      for (final candidatePreset in presetCandidates) {
        final result = await _tryUnsignedConfig(
          preparedFile: preparedFile,
          fileName: fileName,
          uploadEndpoint: uploadEndpoint,
          uploadPreset: candidatePreset,
          folder: folder,
          publicId: publicId,
        );

        if (result.data != null) {
          final data = result.data!;
          final secureUrl = (data['secure_url'] ?? '').toString().trim();
          if (secureUrl.isEmpty) {
            continue;
          }

          return CloudinaryUploadResult(
            secureUrl: secureUrl,
            publicId: (data['public_id'] ?? publicId).toString(),
            createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
            deleteToken: (data['delete_token'] ?? '').toString().trim().isEmpty
                ? null
                : data['delete_token'].toString(),
          );
        }

        if (result.error != null) {
          attempts.add(
            'cloud=$candidateCloud preset=$candidatePreset -> ${_compactError(result.error!)}',
          );
        }
      }
    }

    throw Exception(
      'Cloudinary upload failed for all configurations. ${attempts.join(' | ')}',
    );
  }

  Future<_UploadAttemptResult> _tryUnsignedConfig({
    required File preparedFile,
    required String fileName,
    required String uploadEndpoint,
    required String uploadPreset,
    required String folder,
    required String publicId,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final payloadVariants = <Map<String, String>>[
          {
            'upload_preset': uploadPreset,
            'folder': folder,
            'public_id': publicId,
            'return_delete_token': 'true',
          },
          {
            'upload_preset': uploadPreset,
            'folder': folder,
            'public_id': publicId,
          },
          {'upload_preset': uploadPreset, 'folder': folder},
        ];

        Object? variantError;
        for (final fields in payloadVariants) {
          final response = await _postUnsignedUpload(
            uploadEndpoint: uploadEndpoint,
            preparedFile: preparedFile,
            fileName: fileName,
            fields: fields,
          );

          final statusCode = response.statusCode ?? 0;
          if (statusCode >= 200 && statusCode < 300) {
            return _UploadAttemptResult(data: _responseDataMap(response.data));
          }

          variantError = Exception(
            'HTTP $statusCode: ${_responseErrorMessage(response.data)}',
          );
        }

        if (variantError != null) {
          throw variantError;
        }
      } on DioException catch (error) {
        lastError = Exception(_dioErrorMessage(error));
        if (!_isRetryableNetworkError(error) || attempt == _maxRetryAttempts) {
          return _UploadAttemptResult(error: lastError);
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      } catch (error) {
        lastError = error;
        if (attempt == _maxRetryAttempts) {
          return _UploadAttemptResult(error: error);
        }
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    return _UploadAttemptResult(
      error: Exception(
        'Cloudinary unsigned upload failed: ${_compactError(lastError ?? 'unknown error')}',
      ),
    );
  }

  Future<Response<dynamic>> _postUnsignedUpload({
    required String uploadEndpoint,
    required File preparedFile,
    required String fileName,
    required Map<String, String> fields,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        preparedFile.path,
        filename: fileName,
      ),
      ...fields,
    });

    var response = await _dio.post(
      uploadEndpoint,
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        validateStatus: (status) => status != null,
      ),
    );

    if (_isRedirectStatus(response.statusCode)) {
      final redirectedUrl = _resolveRedirectUrl(response, uploadEndpoint);
      if (redirectedUrl != null) {
        final redirectedFormData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            preparedFile.path,
            filename: fileName,
          ),
          ...fields,
        });

        response = await _dio.post(
          redirectedUrl,
          data: redirectedFormData,
          options: Options(
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            followRedirects: false,
            validateStatus: (status) => status != null,
          ),
        );
      }
    }

    return response;
  }

  Future<void> deleteWithToken(String deleteToken) async {
    final endpoint = Uri.https(
      _apiHost,
      '/v1_1/$cloudName/delete_by_token',
    ).toString();
    final response = await _dio.post<Map<String, dynamic>>(
      endpoint,
      data: {'token': deleteToken},
      options: Options(
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw Exception('Cloudinary delete failed');
    }
  }

  Future<File> _prepareFile(File originalFile, String fileName) async {
    final extension = fileName.toLowerCase();
    final isImage =
        extension.endsWith('.jpg') ||
        extension.endsWith('.jpeg') ||
        extension.endsWith('.png') ||
        extension.endsWith('.webp');

    if (!isImage) {
      return originalFile;
    }

    final compressed = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      '${originalFile.absolute.path}_compressed.jpg',
      quality: 75,
      minWidth: 1440,
      minHeight: 1440,
    );

    if (compressed == null) {
      return originalFile;
    }

    return File(compressed.path);
  }

  bool _isRetryableNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown &&
            error.error is SocketException);
  }

  bool _isRedirectStatus(int? statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  String? _resolveRedirectUrl(Response<dynamic> response, String originalUrl) {
    final location = response.headers.value('location');
    if (location == null || location.trim().isEmpty) {
      return null;
    }

    final redirected = Uri.tryParse(location.trim());
    if (redirected == null) {
      return null;
    }

    if (redirected.hasScheme) {
      return redirected.toString();
    }

    return Uri.parse(originalUrl).resolveUri(redirected).toString();
  }

  List<String> _candidateCloudNames() {
    final values = <String>{
      cloudName.trim(),
      _cloudNamePrimary.trim(),
      _cloudNameLegacy.trim(),
      'rentdone',
      'dmvogtrcg',
    };

    return values.where((value) => value.isNotEmpty).toList();
  }

  List<String> _candidateUploadPresets() {
    final values = <String>{
      unsignedUploadPreset.trim(),
      _uploadPresetPrimary.trim(),
      _uploadPresetLegacy.trim(),
      'rentdone_unsigned',
      'rentdoneapp',
    };

    return values.where((value) => value.isNotEmpty).toList();
  }

  Map<String, dynamic> _responseDataMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String && data.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      } catch (_) {
        return const <String, dynamic>{};
      }
    }

    return const <String, dynamic>{};
  }

  String _responseErrorMessage(dynamic data) {
    final map = _responseDataMap(data);
    if (map.isEmpty) {
      return 'Upload failed';
    }

    final errorNode = map['error'];
    if (errorNode is Map<String, dynamic>) {
      final message = (errorNode['message'] ?? '').toString().trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    final message = (map['message'] ?? '').toString().trim();
    if (message.isNotEmpty) {
      return message;
    }

    return map.toString();
  }

  String _dioErrorMessage(DioException error) {
    final status = error.response?.statusCode;
    final details = _responseErrorMessage(error.response?.data);
    if (status != null) {
      return 'HTTP $status: $details';
    }
    return error.message ?? details;
  }

  String _safeName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(' ', '_');
  }

  String _compactError(Object error) {
    final text = error.toString();
    if (text.length <= 200) {
      return text;
    }
    return '${text.substring(0, 200)}...';
  }

  static String _normalizeApiHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'api.cloudinary.com';
    }

    final withoutScheme = trimmed.replaceFirst(RegExp(r'^https?://'), '');
    return withoutScheme.split('/').first;
  }
}

class _UploadAttemptResult {
  final Map<String, dynamic>? data;
  final Object? error;

  const _UploadAttemptResult({this.data, this.error});
}

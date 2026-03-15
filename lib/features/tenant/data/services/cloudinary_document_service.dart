import 'dart:io';

import 'package:dio/dio.dart';
import 'cloudinary/cloudinary_delete_service.dart';
import 'cloudinary/cloudinary_document_uploader.dart';
import 'cloudinary/cloudinary_service_config.dart';
import 'cloudinary/cloudinary_upload_result.dart';

class CloudinaryDocumentService {
  final CloudinaryServiceConfig _config;
  final Dio _dio;

  CloudinaryDocumentService({
    Dio? dio,
    String? cloudName,
    String? unsignedUploadPreset,
    String? apiHost,
  }) : _dio = dio ?? Dio(),
       _config = CloudinaryServiceConfig.resolve(
         cloudName: cloudName,
         uploadPreset: unsignedUploadPreset,
         apiHost: apiHost,
       );

  Future<CloudinaryUploadResult> uploadTenantDocument({
    required String tenantId,
    required File file,
    required String fileName,
  }) => CloudinaryDocumentUploader(
    dio: _dio,
    config: _config,
  ).uploadTenantDocument(tenantId: tenantId, file: file, fileName: fileName);

  Future<void> deleteWithToken(String deleteToken) => CloudinaryDeleteService(
    dio: _dio,
    config: _config,
  ).deleteWithToken(deleteToken);
}

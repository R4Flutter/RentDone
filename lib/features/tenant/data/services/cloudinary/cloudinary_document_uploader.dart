import 'dart:io';

import 'package:dio/dio.dart';

import 'cloudinary_file_preparer.dart';
import 'cloudinary_response_parser.dart';
import 'cloudinary_service_config.dart';
import 'cloudinary_unsigned_attempt_service.dart';
import 'cloudinary_upload_post_client.dart';
import 'cloudinary_upload_result.dart';
import 'cloudinary_upload_result_mapper.dart';

class CloudinaryDocumentUploader {
  static const maxFileSizeBytes = 50 * 1024 * 1024;

  final Dio dio;
  final CloudinaryServiceConfig config;

  const CloudinaryDocumentUploader({required this.dio, required this.config});

  Future<CloudinaryUploadResult> uploadTenantDocument({
    required String tenantId,
    required File file,
    required String fileName,
  }) async {
    final preparedFile = await CloudinaryFilePreparer.prepare(file, fileName);
    if (await preparedFile.length() > maxFileSizeBytes) {
      throw Exception('File exceeds 50MB limit');
    }
    final presetCandidates = config.candidateUploadPresets();
    if (presetCandidates.isEmpty) {
      throw Exception('Cloudinary upload preset is missing');
    }

    final folder = 'rentdone/tenants/$tenantId/documents';
    final publicId =
        '${DateTime.now().millisecondsSinceEpoch}_${safeCloudinaryFileName(fileName)}';
    final attempts = <String>[];
    final attemptService = CloudinaryUnsignedAttemptService(
      CloudinaryUploadPostClient(dio),
    );

    for (final cloud in config.candidateCloudNames()) {
      final endpoint = Uri.https(
        config.apiHost,
        '/v1_1/$cloud/auto/upload',
      ).toString();
      for (final preset in presetCandidates) {
        final result = await attemptService.tryConfig(
          preparedFile: preparedFile,
          fileName: fileName,
          uploadEndpoint: endpoint,
          uploadPreset: preset,
          folder: folder,
          publicId: publicId,
        );
        if (result.data != null) return _resultFromData(result.data!, publicId);
        if (result.error != null) {
          attempts.add(
            'cloud=$cloud preset=$preset -> ${CloudinaryResponseParser.compactError(result.error!)}',
          );
        }
      }
    }

    throw Exception(
      'Cloudinary upload failed for all configurations. ${attempts.join(' | ')}',
    );
  }

  CloudinaryUploadResult _resultFromData(
    Map<String, dynamic> data,
    String publicId,
  ) => mapCloudinaryUploadResult(data, publicId);
}

import 'dart:io';

import 'package:dio/dio.dart';

import 'cloudinary_response_parser.dart';
import 'cloudinary_upload_attempt_result.dart';
import 'cloudinary_upload_payloads.dart';
import 'cloudinary_upload_post_client.dart';

class CloudinaryUnsignedAttemptService {
  static const maxRetryAttempts = 3;

  final CloudinaryUploadPostClient postClient;

  const CloudinaryUnsignedAttemptService(this.postClient);

  Future<CloudinaryUploadAttemptResult> tryConfig({
    required File preparedFile,
    required String fileName,
    required String uploadEndpoint,
    required String uploadPreset,
    required String folder,
    required String publicId,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxRetryAttempts; attempt++) {
      try {
        for (final fields in _payloadVariants(uploadPreset, folder, publicId)) {
          final response = await postClient.post(
            uploadEndpoint: uploadEndpoint,
            preparedFile: preparedFile,
            fileName: fileName,
            fields: fields,
          );
          final statusCode = response.statusCode ?? 0;
          if (statusCode >= 200 && statusCode < 300) {
            return CloudinaryUploadAttemptResult(
              data: CloudinaryResponseParser.dataMap(response.data),
            );
          }
          lastError = Exception(
            'HTTP $statusCode: ${CloudinaryResponseParser.errorMessage(response.data)}',
          );
        }
        throw lastError ?? Exception('Upload failed');
      } on DioException catch (error) {
        lastError = Exception(CloudinaryResponseParser.dioErrorMessage(error));
        if (!_isRetryable(error) || attempt == maxRetryAttempts) {
          return CloudinaryUploadAttemptResult(error: lastError);
        }
      } catch (error) {
        lastError = error;
        if (attempt == maxRetryAttempts) {
          return CloudinaryUploadAttemptResult(error: error);
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
    }
    return CloudinaryUploadAttemptResult(
      error: Exception(
        'Cloudinary unsigned upload failed: ${CloudinaryResponseParser.compactError(lastError ?? 'unknown error')}',
      ),
    );
  }

  List<Map<String, String>> _payloadVariants(
    String uploadPreset,
    String folder,
    String publicId,
  ) => cloudinaryUploadPayloads(uploadPreset, folder, publicId);

  bool _isRetryable(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError ||
      (error.type == DioExceptionType.unknown &&
          error.error is SocketException);
}

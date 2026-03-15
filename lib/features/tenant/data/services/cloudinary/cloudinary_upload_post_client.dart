import 'dart:io';

import 'package:dio/dio.dart';

class CloudinaryUploadPostClient {
  final Dio dio;

  const CloudinaryUploadPostClient(this.dio);

  Future<Response<dynamic>> post({
    required String uploadEndpoint,
    required File preparedFile,
    required String fileName,
    required Map<String, String> fields,
  }) async {
    var response = await dio.post(
      uploadEndpoint,
      data: _formData(preparedFile, fileName, fields),
      options: _options(),
    );
    if (_isRedirectStatus(response.statusCode)) {
      final redirectedUrl = _resolveRedirectUrl(response, uploadEndpoint);
      if (redirectedUrl != null) {
        response = await dio.post(
          redirectedUrl,
          data: _formData(preparedFile, fileName, fields),
          options: _options(),
        );
      }
    }
    return response;
  }

  FormData _formData(
    File preparedFile,
    String fileName,
    Map<String, String> fields,
  ) => FormData.fromMap({
    'file': MultipartFile.fromFileSync(preparedFile.path, filename: fileName),
    ...fields,
  });

  Options _options() => Options(
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: false,
    validateStatus: (status) => status != null,
  );
  bool _isRedirectStatus(int? statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  String? _resolveRedirectUrl(Response<dynamic> response, String originalUrl) {
    final location = response.headers.value('location');
    if (location == null || location.trim().isEmpty) return null;
    final redirected = Uri.tryParse(location.trim());
    if (redirected == null) return null;
    return redirected.hasScheme
        ? redirected.toString()
        : Uri.parse(originalUrl).resolveUri(redirected).toString();
  }
}

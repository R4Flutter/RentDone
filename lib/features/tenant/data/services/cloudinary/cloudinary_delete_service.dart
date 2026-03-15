import 'package:dio/dio.dart';

import 'cloudinary_service_config.dart';

class CloudinaryDeleteService {
  final Dio dio;
  final CloudinaryServiceConfig config;

  const CloudinaryDeleteService({required this.dio, required this.config});

  Future<void> deleteWithToken(String deleteToken) async {
    final endpoint = Uri.https(
      config.apiHost,
      '/v1_1/${config.cloudName}/delete_by_token',
    ).toString();
    final response = await dio.post<Map<String, dynamic>>(
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
}

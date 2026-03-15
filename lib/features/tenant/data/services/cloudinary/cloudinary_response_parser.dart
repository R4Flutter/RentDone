import 'dart:convert';

import 'package:dio/dio.dart';

class CloudinaryResponseParser {
  static Map<String, dynamic> dataMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }

  static String errorMessage(dynamic data) {
    final map = dataMap(data);
    if (map.isEmpty) return 'Upload failed';
    final errorNode = map['error'];
    if (errorNode is Map<String, dynamic>) {
      final message = (errorNode['message'] ?? '').toString().trim();
      if (message.isNotEmpty) return message;
    }
    final message = (map['message'] ?? '').toString().trim();
    return message.isNotEmpty ? message : map.toString();
  }

  static String dioErrorMessage(DioException error) {
    final status = error.response?.statusCode;
    final details = errorMessage(error.response?.data);
    return status != null
        ? 'HTTP $status: $details'
        : (error.message ?? details);
  }

  static String compactError(Object error) {
    final text = error.toString();
    return text.length <= 200 ? text : '${text.substring(0, 200)}...';
  }
}

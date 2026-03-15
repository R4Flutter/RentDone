import 'cloudinary_upload_result.dart';

CloudinaryUploadResult mapCloudinaryUploadResult(
  Map<String, dynamic> data,
  String publicId,
) {
  final secureUrl = (data['secure_url'] ?? '').toString().trim();
  if (secureUrl.isEmpty) {
    throw Exception('Cloudinary upload returned no secure_url');
  }
  final deleteToken = (data['delete_token'] ?? '').toString().trim();
  return CloudinaryUploadResult(
    secureUrl: secureUrl,
    publicId: (data['public_id'] ?? publicId).toString(),
    createdAt: DateTime.tryParse((data['created_at'] ?? '').toString()),
    deleteToken: deleteToken.isEmpty ? null : deleteToken,
  );
}

String safeCloudinaryFileName(String fileName) =>
    fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_').replaceAll(' ', '_');

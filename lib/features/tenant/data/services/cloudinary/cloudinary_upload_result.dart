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

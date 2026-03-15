class CloudinaryServiceConfig {
  static const cloudNamePrimary = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const uploadPresetPrimary = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
  static const cloudNameLegacy = String.fromEnvironment(
    'CLOUDINARY_CLOUD',
    defaultValue: 'dmvogtrcg',
  );
  static const uploadPresetLegacy = String.fromEnvironment(
    'CLOUDINARY_PRESET',
    defaultValue: 'rentdoneapp',
  );
  static const apiHostPrimary = String.fromEnvironment(
    'CLOUDINARY_API_HOST',
    defaultValue: '',
  );
  static const apiHostLegacy = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_API_HOST',
    defaultValue: '',
  );

  final String cloudName;
  final String uploadPreset;
  final String apiHost;

  const CloudinaryServiceConfig({
    required this.cloudName,
    required this.uploadPreset,
    required this.apiHost,
  });

  factory CloudinaryServiceConfig.resolve({
    String? cloudName,
    String? uploadPreset,
    String? apiHost,
  }) {
    return CloudinaryServiceConfig(
      cloudName:
          cloudName ??
          (cloudNamePrimary.isNotEmpty ? cloudNamePrimary : cloudNameLegacy),
      uploadPreset:
          uploadPreset ??
          (uploadPresetPrimary.isNotEmpty
              ? uploadPresetPrimary
              : uploadPresetLegacy),
      apiHost: _normalizeApiHost(
        apiHost ?? (apiHostPrimary.isNotEmpty ? apiHostPrimary : apiHostLegacy),
      ),
    );
  }

  List<String> candidateCloudNames() => {
    cloudName.trim(),
    cloudNamePrimary.trim(),
    cloudNameLegacy.trim(),
    'rentdone',
    'dmvogtrcg',
  }.where((value) => value.isNotEmpty).toList();
  List<String> candidateUploadPresets() => {
    uploadPreset.trim(),
    uploadPresetPrimary.trim(),
    uploadPresetLegacy.trim(),
    'rentdone_unsigned',
    'rentdoneapp',
  }.where((value) => value.isNotEmpty).toList();

  static String _normalizeApiHost(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'api.cloudinary.com';
    return trimmed.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
  }
}

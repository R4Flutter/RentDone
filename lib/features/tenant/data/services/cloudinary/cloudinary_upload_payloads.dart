List<Map<String, String>> cloudinaryUploadPayloads(
  String uploadPreset,
  String folder,
  String publicId,
) => [
  {
    'upload_preset': uploadPreset,
    'folder': folder,
    'public_id': publicId,
    'return_delete_token': 'true',
  },
  {'upload_preset': uploadPreset, 'folder': folder, 'public_id': publicId},
  {'upload_preset': uploadPreset, 'folder': folder},
];

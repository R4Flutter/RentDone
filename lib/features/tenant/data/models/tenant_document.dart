import 'package:cloud_firestore/cloud_firestore.dart';

class TenantDocument {
  final String id;
  final String fileUrl;
  final String? thumbnailUrl;
  final String fileType;
  final DateTime? uploadedAt;
  final String description;
  final String publicId;
  final int fileSizeBytes;
  final String storagePath;
  final String? thumbnailStoragePath;
  final int? thumbnailSizeBytes;

  const TenantDocument({
    required this.id,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.fileType,
    required this.uploadedAt,
    required this.description,
    required this.publicId,
    this.fileSizeBytes = 0,
    this.storagePath = '',
    this.thumbnailStoragePath,
    this.thumbnailSizeBytes,
  });

  factory TenantDocument.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final resolvedFileUrl =
        data['originalUrl'] as String? ?? data['fileUrl'] as String? ?? '';
    final resolvedStoragePath =
        data['storagePath'] as String? ?? data['publicId'] as String? ?? '';

    return TenantDocument(
      id: doc.id,
      fileUrl: resolvedFileUrl,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      fileType: data['fileType'] as String? ?? 'other',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      description: data['description'] as String? ?? '',
      publicId: resolvedStoragePath,
      fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt() ?? 0,
      storagePath: resolvedStoragePath,
      thumbnailStoragePath: data['thumbnailStoragePath'] as String?,
      thumbnailSizeBytes: (data['thumbnailSizeBytes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileUrl': fileUrl,
      'originalUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileType': fileType,
      'uploadedAt': FieldValue.serverTimestamp(),
      'description': description,
      'publicId': storagePath.isNotEmpty ? storagePath : publicId,
      'storagePath': storagePath.isNotEmpty ? storagePath : publicId,
      'thumbnailStoragePath': thumbnailStoragePath,
      'fileSizeBytes': fileSizeBytes,
      if (thumbnailSizeBytes != null) 'thumbnailSizeBytes': thumbnailSizeBytes,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class TenantDocument {
  final String id;
  final String fileUrl;
  final String fileType;
  final DateTime? uploadedAt;
  final String description;
  final String publicId;
  final int fileSizeBytes;
  final String? deleteToken;

  const TenantDocument({
    required this.id,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedAt,
    required this.description,
    required this.publicId,
    this.fileSizeBytes = 0,
    this.deleteToken,
  });

  factory TenantDocument.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return TenantDocument(
      id: doc.id,
      fileUrl: data['fileUrl'] as String? ?? '',
      fileType: data['fileType'] as String? ?? 'other',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      description: data['description'] as String? ?? '',
      publicId: data['publicId'] as String? ?? '',
      fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt() ?? 0,
      deleteToken: data['deleteToken'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileUrl': fileUrl,
      'fileType': fileType,
      'uploadedAt': FieldValue.serverTimestamp(),
      'description': description,
      'publicId': publicId,
      'fileSizeBytes': fileSizeBytes,
      if (deleteToken != null && deleteToken!.isNotEmpty)
        'deleteToken': deleteToken,
    };
  }
}

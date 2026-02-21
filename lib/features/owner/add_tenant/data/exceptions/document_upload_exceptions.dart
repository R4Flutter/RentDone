class DocumentUploadException implements Exception {
  final String message;

  const DocumentUploadException(this.message);

  @override
  String toString() => message;
}

class CloudinaryUploadException extends DocumentUploadException {
  final int? statusCode;

  const CloudinaryUploadException(super.message, {this.statusCode});
}

class FirestoreSaveException extends DocumentUploadException {
  const FirestoreSaveException(super.message);
}

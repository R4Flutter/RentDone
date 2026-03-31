class DocumentUploadException implements Exception {
  final String message;

  const DocumentUploadException(this.message);

  @override
  String toString() => message;
}

class StorageUploadException extends DocumentUploadException {
  final int? statusCode;

  const StorageUploadException(super.message, {this.statusCode});
}

class FirestoreSaveException extends DocumentUploadException {
  const FirestoreSaveException(super.message);
}

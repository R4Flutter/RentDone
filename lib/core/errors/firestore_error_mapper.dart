import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/core/errors/app_exception.dart';

/// Maps Firestore-specific error codes to user-friendly [AppException] types.
///
/// Usage:
/// ```dart
/// try {
///   await firestore.collection('x').doc('y').get();
/// } on FirebaseException catch (e, st) {
///   throw FirestoreErrorMapper.map(e, stackTrace: st);
/// }
/// ```
class FirestoreErrorMapper {
  FirestoreErrorMapper._();

  /// Converts a [FirebaseException] (or any [Object]) thrown by Firestore
  /// into the appropriate [AppException] subtype.
  static AppException map(
    Object error, {
    StackTrace? stackTrace,
    String? entityLabel,
  }) {
    final label = entityLabel ?? 'Record';

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return StorageException.permissionDenied();

        case 'not-found':
          return StorageException.notFound(label);

        case 'already-exists':
          return StorageException(
            message: '$label already exists.',
            code: 'STORAGE_ALREADY_EXISTS',
            originalError: error,
            stackTrace: stackTrace,
          );

        case 'resource-exhausted':
          return StorageException.quotaExceeded();

        case 'unavailable':
          return const NetworkException(
            message: 'Service temporarily unavailable. Retrying…',
            code: 'FIRESTORE_UNAVAILABLE',
          );

        case 'deadline-exceeded':
          return NetworkException.timeout();

        case 'cancelled':
          return const StorageException(
            message: 'Operation was cancelled.',
            code: 'STORAGE_CANCELLED',
          );

        case 'data-loss':
          return StorageException(
            message: 'Data integrity error. Please contact support.',
            code: 'STORAGE_DATA_LOSS',
            originalError: error,
            stackTrace: stackTrace,
          );

        case 'unauthenticated':
          return AuthException.sessionExpired();

        default:
          return StorageException(
            message: 'Something went wrong. Please try again.',
            code: 'FIRESTORE_${error.code}',
            originalError: error,
            stackTrace: stackTrace,
          );
      }
    }

    // Fallback for non-Firebase errors
    if (error is TypeError) {
      return StorageException(
        message: 'Data format error. Please refresh and try again.',
        code: 'STORAGE_TYPE_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return StorageException(
      message: 'An unexpected error occurred. Please try again.',
      code: 'STORAGE_UNKNOWN',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

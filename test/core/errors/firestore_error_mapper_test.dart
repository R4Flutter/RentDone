import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentdone/core/errors/app_exception.dart';
import 'package:rentdone/core/errors/firestore_error_mapper.dart';

/// Minimal stub so we can construct FirebaseException in tests.
/// The real class requires a plugin string.
FirebaseException _firestoreException(String code) {
  return FirebaseException(plugin: 'cloud_firestore', code: code);
}

void main() {
  group('FirestoreErrorMapper.map()', () {
    test('maps permission-denied to StorageException.permissionDenied', () {
      final result = FirestoreErrorMapper.map(_firestoreException('permission-denied'));
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_PERMISSION_DENIED');
    });

    test('maps not-found to StorageException.notFound', () {
      final result = FirestoreErrorMapper.map(
        _firestoreException('not-found'),
        entityLabel: 'Payment',
      );
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_NOT_FOUND');
      expect(result.message, 'Payment not found.');
    });

    test('maps already-exists to StorageException', () {
      final result = FirestoreErrorMapper.map(
        _firestoreException('already-exists'),
        entityLabel: 'Tenant',
      );
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_ALREADY_EXISTS');
      expect(result.message, contains('Tenant'));
    });

    test('maps resource-exhausted to StorageException.quotaExceeded', () {
      final result = FirestoreErrorMapper.map(_firestoreException('resource-exhausted'));
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_QUOTA_EXCEEDED');
    });

    test('maps unavailable to NetworkException', () {
      final result = FirestoreErrorMapper.map(_firestoreException('unavailable'));
      expect(result, isA<NetworkException>());
      expect(result.code, 'FIRESTORE_UNAVAILABLE');
    });

    test('maps deadline-exceeded to NetworkException.timeout', () {
      final result = FirestoreErrorMapper.map(_firestoreException('deadline-exceeded'));
      expect(result, isA<NetworkException>());
      expect(result.code, 'NETWORK_TIMEOUT');
    });

    test('maps cancelled to StorageException', () {
      final result = FirestoreErrorMapper.map(_firestoreException('cancelled'));
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_CANCELLED');
    });

    test('maps data-loss to StorageException', () {
      final result = FirestoreErrorMapper.map(_firestoreException('data-loss'));
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_DATA_LOSS');
    });

    test('maps unauthenticated to AuthException.sessionExpired', () {
      final result = FirestoreErrorMapper.map(_firestoreException('unauthenticated'));
      expect(result, isA<AuthException>());
      expect(result.code, 'AUTH_SESSION_EXPIRED');
    });

    test('maps unknown code to generic StorageException', () {
      final result = FirestoreErrorMapper.map(_firestoreException('internal'));
      expect(result, isA<StorageException>());
      expect(result.code, 'FIRESTORE_internal');
    });

    test('maps TypeError to StorageException with TYPE_ERROR code', () {
      final result = FirestoreErrorMapper.map(TypeError());
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_TYPE_ERROR');
    });

    test('maps unknown Object to StorageException with UNKNOWN code', () {
      final result = FirestoreErrorMapper.map('random string error');
      expect(result, isA<StorageException>());
      expect(result.code, 'STORAGE_UNKNOWN');
    });

    test('uses fallback entity label "Record" when none provided', () {
      final result = FirestoreErrorMapper.map(_firestoreException('not-found'));
      expect(result.message, 'Record not found.');
    });
  });
}

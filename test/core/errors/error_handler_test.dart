import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentdone/core/errors/app_exception.dart';
import 'package:rentdone/core/errors/error_handler.dart';

void main() {
  group('ErrorHandler.wrap()', () {
    test('returns AppException unchanged', () {
      const input = PaymentProcessException(
        message: 'Test payment error',
        code: 'PAYMENT_TEST',
      );
      final result = ErrorHandler.wrap(input);
      expect(result, same(input));
    });

    test('maps ArgumentError to ValidationException', () {
      final result = ErrorHandler.wrap(ArgumentError('bad input'));
      expect(result, isA<ValidationException>());
      expect(result.code, 'VALIDATION_ARGUMENT');
    });

    test('maps FormatException to ValidationException', () {
      final result = ErrorHandler.wrap(const FormatException('bad format'));
      expect(result, isA<ValidationException>());
      expect(result.code, 'VALIDATION_FORMAT');
    });

    test('maps StateError to StorageException', () {
      final result = ErrorHandler.wrap(StateError('not found'));
      expect(result, isA<StorageException>());
      expect(result.code, 'STATE_ERROR');
      expect(result.message, 'not found');
    });

    test('maps SocketException to NetworkException via NetworkErrorHandler', () {
      final result = ErrorHandler.wrap(
        const SocketException('connection refused'),
      );
      expect(result, isA<NetworkException>());
    });

    test('maps TimeoutException to NetworkException', () {
      final result = ErrorHandler.wrap(TimeoutException('timed out'));
      expect(result, isA<NetworkException>());
    });

    test('maps unknown Exception to StorageException with UNKNOWN_ERROR', () {
      final result = ErrorHandler.wrap(Exception('something random'));
      expect(result, isA<StorageException>());
      expect(result.code, 'UNKNOWN_ERROR');
      expect(result.message, 'Something went wrong. Please try again.');
    });
  });

  group('ErrorHandler.userMessage()', () {
    test('returns message from AppException directly', () {
      const ex = AuthException(message: 'Please sign in');
      expect(ErrorHandler.userMessage(ex), 'Please sign in');
    });

    test('converts unknown error into fallback message', () {
      final msg = ErrorHandler.userMessage(Exception('???'));
      expect(msg, 'Something went wrong. Please try again.');
    });
  });
}

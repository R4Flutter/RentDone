import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rentdone/core/errors/app_exception.dart';
import 'package:rentdone/core/errors/network_error_handler.dart';

void main() {
  group('NetworkErrorHandler.isNetworkError()', () {
    test('recognizes SocketException', () {
      expect(
        NetworkErrorHandler.isNetworkError(const SocketException('fail')),
        isTrue,
      );
    });

    test('recognizes TimeoutException', () {
      expect(
        NetworkErrorHandler.isNetworkError(TimeoutException('slow')),
        isTrue,
      );
    });

    test('recognizes HttpException', () {
      expect(
        NetworkErrorHandler.isNetworkError(const HttpException('bad')),
        isTrue,
      );
    });

    test('recognizes error message containing "connection refused"', () {
      expect(
        NetworkErrorHandler.isNetworkError(Exception('connection refused')),
        isTrue,
      );
    });

    test('recognizes error message containing "timed out"', () {
      expect(
        NetworkErrorHandler.isNetworkError(Exception('request timed out')),
        isTrue,
      );
    });

    test('returns false for unrelated errors', () {
      expect(
        NetworkErrorHandler.isNetworkError(Exception('null pointer')),
        isFalse,
      );
    });
  });

  group('NetworkErrorHandler.tryWrap()', () {
    test('wraps SocketException into NetworkException', () {
      final result = NetworkErrorHandler.tryWrap(
        const SocketException('test'),
      );
      expect(result, isA<NetworkException>());
      expect(result!.code, 'NETWORK_SOCKET_ERROR');
    });

    test('wraps TimeoutException into NetworkException.timeout', () {
      final result = NetworkErrorHandler.tryWrap(TimeoutException('slow'));
      expect(result, isA<NetworkException>());
      expect(result!.code, 'NETWORK_TIMEOUT');
    });

    test('wraps HttpException into NetworkException', () {
      final result = NetworkErrorHandler.tryWrap(
        const HttpException('bad gateway'),
      );
      expect(result, isA<NetworkException>());
      expect(result!.code, 'NETWORK_HTTP_ERROR');
      expect(result.message, contains('bad gateway'));
    });

    test('wraps generic network-like error', () {
      final result = NetworkErrorHandler.tryWrap(
        Exception('host lookup failed'),
      );
      expect(result, isA<NetworkException>());
      expect(result!.code, 'NETWORK_GENERIC');
    });

    test('returns null for non-network errors', () {
      final result = NetworkErrorHandler.tryWrap(Exception('file missing'));
      expect(result, isNull);
    });
  });
}

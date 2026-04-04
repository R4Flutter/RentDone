import 'dart:async';
import 'dart:io';

import 'package:rentdone/core/errors/app_exception.dart';

/// Detects and wraps common network-related errors (SocketException,
/// TimeoutException, etc.) into the unified [AppException] hierarchy.
class NetworkErrorHandler {
  NetworkErrorHandler._();

  /// Returns `true` if [error] looks like a network connectivity issue.
  static bool isNetworkError(Object error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;

    final message = error.toString().toLowerCase();
    return message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection refused') ||
        message.contains('host lookup') ||
        message.contains('timed out') ||
        message.contains('unreachable');
  }

  /// Wraps a network-like error into a [NetworkException].
  ///
  /// If [error] does not look like a network issue, returns `null`
  /// so the caller can fall back to a different mapper.
  static NetworkException? tryWrap(Object error, {StackTrace? stackTrace}) {
    if (error is SocketException) {
      return const NetworkException(
        message: 'Cannot reach server. Check your internet connection.',
        code: 'NETWORK_SOCKET_ERROR',
      );
    }
    if (error is TimeoutException) {
      return NetworkException.timeout();
    }
    if (error is HttpException) {
      return NetworkException(
        message: 'Connection error: ${error.message}',
        code: 'NETWORK_HTTP_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (isNetworkError(error)) {
      return NetworkException(
        message: 'Network error. Please check your connection and try again.',
        code: 'NETWORK_GENERIC',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return null;
  }
}

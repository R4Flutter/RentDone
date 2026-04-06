import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:rentdone/core/errors/app_exception.dart';
import 'package:rentdone/core/errors/firestore_error_mapper.dart';
import 'package:rentdone/core/errors/network_error_handler.dart';
import 'package:rentdone/core/logging/app_logger.dart';

/// Centralized error handler that converts arbitrary errors into
/// user-friendly messages and optionally shows them via SnackBar.
///
/// Usage in a widget / provider:
/// ```dart
/// try {
///   await someFirestoreCall();
/// } catch (e, st) {
///   ErrorHandler.handle(e, stackTrace: st, context: context);
/// }
/// ```
class ErrorHandler {
  ErrorHandler._();

  // ---------------------------------------------------------------
  // Core API
  // ---------------------------------------------------------------

  /// Converts [error] into an [AppException], logs it, and optionally
  /// shows a SnackBar if [context] is provided and mounted.
  static AppException handle(
    Object error, {
    StackTrace? stackTrace,
    BuildContext? context,
    String? entityLabel,
    bool showSnackBar = true,
    String tag = 'ErrorHandler',
  }) {
    final appException = _toAppException(
      error,
      stackTrace: stackTrace,
      entityLabel: entityLabel,
    );

    // Log to Crashlytics-friendly logger
    AppLogger.error(
      appException.toString(),
      error: appException.originalError ?? appException,
      stackTrace: stackTrace ?? appException.stackTrace,
      tag: tag,
    );

    // Show SnackBar if context is valid
    if (showSnackBar && context != null && context.mounted) {
      _showErrorSnackBar(context, appException);
    }

    return appException;
  }

  /// Converts [error] into an [AppException] without showing any UI.
  /// Useful in data layers where you have no BuildContext.
  static AppException wrap(
    Object error, {
    StackTrace? stackTrace,
    String? entityLabel,
  }) {
    return _toAppException(
      error,
      stackTrace: stackTrace,
      entityLabel: entityLabel,
    );
  }

  /// Returns the user-friendly message for any error.
  static String userMessage(Object error) {
    if (error is AppException) return error.message;
    return _toAppException(error).message;
  }

  // ---------------------------------------------------------------
  // Internal mapping
  // ---------------------------------------------------------------

  static AppException _toAppException(
    Object error, {
    StackTrace? stackTrace,
    String? entityLabel,
  }) {
    // Already mapped
    if (error is AppException) return error;

    // Firebase Auth
    if (error is FirebaseAuthException) {
      return AuthException.fromFirebase(error.code, error);
    }

    // Firestore / Firebase
    if (error is FirebaseException) {
      return FirestoreErrorMapper.map(
        error,
        stackTrace: stackTrace,
        entityLabel: entityLabel,
      );
    }

    // Network
    final networkException = NetworkErrorHandler.tryWrap(
      error,
      stackTrace: stackTrace,
    );
    if (networkException != null) return networkException;

    // StateError (often thrown by repos for "not found" etc.)
    if (error is StateError) {
      return StorageException(
        message: error.message,
        code: 'STATE_ERROR',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // ArgumentError / FormatException
    if (error is ArgumentError) {
      return ValidationException(
        message: error.message?.toString() ?? 'Invalid input.',
        code: 'VALIDATION_ARGUMENT',
      );
    }
    if (error is FormatException) {
      return ValidationException(
        message: error.message,
        code: 'VALIDATION_FORMAT',
      );
    }

    // Catch-all
    return StorageException(
      message: 'Something went wrong. Please try again.',
      code: 'UNKNOWN_ERROR',
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  // ---------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------

  static void _showErrorSnackBar(BuildContext context, AppException ex) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _iconForCode(ex.code),
              color: isDark ? Colors.white70 : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ex.message,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _colorForCode(ex.code, isDark),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  static IconData _iconForCode(String code) {
    if (code.startsWith('AUTH_')) return Icons.lock_outline;
    if (code.startsWith('NETWORK_')) return Icons.wifi_off_rounded;
    if (code.startsWith('PAYMENT_')) return Icons.payment;
    if (code.startsWith('VALIDATION_')) return Icons.warning_amber_rounded;
    if (code.startsWith('FEATURE_')) return Icons.star_outline;
    return Icons.error_outline;
  }

  static Color _colorForCode(String code, bool isDark) {
    if (code.contains('CANCELLED')) {
      return isDark ? const Color(0xFF374151) : const Color(0xFF6B7280);
    }
    if (code.startsWith('NETWORK_')) {
      return isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B);
    }
    if (code.startsWith('FEATURE_')) {
      return isDark ? const Color(0xFF1E3A5F) : const Color(0xFF3B82F6);
    }
    return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEF4444);
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Logging levels for the application
enum LogLevel {
  debug, // Development only
  info, // Minimal production logs
  warning, // Warnings and alerts
  error, // Errors and exceptions
}

/// Centralized logging utility for the application
/// Ensures consistent logging across the app with environment awareness
class AppLogger {
  static const String _tag = 'RentDone';

  /// Whether to enable logging (kDebugMode or env override)
  static bool _loggingEnabled = kDebugMode;

  /// Minimum log level for production
  static const LogLevel _productionMinLevel = LogLevel.error;

  /// Enable/disable logging programmatically (e.g., for feature flags)
  static void setLoggingEnabled(bool enabled) {
    _loggingEnabled = enabled;
  }

  /// Log debug message (development only)
  /// In production: NO-OP to avoid log spam
  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode || !_loggingEnabled) return;

    _log(
      level: LogLevel.debug,
      message: message,
      tag: tag ?? _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log info message (minimal production use)
  /// Reserved for important state changes or milestones
  static void info(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_shouldLog(LogLevel.info)) return;

    _log(
      level: LogLevel.info,
      message: message,
      tag: tag ?? _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log warning message (both debug and production)
  /// Use for recoverable issues and warnings
  static void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_shouldLog(LogLevel.warning)) return;

    _log(
      level: LogLevel.warning,
      message: message,
      tag: tag ?? _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log error message (both debug and production)
  /// Primary production logging - only errors make it to production
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: LogLevel.error,
      message: message,
      tag: tag ?? _tag,
      error: error,
      stackTrace: stackTrace,
    );

    // Send to Crashlytics in production
    _recordToCrashlytics(
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log exception with optional context
  /// Automatically sent to Crashlytics
  static void exception(
    Object exception, {
    StackTrace? stackTrace,
    String? context,
    String? tag,
  }) {
    final message = context ?? exception.toString();

    _log(
      level: LogLevel.error,
      message: message,
      tag: tag ?? _tag,
      error: exception,
      stackTrace: stackTrace,
    );

    // Always record exceptions to Crashlytics
    _recordToCrashlytics(
      message: message,
      error: exception,
      stackTrace: stackTrace,
    );
  }

  /// Check if a log level should be recorded
  static bool _shouldLog(LogLevel level) {
    if (!_loggingEnabled) return false;

    // In production, only log errors and warnings
    if (!kDebugMode && level.index < _productionMinLevel.index) {
      return false;
    }

    return true;
  }

  /// Internal logging implementation
  static void _log({
    required LogLevel level,
    required String message,
    required String tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = '[$tag] ${level.name.toUpperCase()}';
    final fullMessage = '$prefix: $message';

    // Print to console in debug mode only
    if (kDebugMode) {
      debugPrint(fullMessage);
      if (error != null) {
        debugPrint('Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack: $stackTrace');
      }
    }
  }

  /// Record error to Firebase Crashlytics
  static void _recordToCrashlytics({
    required String message,
    Object? error,
    StackTrace? stackTrace,
  }) {
    try {
      if (!kDebugMode) {
        // Only in production
        if (error != null && stackTrace != null) {
          FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: message,
            fatal: false,
          );
        } else if (error != null) {
          FirebaseCrashlytics.instance.recordError(
            error,
            StackTrace.current,
            reason: message,
            fatal: false,
          );
        } else {
          // Log as breadcrumb if no exception
          FirebaseCrashlytics.instance.log(message);
        }
      }
    } catch (e) {
      // Silently fail if Crashlytics not initialized
      // Don't let logging errors crash the app
    }
  }

  /// Set custom Crashlytics key for additional context
  /// Use sparingly - only for important debugging info
  static void setCustomKey(String key, Object value) {
    try {
      if (!kDebugMode) {
        // Production only
        FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      }
    } catch (e) {
      // Silently fail if Crashlytics not initialized
    }
  }

  /// Set user ID in Crashlytics for attribution
  /// Note: setUserID functionality may vary by Firebase Crashlytics version
  static void setUserId(String userId) {
    try {
      if (!kDebugMode) {
        // Production only
        // Firebase Crashlytics user ID setting - implementation varies by version
        // Uncomment when available in your Firebase SDK version:
        // await FirebaseCrashlytics.instance.setUserID(userId);
      }
    } catch (e) {
      // Silently fail if method not available in this version
    }
  }
}

/// Extension methods for easier logging
extension AppLoggerExtension on Object {
  /// Log this object as debug (useful for tracing flow)
  void logDebug([String prefix = 'Debug']) {
    if (kDebugMode) {
      AppLogger.debug('$prefix: $this');
    }
  }

  /// Log this object as error
  void logError([String prefix = 'Error']) {
    AppLogger.error('$prefix: $this');
  }
}

/// Base exception hierarchy for the entire RentDone application.
///
/// All app-level exceptions should extend [AppException] so that
/// the global [ErrorHandler] can present uniform, user-friendly
/// messages while still preserving the underlying cause for logging.
library;

// ---------------------------------------------------------------------------
// Abstract base
// ---------------------------------------------------------------------------

/// Root of the app exception hierarchy.
///
/// Every domain-specific exception inherits from this to ensure:
///   • Consistent `toString()` output
///   • A machine-readable [code] for analytics / Crashlytics
///   • Optional [originalError] and [stackTrace] for debugging
abstract class AppException implements Exception {
  const AppException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  /// Human-readable message suitable for display in SnackBars / dialogs.
  final String message;

  /// Machine-readable error code (e.g. `AUTH_NOT_VERIFIED`).
  final String code;

  /// The underlying error / exception, if any.
  final Object? originalError;

  /// Stack trace from the original error site, if available.
  final StackTrace? stackTrace;

  @override
  String toString() => '[$code] $message';
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory AuthException.unauthenticated() => const AuthException(
    message: 'Please sign in to continue.',
    code: 'AUTH_UNAUTHENTICATED',
  );

  factory AuthException.emailNotVerified() => const AuthException(
    message: 'Please verify your email address before continuing.',
    code: 'AUTH_EMAIL_NOT_VERIFIED',
  );

  factory AuthException.invalidCredentials() => const AuthException(
    message: 'Invalid email or password. Please try again.',
    code: 'AUTH_INVALID_CREDENTIALS',
  );

  factory AuthException.accountDisabled() => const AuthException(
    message: 'Your account has been disabled. Contact support.',
    code: 'AUTH_ACCOUNT_DISABLED',
  );

  factory AuthException.tooManyRequests() => const AuthException(
    message: 'Too many attempts. Please wait a moment and try again.',
    code: 'AUTH_TOO_MANY_REQUESTS',
  );

  factory AuthException.sessionExpired() => const AuthException(
    message: 'Your session has expired. Please sign in again.',
    code: 'AUTH_SESSION_EXPIRED',
  );

  factory AuthException.fromFirebase(String firebaseCode, [Object? error]) {
    switch (firebaseCode) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return AuthException.invalidCredentials();
      case 'user-disabled':
        return AuthException.accountDisabled();
      case 'too-many-requests':
        return AuthException.tooManyRequests();
      case 'network-request-failed':
        return AuthException(
          message: 'Network error. Check your connection.',
          code: 'AUTH_NETWORK_ERROR',
          originalError: error,
        );
      default:
        return AuthException(
          message: 'Authentication error. Please try again.',
          code: 'AUTH_FIREBASE_$firebaseCode',
          originalError: error,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Network / Connectivity
// ---------------------------------------------------------------------------

class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory NetworkException.noConnection() => const NetworkException(
    message: 'No internet connection. Please check your network.',
    code: 'NETWORK_NO_CONNECTION',
  );

  factory NetworkException.timeout() => const NetworkException(
    message: 'Request timed out. Please try again.',
    code: 'NETWORK_TIMEOUT',
  );

  factory NetworkException.serverError([int? statusCode]) => NetworkException(
    message:
        'Server error${statusCode != null ? ' ($statusCode)' : ''}. '
        'Please try again later.',
    code: 'NETWORK_SERVER_ERROR',
  );
}

// ---------------------------------------------------------------------------
// Firestore / Storage
// ---------------------------------------------------------------------------

class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory StorageException.notFound(String entity) => StorageException(
    message: '$entity not found.',
    code: 'STORAGE_NOT_FOUND',
  );

  factory StorageException.permissionDenied() => const StorageException(
    message: 'Permission denied. You cannot access this resource.',
    code: 'STORAGE_PERMISSION_DENIED',
  );

  factory StorageException.quotaExceeded() => const StorageException(
    message: 'Storage quota exceeded. Please contact support.',
    code: 'STORAGE_QUOTA_EXCEEDED',
  );

  factory StorageException.writeFailed([Object? error]) => StorageException(
    message: 'Failed to save data. Please try again.',
    code: 'STORAGE_WRITE_FAILED',
    originalError: error,
  );

  factory StorageException.readFailed([Object? error]) => StorageException(
    message: 'Failed to load data. Please refresh.',
    code: 'STORAGE_READ_FAILED',
    originalError: error,
  );
}

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------

class PaymentProcessException extends AppException {
  const PaymentProcessException({
    required super.message,
    super.code = 'PAYMENT_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory PaymentProcessException.invalidAmount(String reason) =>
      PaymentProcessException(message: reason, code: 'PAYMENT_INVALID_AMOUNT');

  factory PaymentProcessException.gatewayFailure([Object? error]) =>
      PaymentProcessException(
        message: 'Payment could not be processed. Please try again.',
        code: 'PAYMENT_GATEWAY_FAILURE',
        originalError: error,
      );

  factory PaymentProcessException.cancelled() => const PaymentProcessException(
    message: 'Payment was cancelled.',
    code: 'PAYMENT_CANCELLED',
  );

  factory PaymentProcessException.rateLimited() =>
      const PaymentProcessException(
        message: 'Too many payment attempts. Please wait and try again.',
        code: 'PAYMENT_RATE_LIMITED',
      );

  factory PaymentProcessException.maintenanceMode() =>
      const PaymentProcessException(
        message: 'Payments are temporarily unavailable. Please try later.',
        code: 'PAYMENT_MAINTENANCE',
      );
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.field,
  });

  /// The specific form field that failed validation, if applicable.
  final String? field;

  factory ValidationException.required(String fieldName) => ValidationException(
    message: '$fieldName is required.',
    code: 'VALIDATION_REQUIRED',
    field: fieldName,
  );

  factory ValidationException.invalidFormat(String fieldName, String hint) =>
      ValidationException(
        message: 'Invalid $fieldName. $hint',
        code: 'VALIDATION_FORMAT',
        field: fieldName,
      );
}

// ---------------------------------------------------------------------------
// Feature-gated / Subscription
// ---------------------------------------------------------------------------

class FeatureGatedException extends AppException {
  const FeatureGatedException({
    required super.message,
    super.code = 'FEATURE_GATED',
  });

  factory FeatureGatedException.tenantLimit() => const FeatureGatedException(
    message: 'Tenant limit reached. Upgrade your plan to add more.',
    code: 'FEATURE_TENANT_LIMIT',
  );

  factory FeatureGatedException.subscriptionRequired() =>
      const FeatureGatedException(
        message: 'This feature requires an active subscription.',
        code: 'FEATURE_SUBSCRIPTION_REQUIRED',
      );
}

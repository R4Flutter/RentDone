/// Custom exception types for payment operations
/// Enables granular error handling and better user messaging
library;

abstract class PaymentException implements Exception {
  final String message;
  final String? code;
  final Exception? originalException;

  PaymentException({required this.message, this.code, this.originalException});

  @override
  String toString() => message;
}

/// Thrown when payment amount validation fails
class InvalidPaymentAmountException extends PaymentException {
  InvalidPaymentAmountException({required super.message, super.code = 'INVALID_AMOUNT'});

  factory InvalidPaymentAmountException.zero() => InvalidPaymentAmountException(
    message: 'Payment amount must be greater than zero',
  );

  factory InvalidPaymentAmountException.negative() =>
      InvalidPaymentAmountException(
        message: 'Payment amount cannot be negative',
      );

  factory InvalidPaymentAmountException.exceedsRemaining(int remaining) =>
      InvalidPaymentAmountException(
        message:
            'Installment amount cannot exceed remaining amount (Rs $remaining)',
      );

  factory InvalidPaymentAmountException.exceedsBase(int base) =>
      InvalidPaymentAmountException(
        message: 'Payment amount cannot exceed base rent (Rs $base)',
      );

  factory InvalidPaymentAmountException.custom(String reason) =>
      InvalidPaymentAmountException(message: reason);
}

/// Thrown when payment status is invalid or transition not allowed
class InvalidPaymentStatusException extends PaymentException {
  InvalidPaymentStatusException({required super.message, super.code = 'INVALID_STATUS'});

  factory InvalidPaymentStatusException.invalidStatus(
    String status,
  ) => InvalidPaymentStatusException(
    message:
        'Invalid payment status: "$status". Must be one of: paid, partial, unpaid',
  );

  factory InvalidPaymentStatusException.invalidTransition(
    String current,
    String requested,
  ) => InvalidPaymentStatusException(
    message: 'Cannot transition payment status from "$current" to "$requested"',
  );
}

/// Thrown when Firestore operation fails
class PaymentStorageException extends PaymentException {
  PaymentStorageException({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.originalException,
  });

  factory PaymentStorageException.write(Exception? e) =>
      PaymentStorageException(
        message: 'Failed to save payment to database. Please try again.',
        code: 'WRITE_FAILED',
        originalException: e,
      );

  factory PaymentStorageException.read(Exception? e) => PaymentStorageException(
    message: 'Failed to fetch payment history. Please refresh.',
    code: 'READ_FAILED',
    originalException: e,
  );

  factory PaymentStorageException.update(Exception? e) =>
      PaymentStorageException(
        message: 'Failed to update payment status. Please try again.',
        code: 'UPDATE_FAILED',
        originalException: e,
      );

  factory PaymentStorageException.networkError() => PaymentStorageException(
    message: 'Network error. Check your connection and try again.',
    code: 'NETWORK_ERROR',
  );

  factory PaymentStorageException.permissionDenied() => PaymentStorageException(
    message: 'Permission denied. You cannot modify this payment.',
    code: 'PERMISSION_DENIED',
  );

  factory PaymentStorageException.notFound() => PaymentStorageException(
    message: 'Payment record not found.',
    code: 'NOT_FOUND',
  );

  factory PaymentStorageException.custom(String message) =>
      PaymentStorageException(message: message, code: 'CUSTOM_ERROR');
}

/// Thrown when payment gateway (Razorpay) operation fails
class PaymentGatewayException extends PaymentException {
  PaymentGatewayException({
    required super.message,
    super.code = 'GATEWAY_ERROR',
    super.originalException,
  });

  factory PaymentGatewayException.checkoutFailed(Exception? e) =>
      PaymentGatewayException(
        message: 'Payment checkout failed. Please try again.',
        code: 'CHECKOUT_FAILED',
        originalException: e,
      );

  factory PaymentGatewayException.timeout() => PaymentGatewayException(
    message: 'Payment request timeout. Please try again.',
    code: 'TIMEOUT',
  );

  factory PaymentGatewayException.userCancelled() => PaymentGatewayException(
    message: 'Payment cancelled by user.',
    code: 'CANCELLED',
  );

  factory PaymentGatewayException.insufficientFunds() =>
      PaymentGatewayException(
        message: 'Insufficient balance. Please try another payment method.',
        code: 'INSUFFICIENT_FUNDS',
      );

  factory PaymentGatewayException.invalidCard() => PaymentGatewayException(
    message: 'Card transaction failed. Please try another method.',
    code: 'INVALID_CARD',
  );
}

/// Thrown when tenant/property context is invalid
class InvalidPaymentContextException extends PaymentException {
  InvalidPaymentContextException({required super.message, super.code = 'INVALID_CONTEXT'});

  factory InvalidPaymentContextException.noAuth() =>
      InvalidPaymentContextException(
        message: 'Authentication failed. Please log in again.',
      );

  factory InvalidPaymentContextException.tenantNotFound() =>
      InvalidPaymentContextException(message: 'Tenant record not found.');

  factory InvalidPaymentContextException.propertyNotFound() =>
      InvalidPaymentContextException(message: 'Property record not found.');

  factory InvalidPaymentContextException.noOwnership() =>
      InvalidPaymentContextException(
        message: 'You do not have permission to modify this payment.',
      );
}

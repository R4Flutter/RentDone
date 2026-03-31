abstract class PaymentFailure implements Exception {
  final String code;
  final String message;

  const PaymentFailure(this.code, this.message);

  @override
  String toString() => message;
}

class NetworkFailure extends PaymentFailure {
  const NetworkFailure([String message = 'Network unavailable'])
    : super('network', message);
}

class UnauthorizedFailure extends PaymentFailure {
  const UnauthorizedFailure([String message = 'Authentication required'])
    : super('unauthorized', message);
}

class ValidationFailure extends PaymentFailure {
  const ValidationFailure([String message = 'Invalid request'])
    : super('validation', message);
}

class NotFoundFailure extends PaymentFailure {
  const NotFoundFailure([String message = 'Resource not found'])
    : super('not_found', message);
}

class ServerFailure extends PaymentFailure {
  const ServerFailure([String message = 'Server error'])
    : super('server', message);
}

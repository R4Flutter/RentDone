/// Security and authorization exception classes
/// Used throughout the app for permission and authentication failures
library;

/// Thrown when user tries to access or modify data they don't own
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Thrown when user's role doesn't grant required permission
class InsufficientPermissionException implements Exception {
  final String message;
  final String? requiredRole;
  final String? userRole;

  InsufficientPermissionException({
    required this.message,
    this.requiredRole,
    this.userRole,
  });

  @override
  String toString() =>
      'InsufficientPermissionException: $message'
      '${requiredRole != null ? ' (requires $requiredRole, got $userRole)' : ''}';
}

/// Thrown when user tries to exceed quota/limit (e.g., too many tenants)
class QuotaExceededException implements Exception {
  final String message;
  final int? currentCount;
  final int? maxAllowed;

  QuotaExceededException({
    required this.message,
    this.currentCount,
    this.maxAllowed,
  });

  @override
  String toString() =>
      'QuotaExceededException: $message'
      '${currentCount != null && maxAllowed != null ? ' ($currentCount/$maxAllowed)' : ''}';
}

/// Thrown when requested resource doesn't exist or user can't access it
class ResourceNotAccessibleException implements Exception {
  final String message;
  final String? resourceType;
  final String? resourceId;

  ResourceNotAccessibleException({
    required this.message,
    this.resourceType,
    this.resourceId,
  });

  @override
  String toString() =>
      'ResourceNotAccessibleException: $message'
      '${resourceType != null ? ' ($resourceType:$resourceId)' : ''}';
}

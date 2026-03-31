class AuthUser {
  final String uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? role;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool isProfileComplete;

  const AuthUser({
    required this.uid,
    this.name,
    this.email,
    this.phone,
    this.role,
    this.createdAt,
    this.lastLoginAt,
    this.isProfileComplete = false,
  });

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      uid: (map['uid'] as String?) ?? '',
      name: map['name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: map['role'] as String?,
      createdAt: _parseDate(map['createdAt']),
      lastLoginAt: _parseDate(map['lastLoginAt']),
      isProfileComplete: (map['isProfileComplete'] as bool?) ?? false,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

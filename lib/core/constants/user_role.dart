enum UserRole { tenant, owner }

extension UserRoleX on UserRole {
  String get value => name;

  String get label {
    switch (this) {
      case UserRole.tenant:
        return 'Tenant';
      case UserRole.owner:
        return 'Owner';
    }
  }

  static UserRole? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final role in UserRole.values) {
      if (role.name == normalized) {
        return role;
      }
    }
    return null;
  }
}

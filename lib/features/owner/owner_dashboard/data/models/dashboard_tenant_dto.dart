import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardTenantDto {
  final String id;
  final String fullName;
  final DateTime createdAt;

  const DashboardTenantDto({
    required this.id,
    required this.fullName,
    required this.createdAt,
  });

  factory DashboardTenantDto.fromMap(String id, Map<String, dynamic> map) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    final fullName = ((map['fullName'] ?? map['name'] ?? 'Tenant') as String)
        .trim();

    return DashboardTenantDto(
      id: id,
      fullName: fullName.isEmpty ? 'Tenant' : fullName,
      createdAt: toDate(map['createdAt'] ?? map['moveInDate']),
    );
  }
}

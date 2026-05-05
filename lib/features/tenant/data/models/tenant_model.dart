import 'package:cloud_firestore/cloud_firestore.dart';

class TenantModel {
  const TenantModel({
    required this.tenantId,
    required this.ownerId,
    required this.name,
    required this.rent,
    required this.dueDay,
    required this.createdAt,
    required this.documentId,
  });

  final String tenantId;
  final String ownerId;
  final String name;
  final double rent;
  final int dueDay;
  final DateTime? createdAt;
  final String documentId;

  factory TenantModel.fromMap({
    required String documentId,
    required Map<String, dynamic> map,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return TenantModel(
      tenantId: (map['tenantId'] ?? '').toString().trim(),
      ownerId: (map['ownerId'] ?? '').toString().trim(),
      name: (map['name'] ?? '').toString().trim(),
      rent: (map['rent'] as num?)?.toDouble() ?? 0,
      dueDay: (map['dueDay'] as num?)?.toInt() ?? 1,
      createdAt: parseDate(map['createdAt']),
      documentId: documentId,
    );
  }
}

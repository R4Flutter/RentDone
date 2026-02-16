import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPaymentDto {
  final String id;
  final String tenantId;
  final int amount;
  final DateTime dueDate;
  final String status;
  final String method;
  final DateTime? paidAt;
  final DateTime updatedAt;

  const DashboardPaymentDto({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.method,
    required this.paidAt,
    required this.updatedAt,
  });

  factory DashboardPaymentDto.fromMap(String id, Map<String, dynamic> map) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return DashboardPaymentDto(
      id: id,
      tenantId: (map['tenantId'] ?? '').toString(),
      amount: toInt(map['amount']),
      dueDate: toDate(map['dueDate']),
      status: (map['status'] ?? 'pending').toString(),
      method: (map['method'] ?? 'unknown').toString(),
      paidAt: map['paidAt'] != null ? toDate(map['paidAt']) : null,
      updatedAt: toDate(map['updatedAt']),
    );
  }
}

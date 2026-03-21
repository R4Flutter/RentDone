import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPaymentDto {
  final String id;
  final String tenantId;
  final int amount;
  final int paidAmount;
  final DateTime dueDate;
  final String status;
  final String method;
  final DateTime? paidAt;
  final DateTime updatedAt;

  const DashboardPaymentDto({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.paidAmount,
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

    String normalizeStatus(dynamic raw) {
      final value = (raw ?? '').toString().trim().toLowerCase();
      if (value == 'paid' || value == 'success') return 'paid';
      if (value == 'partial') return 'partial';
      return 'pending';
    }

    String normalizeMethod(dynamic raw) {
      final value = (raw ?? '').toString().trim().toLowerCase();
      if (value.isEmpty) return 'unknown';
      if (value == 'cash') return 'cash';
      if (value == 'upi' || value == 'online' || value == 'razorpay') {
        return 'upi';
      }
      if (value == 'bank transfer' || value == 'cheque') return 'bank';
      return value;
    }

    final amount = toInt(map['amount']) > 0
        ? toInt(map['amount'])
        : toInt(map['baseAmount']);
    final paidAmount = toInt(map['paidAmount']);

    return DashboardPaymentDto(
      id: id,
      tenantId: (map['tenantId'] ?? '').toString(),
      amount: amount,
      paidAmount: paidAmount,
      dueDate: toDate(map['dueDate'] ?? map['date'] ?? map['createdAt']),
      status: normalizeStatus(map['status']),
      method: normalizeMethod(map['method'] ?? map['paymentMethod']),
      paidAt: map['paidAt'] != null
          ? toDate(map['paidAt'])
          : (map['date'] != null ? toDate(map['date']) : null),
      updatedAt: toDate(map['updatedAt'] ?? map['createdAt'] ?? map['date']),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String tenantId;
  final String propertyId;
  final String roomId;
  final int amount;
  final DateTime dueDate;
  final String periodKey;
  final String status; // pending, paid, overdue
  final String method; // cash, online, unknown
  final DateTime? paidAt;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.roomId,
    required this.amount,
    required this.dueDate,
    required this.periodKey,
    required this.status,
    required this.method,
    this.paidAt,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }
    return Payment(
      id: doc.id,
      tenantId: data['tenantId'] ?? '',
      propertyId: data['propertyId'] ?? '',
      roomId: data['roomId'] ?? '',
      amount: data['amount'] ?? 0,
      dueDate: toDate(data['dueDate']),
      periodKey: data['periodKey'] ?? '',
      status: data['status'] ?? 'pending',
      method: data['method'] ?? 'unknown',
      paidAt: data['paidAt'] != null
          ? toDate(data['paidAt'])
          : null,
      transactionId: data['transactionId'],
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'propertyId': propertyId,
      'roomId': roomId,
      'amount': amount,
      'dueDate': dueDate,
      'periodKey': periodKey,
      'status': status,
      'method': method,
      'paidAt': paidAt,
      'transactionId': transactionId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

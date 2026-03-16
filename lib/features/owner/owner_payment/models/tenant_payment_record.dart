import 'package:cloud_firestore/cloud_firestore.dart';

class TenantPaymentRecord {
  const TenantPaymentRecord({
    required this.id,
    required this.tenantId,
    required this.propertyId,
    required this.amount,
    required this.date,
    required this.method,
    required this.status,
    required this.createdAt,
    this.transactionId,
    this.notes,
  });

  final String id;
  final String tenantId;
  final String propertyId;
  final int amount;
  final DateTime date;
  final String method;
  final String status;
  final DateTime createdAt;
  final String? transactionId;
  final String? notes;

  factory TenantPaymentRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime toDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return fallback;
    }

    final createdAt = toDate(data['createdAt'], DateTime.now());
    final date = toDate(
      data['date'] ?? data['paymentDate'] ?? data['dueDate'],
      createdAt,
    );

    String normalizeStatus(String? raw) {
      final value = (raw ?? '').trim().toLowerCase();
      if (value == 'paid') return 'paid';
      if (value == 'partial') return 'partial';
      if (value == 'unpaid' || value == 'pending' || value == 'overdue') {
        return 'unpaid';
      }
      return 'unpaid';
    }

    return TenantPaymentRecord(
      id: id,
      tenantId: (data['tenantId'] as String? ?? '').trim(),
      propertyId: (data['propertyId'] as String? ?? '').trim(),
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      date: date,
      method: ((data['method'] ?? data['paymentMethod'] ?? 'Cash') as String)
          .trim(),
      status: normalizeStatus(data['status'] as String?),
      createdAt: createdAt,
      transactionId: (data['transactionId'] as String?)?.trim(),
      notes: (data['notes'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toFirestore({required String ownerId}) {
    return {
      'tenantId': tenantId,
      'propertyId': propertyId,
      'ownerId': ownerId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'transactionId': transactionId,
      'notes': notes,
    };
  }
}

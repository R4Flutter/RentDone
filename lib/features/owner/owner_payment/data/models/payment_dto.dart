import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_payment/domain/entities/payment.dart';

class PaymentDto {
  final String id;
  final String tenantId;
  final String propertyId;
  final String roomId;
  final int amount;
  final DateTime dueDate;
  final String periodKey;
  final String status;
  final String method;
  final DateTime? paidAt;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentDto({
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

  factory PaymentDto.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return PaymentDto(
      id: id,
      tenantId: (data['tenantId'] as String?) ?? '',
      propertyId: (data['propertyId'] as String?) ?? '',
      roomId: (data['roomId'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      dueDate: toDate(data['dueDate']),
      periodKey: (data['periodKey'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      method: (data['method'] as String?) ?? 'unknown',
      paidAt: data['paidAt'] != null ? toDate(data['paidAt']) : null,
      transactionId: data['transactionId'] as String?,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  Payment toEntity() {
    return Payment(
      id: id,
      tenantId: tenantId,
      propertyId: propertyId,
      roomId: roomId,
      amount: amount,
      dueDate: dueDate,
      periodKey: periodKey,
      status: status,
      method: method,
      paidAt: paidAt,
      transactionId: transactionId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

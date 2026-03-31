import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/payment/domain/entities/transaction_record.dart';

class TransactionRecordDto {
  final String id;
  final String paymentId;
  final String leaseId;
  final String tenantId;
  final String ownerId;
  final int amount;
  final String currency;
  final String status;
  final String gateway;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? baseAmount;
  final int? paidAmount;
  final int? remainingAmount;

  const TransactionRecordDto({
    required this.id,
    required this.paymentId,
    required this.leaseId,
    required this.tenantId,
    required this.ownerId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.gateway,
    this.failureReason,
    required this.createdAt,
    this.completedAt,
    this.baseAmount,
    this.paidAmount,
    this.remainingAmount,
  });

  factory TransactionRecordDto.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return TransactionRecordDto(
      id: id,
      paymentId: (data['paymentId'] as String?) ?? id,
      leaseId:
          (data['leaseId'] as String?) ?? (data['propertyId'] as String?) ?? '',
      tenantId: (data['tenantId'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      amount:
          (data['baseAmount'] as num?)?.toInt() ??
          (data['amount'] as num?)?.toInt() ??
          0,
      currency: (data['currency'] as String?) ?? 'INR',
      status: (data['status'] as String?) ?? 'pending',
      gateway:
          (data['gateway'] as String?) ??
          (data['method'] as String?) ??
          'manual',
      failureReason:
          (data['notes'] as String?) ?? (data['failureReason'] as String?),
      createdAt: toDate(data['createdAt']),
      completedAt: data['completedAt'] != null
          ? toDate(data['completedAt'])
          : (data['date'] != null ? toDate(data['date']) : null),
      baseAmount: (data['baseAmount'] as num?)?.toInt(),
      paidAmount: (data['paidAmount'] as num?)?.toInt(),
      remainingAmount: (data['remainingAmount'] as num?)?.toInt(),
    );
  }

  TransactionRecord toEntity() {
    return TransactionRecord(
      transactionId: id,
      paymentId: paymentId,
      leaseId: leaseId,
      tenantId: tenantId,
      ownerId: ownerId,
      amount: amount,
      currency: currency,
      status: status,
      gateway: gateway,
      failureReason: failureReason,
      createdAt: createdAt,
      completedAt: completedAt,
      baseAmount: baseAmount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
    );
  }
}

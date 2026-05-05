import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/payment_enums.dart';

class PaymentRecordModel {
  const PaymentRecordModel({
    required this.paymentId,
    required this.tenantId,
    required this.ownerId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.razorpayOrderId,
    this.razorpayPaymentId,
  });

  final String paymentId;
  final String tenantId;
  final String ownerId;
  final double amount;
  final PaymentMethodType method;
  final PaymentStatusType status;
  final DateTime? createdAt;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;

  bool get isSuccessful => status == PaymentStatusType.success;

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return PaymentRecordModel(
      paymentId: (map['paymentId'] ?? '').toString().trim(),
      tenantId: (map['tenantId'] ?? '').toString().trim(),
      ownerId: (map['ownerId'] ?? '').toString().trim(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: PaymentMethodTypeX.fromDb((map['method'] ?? '').toString()),
      status: PaymentStatusTypeX.fromDb((map['status'] ?? '').toString()),
      createdAt: parseDate(map['createdAt']),
      razorpayOrderId: map['razorpayOrderId']?.toString(),
      razorpayPaymentId: map['razorpayPaymentId']?.toString(),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/payment_entity.dart';

/// Data Transfer Object for Payment/Transaction
class PaymentDTO {
  final String id;
  final String tenantId;
  final String ownerId;
  final String propertyId;
  final int amount;
  final DateTime paymentDate;
  final String monthFor;
  final String paymentMethod;
  final String? referenceId;
  final String status;
  final String? notes;
  final DateTime createdAt;

  PaymentDTO({
    required this.id,
    required this.tenantId,
    required this.ownerId,
    required this.propertyId,
    required this.amount,
    required this.paymentDate,
    required this.monthFor,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.referenceId,
    this.notes,
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'ownerId': ownerId,
      'propertyId': propertyId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'monthFor': monthFor,
      'paymentMethod': paymentMethod,
      'referenceId': referenceId,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create from Firestore document
  factory PaymentDTO.fromMap(Map<String, dynamic> map) {
    return PaymentDTO(
      id: map['id'] as String,
      tenantId: map['tenantId'] as String,
      ownerId: map['ownerId'] as String,
      propertyId: map['propertyId'] as String,
      amount: map['amount'] as int,
      paymentDate: (map['paymentDate'] as Timestamp).toDate(),
      monthFor: map['monthFor'] as String,
      paymentMethod: map['paymentMethod'] as String,
      referenceId: map['referenceId'] as String?,
      status: map['status'] as String,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert DTO to Entity
  PaymentEntity toEntity() {
    return PaymentEntity(
      id: id,
      tenantId: tenantId,
      ownerId: ownerId,
      propertyId: propertyId,
      amount: amount,
      paymentDate: paymentDate,
      monthFor: monthFor,
      paymentMethod: paymentMethod,
      referenceId: referenceId,
      status: status,
      notes: notes,
      createdAt: createdAt,
    );
  }

  /// Create DTO from Entity
  factory PaymentDTO.fromEntity(PaymentEntity entity) {
    return PaymentDTO(
      id: entity.id,
      tenantId: entity.tenantId,
      ownerId: entity.ownerId,
      propertyId: entity.propertyId,
      amount: entity.amount,
      paymentDate: entity.paymentDate,
      monthFor: entity.monthFor,
      paymentMethod: entity.paymentMethod,
      referenceId: entity.referenceId,
      status: entity.status,
      notes: entity.notes,
      createdAt: entity.createdAt,
    );
  }
}

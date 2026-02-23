/// Represents a payment/transaction for a tenant
/// Tracks rent payments with full audit trail
class PaymentEntity {
  final String id;
  final String tenantId;
  final String ownerId;
  final String propertyId;
  final int amount;
  final DateTime paymentDate;
  final String monthFor; // e.g., "Jan 2026"
  final String paymentMethod; // UPI, cash, bank_transfer, check
  final String? referenceId; // transaction ID from payment gateway
  final String status; // paid, partial, pending, failed
  final String? notes;
  final DateTime createdAt;

  const PaymentEntity({
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

  PaymentEntity copyWith({
    String? id,
    String? tenantId,
    String? ownerId,
    String? propertyId,
    int? amount,
    DateTime? paymentDate,
    String? monthFor,
    String? paymentMethod,
    String? referenceId,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaymentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      monthFor: monthFor ?? this.monthFor,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceId: referenceId ?? this.referenceId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'PaymentEntity(id: $id, tenantId: $tenantId, amount: $amount, status: $status)';
}

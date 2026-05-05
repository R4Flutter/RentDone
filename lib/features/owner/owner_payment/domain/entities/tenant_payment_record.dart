class PaymentInstallment {
  const PaymentInstallment({
    required this.amount,
    required this.date,
    required this.method,
    this.notes,
  });

  final int amount;
  final DateTime date;
  final String method;
  final String? notes;
}

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
    required this.baseAmount,
    required this.paidAmount,
    required this.remainingAmount,
    this.transactionId,
    this.notes,
    this.installments = const <PaymentInstallment>[],
  });

  final String id;
  final String tenantId;
  final String propertyId;
  final int amount;
  final DateTime date;
  final String method;
  final String status;
  final DateTime createdAt;
  final int baseAmount;
  final int paidAmount;
  final int remainingAmount;
  final String? transactionId;
  final String? notes;
  final List<PaymentInstallment> installments;

  bool get isSettled => remainingAmount <= 0;
}

class PaymentDue {
  final String leaseId;
  final String paymentId;
  final String tenantId;
  final String ownerId;
  final String propertyId;
  final String propertyName;
  final String ownerName;
  final int monthlyRent;
  final DateTime dueDate;
  final int lateFeeAmount;
  final int totalPayable;
  final int daysRemaining;
  final String paymentStatus;
  final String? lastTransactionStatus;
  final String? receiptUrl;

  const PaymentDue({
    required this.leaseId,
    required this.paymentId,
    required this.tenantId,
    required this.ownerId,
    required this.propertyId,
    required this.propertyName,
    required this.ownerName,
    required this.monthlyRent,
    required this.dueDate,
    required this.lateFeeAmount,
    required this.totalPayable,
    required this.daysRemaining,
    required this.paymentStatus,
    this.lastTransactionStatus,
    this.receiptUrl,
  });
}

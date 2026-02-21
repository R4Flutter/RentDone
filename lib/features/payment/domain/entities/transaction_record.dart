class TransactionRecord {
  final String transactionId;
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

  const TransactionRecord({
    required this.transactionId,
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
  });
}

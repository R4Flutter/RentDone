class Payment {
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

  const Payment({
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
}

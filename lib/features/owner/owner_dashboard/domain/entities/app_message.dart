class AppMessage {
  final String id;
  final String type;
  final String title;
  final String body;
  final String severity;
  final String? tenantId;
  final String? paymentId;
  final bool read;
  final DateTime createdAt;

  const AppMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
    this.tenantId,
    this.paymentId,
    required this.read,
    required this.createdAt,
  });
}

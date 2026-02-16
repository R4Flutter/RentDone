import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';

class AppMessageDto {
  final String id;
  final String type; // reminder, overdue, receipt
  final String title;
  final String body;
  final String severity; // info, warn, critical
  final String? tenantId;
  final String? paymentId;
  final bool read;
  final DateTime createdAt;

  AppMessageDto({
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

  factory AppMessageDto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }
    return AppMessageDto(
      id: doc.id,
      type: data['type'] ?? 'reminder',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      severity: data['severity'] ?? 'info',
      tenantId: data['tenantId'],
      paymentId: data['paymentId'],
      read: data['read'] ?? false,
      createdAt: toDate(data['createdAt']),
    );
  }

  AppMessage toEntity() {
    return AppMessage(
      id: id,
      type: type,
      title: title,
      body: body,
      severity: severity,
      tenantId: tenantId,
      paymentId: paymentId,
      read: read,
      createdAt: createdAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owner_notifications/domain/entities/owner_notification.dart';

class OwnerNotificationDto {
  final String id;
  final String type;
  final String title;
  final String body;
  final String severity;
  final String? tenantId;
  final String? paymentId;
  final bool read;
  final DateTime createdAt;

  const OwnerNotificationDto({
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

  factory OwnerNotificationDto.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return OwnerNotificationDto(
      id: doc.id,
      type: (data['type'] ?? 'reminder').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      severity: (data['severity'] ?? 'info').toString(),
      tenantId: data['tenantId']?.toString(),
      paymentId: data['paymentId']?.toString(),
      read: data['read'] == true,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  OwnerNotification toEntity() {
    return OwnerNotification(
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

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class TenantReminder {
  final String id;
  final String title;
  final String body;
  final String periodKey;
  final int daysBeforeDue;
  final String status;
  final DateTime? createdAt;

  const TenantReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.periodKey,
    required this.daysBeforeDue,
    required this.status,
    this.createdAt,
  });

  factory TenantReminder.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return TenantReminder(
      id: doc.id,
      title: (data['title'] as String? ?? '').trim(),
      body: (data['body'] as String? ?? '').trim(),
      periodKey: (data['periodKey'] as String? ?? '').trim(),
      daysBeforeDue: (data['daysBeforeDue'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String? ?? 'pending').trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

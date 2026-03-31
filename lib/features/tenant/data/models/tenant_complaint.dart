import 'package:cloud_firestore/cloud_firestore.dart';

class TenantComplaint {
  final String description;
  final String category;
  final String status;

  const TenantComplaint({
    required this.description,
    required this.category,
    this.status = 'pending',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'category': category,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

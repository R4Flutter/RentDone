import 'package:cloud_firestore/cloud_firestore.dart';

class TenantOwnerDetails {
  final String ownerPhoneNumber;

  const TenantOwnerDetails({required this.ownerPhoneNumber});

  Map<String, dynamic> toFirestore() {
    return {
      'ownerPhoneNumber': ownerPhoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TenantOwnerDetails.fromMap(Map<String, dynamic> map) {
    return TenantOwnerDetails(
      ownerPhoneNumber: (map['ownerPhoneNumber'] as String? ?? '').trim(),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class TenantOwnerDetails {
  final String ownerPhoneNumber;
  final String ownerUpiId;
  final String ownerName;

  const TenantOwnerDetails({
    required this.ownerPhoneNumber,
    this.ownerUpiId = '',
    this.ownerName = '',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'ownerPhoneNumber': ownerPhoneNumber,
      if (ownerUpiId.isNotEmpty) 'ownerUpiId': ownerUpiId,
      if (ownerName.isNotEmpty) 'ownerName': ownerName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TenantOwnerDetails.fromMap(Map<String, dynamic> map) {
    final upiCandidates = <String?>[
      map['ownerUpiId'] as String?,
      map['upiId'] as String?,
      map['upiID'] as String?,
      map['upi'] as String?,
    ];

    String resolvedUpi = '';
    for (final candidate in upiCandidates) {
      final normalized = (candidate ?? '').trim();
      if (normalized.isNotEmpty) {
        resolvedUpi = normalized;
        break;
      }
    }

    return TenantOwnerDetails(
      ownerPhoneNumber: (map['ownerPhoneNumber'] as String? ?? '').trim(),
      ownerUpiId: resolvedUpi,
      ownerName: (map['ownerName'] as String? ?? map['name'] as String? ?? '')
          .trim(),
    );
  }
}

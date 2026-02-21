import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerUpiProfile {
  final String upiId;
  final bool isVerified;

  const OwnerUpiProfile({required this.upiId, required this.isVerified});
}

class OwnerUpiFirestoreService {
  final FirebaseFirestore _firestore;

  OwnerUpiFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<OwnerUpiProfile?> getOwnerUpiProfile(String ownerId) async {
    final doc = await _firestore
        .collection('ownerPaymentProfiles')
        .doc(ownerId)
        .get();

    if (!doc.exists) return null;
    final data = doc.data() ?? const <String, dynamic>{};
    final upiId = (data['upiId'] as String?)?.trim() ?? '';
    if (upiId.isEmpty) return null;

    return OwnerUpiProfile(
      upiId: upiId,
      isVerified: data['isUpiVerified'] == true,
    );
  }

  Future<void> saveVerifiedUpi({
    required String ownerId,
    required String upiId,
  }) async {
    await _firestore.collection('ownerPaymentProfiles').doc(ownerId).set({
      'ownerId': ownerId,
      'upiId': upiId.trim(),
      'isUpiVerified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

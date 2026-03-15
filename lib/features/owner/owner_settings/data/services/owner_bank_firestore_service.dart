import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerBankProfile {
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String branch;
  final bool isVerified;
  final DateTime? verifiedAt;
  final DateTime? updatedAt;

  const OwnerBankProfile({
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
    required this.branch,
    required this.isVerified,
    required this.verifiedAt,
    required this.updatedAt,
  });
}

class OwnerBankFirestoreService {
  final FirebaseFirestore _firestore;

  OwnerBankFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<OwnerBankProfile?> getOwnerBankProfile(String ownerId) async {
    final doc = await _firestore
        .collection('ownerPaymentProfiles')
        .doc(ownerId)
        .get();

    if (!doc.exists) return null;
    final data = doc.data() ?? const <String, dynamic>{};

    final accountHolderName =
        (data['bankAccountHolderName'] as String?)?.trim() ?? '';
    final bankName = (data['bankName'] as String?)?.trim() ?? '';
    final accountNumber = (data['bankAccountNumber'] as String?)?.trim() ?? '';
    final ifsc = (data['bankIfsc'] as String?)?.trim() ?? '';
    final branch = (data['bankBranch'] as String?)?.trim() ?? '';
    final verifiedAt = _toDateTime(data['bankVerifiedAt']);
    final updatedAt = _toDateTime(data['updatedAt']);

    if (accountHolderName.isEmpty &&
        bankName.isEmpty &&
        accountNumber.isEmpty &&
        ifsc.isEmpty) {
      return null;
    }

    return OwnerBankProfile(
      accountHolderName: accountHolderName,
      bankName: bankName,
      accountNumber: accountNumber,
      ifsc: ifsc,
      branch: branch,
      isVerified: data['isBankVerified'] == true,
      verifiedAt: verifiedAt,
      updatedAt: updatedAt,
    );
  }

  Future<void> saveVerifiedBankDetails({
    required String ownerId,
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String ifsc,
    required String branch,
  }) async {
    await _firestore.collection('ownerPaymentProfiles').doc(ownerId).set({
      'ownerId': ownerId,
      'bankAccountHolderName': accountHolderName.trim(),
      'bankName': bankName.trim(),
      'bankAccountNumber': accountNumber.trim(),
      'bankIfsc': ifsc.trim().toUpperCase(),
      'bankBranch': branch.trim(),
      'isBankVerified': true,
      'bankVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class TenantSummarySeedResolver {
  final FirebaseFirestore firestore;

  const TenantSummarySeedResolver(this.firestore);

  Future<
    ({
      Map<String, dynamic> userData,
      Map<String, dynamic>? tenantData,
      String? tenantId,
    })
  >
  resolve(String uid) async {
    final userData = await _readUser(uid);
    final resolved =
        await _readById(userData['tenantId'] as String?) ??
        await _readById(uid) ??
        await _readByAuthUid(uid);
    return (
      userData: userData,
      tenantData: resolved?.$1,
      tenantId: resolved?.$2,
    );
  }

  Future<Map<String, dynamic>> _readUser(String uid) async {
    try {
      return (await firestore.collection('users').doc(uid).get()).data() ??
          const <String, dynamic>{};
    } on FirebaseException {
      return const <String, dynamic>{};
    }
  }

  Future<(Map<String, dynamic>, String)?> _readById(String? tenantId) async {
    if (tenantId == null || tenantId.isEmpty) return null;
    try {
      final doc = await firestore.collection('tenants').doc(tenantId).get();
      return doc.exists && doc.data() != null ? (doc.data()!, doc.id) : null;
    } on FirebaseException {
      return null;
    }
  }

  Future<(Map<String, dynamic>, String)?> _readByAuthUid(String uid) async {
    try {
      final result = await firestore
          .collection('tenants')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      return result.docs.isEmpty
          ? null
          : (result.docs.first.data(), result.docs.first.id);
    } on FirebaseException {
      return null;
    }
  }
}

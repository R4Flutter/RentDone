import 'package:cloud_firestore/cloud_firestore.dart';

class TenantUserSyncStore {
  final FirebaseFirestore firestore;

  const TenantUserSyncStore(this.firestore);

  Future<void> ensureTenantUserDoc({
    required String uid,
    required String email,
  }) async {
    final userRef = firestore.collection('users').doc(uid);
    final normalizedEmail = email.trim().toLowerCase();
    final snapshot = await userRef.get();
    if (!snapshot.exists) {
      await userRef.set(
        _payload(email, normalizedEmail, includeRole: true, uid: uid),
      );
      return;
    }

    await userRef.set({
      ..._payload(email, normalizedEmail, uid: uid),
      if ((snapshot.data() ?? const <String, dynamic>{})['role'] == null)
        'role': 'tenant',
    }, SetOptions(merge: true));
  }

  Map<String, dynamic> _payload(
    String email,
    String normalizedEmail, {
    required String uid,
    bool includeRole = false,
  }) => {
    'uid': uid,
    'email': email,
    'emailLowercase': normalizedEmail,
    'updatedAt': FieldValue.serverTimestamp(),
    if (includeRole) 'role': 'tenant',
  };
}

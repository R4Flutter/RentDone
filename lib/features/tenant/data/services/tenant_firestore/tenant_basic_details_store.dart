import 'package:cloud_firestore/cloud_firestore.dart';

import 'tenant_phone_hash.dart';

class TenantBasicDetailsStore {
  final FirebaseFirestore firestore;

  const TenantBasicDetailsStore(this.firestore);

  Future<void> save({
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  }) async {
    final normalizedName = tenantName.trim();
    final normalizedEmail = tenantEmail.trim();
    final normalizedPhone = tenantPhone.trim();
    final payload = {
      'name': normalizedName,
      'email': normalizedEmail,
      'emailLowercase': normalizedEmail.toLowerCase(),
      'phoneNumber': normalizedPhone,
      'phoneHash': hashTenantPhone(normalizeTenantPhone(normalizedPhone)),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await firestore
        .collection('tenants')
        .doc(tenantId)
        .set(payload, SetOptions(merge: true));
    await firestore
        .collection('users')
        .doc(tenantId)
        .set(payload, SetOptions(merge: true));
  }
}

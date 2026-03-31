import 'package:cloud_firestore/cloud_firestore.dart';

class TenantSettingsStore {
  final FirebaseFirestore firestore;

  const TenantSettingsStore(this.firestore);

  Future<Map<String, bool>> get(String tenantId) async {
    bool? darkAppearanceEnabled;
    darkAppearanceEnabled = await _readSetting('users', tenantId);
    darkAppearanceEnabled ??= await _readSetting('tenants', tenantId);
    return {'darkAppearanceEnabled': darkAppearanceEnabled ?? true};
  }

  Future<void> save(String tenantId, bool darkAppearanceEnabled) async {
    final payload = {
      'darkAppearanceEnabled': darkAppearanceEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await firestore.collection('users').doc(tenantId).set({
      'tenantSettings': payload,
      'notifications': {'rent_due': true, 'payment_received': true},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await firestore.collection('tenants').doc(tenantId).set({
      'tenantSettings': payload,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool?> _readSetting(String collection, String tenantId) async {
    try {
      final data =
          (await firestore.collection(collection).doc(tenantId).get()).data() ??
          const <String, dynamic>{};
      final settings = data['tenantSettings'];
      return settings is Map<String, dynamic>
          ? settings['darkAppearanceEnabled'] as bool?
          : null;
    } on FirebaseException {
      return null;
    }
  }
}

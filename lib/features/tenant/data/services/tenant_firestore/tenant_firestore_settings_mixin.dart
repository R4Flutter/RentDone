import 'package:cloud_firestore/cloud_firestore.dart';

import 'tenant_settings_store.dart';

mixin TenantFirestoreSettingsMixin {
  FirebaseFirestore get firestore;

  Future<Map<String, bool>> getTenantAppSettings(String tenantId) =>
      TenantSettingsStore(firestore).get(tenantId);

  Future<void> saveTenantAppSettings({
    required String tenantId,
    required bool darkAppearanceEnabled,
  }) => TenantSettingsStore(firestore).save(tenantId, darkAppearanceEnabled);
}

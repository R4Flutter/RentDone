import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';

import 'tenant_owner_details_reader.dart';
import 'tenant_owner_details_writer.dart';

mixin TenantFirestoreOwnerMixin {
  FirebaseFirestore get firestore;

  Future<String> getOwnerPhoneNumber(String ownerId) =>
      TenantOwnerDetailsReader(firestore).getOwnerPhoneNumber(ownerId);

  Future<TenantOwnerDetails?> getOwnerDetails(String tenantId) =>
      TenantOwnerDetailsReader(firestore).get(tenantId);

  Future<void> saveOwnerDetails({
    required String tenantId,
    required TenantOwnerDetails details,
  }) => TenantOwnerDetailsWriter(firestore).save(tenantId, details);
}

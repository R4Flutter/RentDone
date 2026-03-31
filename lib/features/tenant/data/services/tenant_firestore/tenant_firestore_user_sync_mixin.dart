import 'package:cloud_firestore/cloud_firestore.dart';

import 'tenant_basic_details_store.dart';
import 'tenant_self_profile_bootstrapper.dart';
import 'tenant_user_sync_store.dart';

mixin TenantFirestoreUserSyncMixin {
  FirebaseFirestore get firestore;

  Future<void> ensureTenantUserDoc({
    required String uid,
    required String email,
  }) => TenantUserSyncStore(
    firestore,
  ).ensureTenantUserDoc(uid: uid, email: email);

  Future<void> ensureSelfTenantProfile({
    required String uid,
    required String email,
    String? displayName,
    String? phoneNumber,
  }) => TenantSelfProfileBootstrapper(firestore).ensure(
    uid: uid,
    email: email,
    displayName: displayName,
    phoneNumber: phoneNumber,
  );

  Future<void> saveTenantBasicDetails({
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  }) => TenantBasicDetailsStore(firestore).save(
    tenantId: tenantId,
    tenantName: tenantName,
    tenantEmail: tenantEmail,
    tenantPhone: tenantPhone,
  );
}

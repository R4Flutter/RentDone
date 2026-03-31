import 'package:cloud_firestore/cloud_firestore.dart';

import 'tenant_firestore/tenant_firestore_documents_mixin.dart';
import 'tenant_firestore/tenant_firestore_owner_mixin.dart';
import 'tenant_firestore/tenant_firestore_payments_mixin.dart';
import 'tenant_firestore/tenant_firestore_room_mixin.dart';
import 'tenant_firestore/tenant_firestore_settings_mixin.dart';
import 'tenant_firestore/tenant_firestore_summary_mixin.dart';
import 'tenant_firestore/tenant_firestore_user_sync_mixin.dart';

class TenantFirestoreService
    with
        TenantFirestoreUserSyncMixin,
        TenantFirestoreSummaryMixin,
        TenantFirestorePaymentsMixin,
        TenantFirestoreDocumentsMixin,
        TenantFirestoreRoomMixin,
        TenantFirestoreOwnerMixin,
        TenantFirestoreSettingsMixin {
  final FirebaseFirestore _firestore;

  TenantFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  FirebaseFirestore get firestore => _firestore;
}

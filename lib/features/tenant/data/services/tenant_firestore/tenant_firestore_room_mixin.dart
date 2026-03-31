import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';

import 'tenant_room_details_reader.dart';
import 'tenant_room_details_writer.dart';

mixin TenantFirestoreRoomMixin {
  FirebaseFirestore get firestore;

  Future<TenantRoomDetails?> getRoomDetails(String tenantId) =>
      TenantRoomDetailsReader(firestore).get(tenantId);

  Future<void> saveRoomDetails({
    required String tenantId,
    required TenantRoomDetails details,
  }) => TenantRoomDetailsWriter(firestore).save(tenantId, details);
}

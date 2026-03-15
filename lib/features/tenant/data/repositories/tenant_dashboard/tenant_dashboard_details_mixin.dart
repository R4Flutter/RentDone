import 'package:rentdone/features/tenant/data/models/tenant_owner_details.dart';
import 'package:rentdone/features/tenant/data/models/tenant_room_details.dart';
import 'package:rentdone/features/tenant/data/services/tenant_firestore_service.dart';

mixin TenantDashboardDetailsMixin {
  TenantFirestoreService get firestoreService;

  Future<TenantRoomDetails?> getRoomDetails(String tenantId) =>
      firestoreService.getRoomDetails(tenantId);
  Future<void> saveRoomDetails({
    required String tenantId,
    required TenantRoomDetails details,
  }) => firestoreService.saveRoomDetails(tenantId: tenantId, details: details);
  Future<TenantOwnerDetails?> getOwnerDetails(String tenantId) =>
      firestoreService.getOwnerDetails(tenantId);
  Future<void> saveOwnerDetails({
    required String tenantId,
    required TenantOwnerDetails details,
  }) => firestoreService.saveOwnerDetails(tenantId: tenantId, details: details);
  Future<void> saveTenantBasicDetails({
    required String tenantId,
    required String tenantName,
    required String tenantEmail,
    required String tenantPhone,
  }) => firestoreService.saveTenantBasicDetails(
    tenantId: tenantId,
    tenantName: tenantName,
    tenantEmail: tenantEmail,
    tenantPhone: tenantPhone,
  );
}

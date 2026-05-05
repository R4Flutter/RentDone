import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

abstract class TenantRepository {
  Stream<List<Tenant>> watchAllTenants(String ownerId);
  Stream<List<Tenant>> watchPropertyTenants(String propertyId);
  Future<Tenant?> getTenantById(String tenantId);
  Future<void> addTenant(Tenant tenant);
  Future<void> removeTenantFromRoom({
    required String propertyId,
    required String roomId,
    required String tenantId,
  });
}

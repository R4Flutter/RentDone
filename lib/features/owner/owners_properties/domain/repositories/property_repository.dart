import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

abstract class PropertyRepository {
  Stream<List<Property>> watchAllProperties();
  Stream<Property> watchProperty(String propertyId);

  Future<void> addProperty(Property property);
  Future<void> updateProperty(Property property);
  Future<void> deleteProperty(String propertyId);

  Stream<List<Tenant>> watchAllTenants();
  Stream<List<Tenant>> watchTenantsForProperty(String propertyId);
  Future<Tenant?> getTenantById(String tenantId);

  Future<void> addTenant(Tenant tenant);
  Future<void> removeTenant({
    required String tenantId,
    required String propertyId,
    required String roomId,
  });
}

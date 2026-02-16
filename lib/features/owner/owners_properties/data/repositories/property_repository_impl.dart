import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/services/property_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  final PropertyFirebaseService _service;

  PropertyRepositoryImpl(this._service);

  @override
  Stream<List<Property>> watchAllProperties() {
    return _service.watchAllProperties().map(
          (items) => items.map((dto) => dto.toEntity()).toList(),
        );
  }

  @override
  Stream<Property> watchProperty(String propertyId) {
    return _service.watchProperty(propertyId).map((dto) => dto.toEntity());
  }

  @override
  Future<void> addProperty(Property property) {
    return _service.addProperty(PropertyDto.fromEntity(property));
  }

  @override
  Future<void> updateProperty(Property property) {
    return _service.updateProperty(PropertyDto.fromEntity(property));
  }

  @override
  Future<void> deleteProperty(String propertyId) {
    return _service.deleteProperty(propertyId);
  }

  @override
  Stream<List<Tenant>> watchAllTenants() {
    return _service.watchAllTenants().map(
          (items) => items.map((dto) => dto.toEntity()).toList(),
        );
  }

  @override
  Stream<List<Tenant>> watchTenantsForProperty(String propertyId) {
    return _service.watchPropertyTenants(propertyId).map(
          (items) => items.map((dto) => dto.toEntity()).toList(),
        );
  }

  @override
  Future<Tenant?> getTenantById(String tenantId) async {
    final dto = await _service.getTenantById(tenantId);
    return dto?.toEntity();
  }

  @override
  Future<void> addTenant(Tenant tenant) {
    return _service.addTenant(TenantDto.fromEntity(tenant));
  }

  @override
  Future<void> removeTenant({
    required String tenantId,
    required String propertyId,
    required String roomId,
  }) {
    return _service.removeTenant(
      tenantId: tenantId,
      propertyId: propertyId,
      roomId: roomId,
    );
  }
}

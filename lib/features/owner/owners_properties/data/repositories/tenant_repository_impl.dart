import 'package:rentdone/features/owner/owners_properties/data/models/tenant_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/services/tenant_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';

class TenantRepositoryImpl implements TenantRepository {
  final TenantFirebaseService _service;

  TenantRepositoryImpl(this._service);

  @override
  Stream<List<Tenant>> watchAllTenants(String ownerId) {
    return _service.watchAllTenants(ownerId).map(
      (items) => items.map((dto) => dto.toEntity()).toList(),
    );
  }

  @override
  Stream<List<Tenant>> watchPropertyTenants(String propertyId) {
    return _service
        .watchPropertyTenants(propertyId)
        .map((items) => items.map((dto) => dto.toEntity()).toList());
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
  Future<void> removeTenantFromRoom({
    required String propertyId,
    required String roomId,
    required String tenantId,
  }) {
    return _service.removeTenant(
      tenantId: tenantId,
      propertyId: propertyId,
      roomId: roomId,
    );
  }
}

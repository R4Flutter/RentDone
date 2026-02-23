import 'package:rentdone/features/owner/owner_tenants/data/services/owner_tenants_firebase_service.dart';
import 'package:rentdone/features/owner/owner_tenants/domain/repositories/owner_tenants_repository.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class OwnerTenantsRepositoryImpl implements OwnerTenantsRepository {
  final OwnerTenantsFirebaseService _service;

  OwnerTenantsRepositoryImpl(this._service);

  @override
  Stream<List<Tenant>> watchAllTenants() {
    return _service.watchAllTenants().map(
      (items) => items.map((item) => item.toEntity()).toList(),
    );
  }

  @override
  Stream<List<Property>> watchAllProperties() {
    return _service.watchAllProperties().map(
      (items) => items.map((item) => item.toEntity()).toList(),
    );
  }

  @override
  Future<int> cleanupOrphanTenants() {
    return _service.cleanupOrphanTenants();
  }
}

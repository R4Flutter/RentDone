import 'package:rentdone/features/owner/add_tenant/data/services/add_tenant_firebase_service.dart';
import 'package:rentdone/features/owner/add_tenant/domain/repositories/add_tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class AddTenantRepositoryImpl implements TenantRepository {
  final AddTenantFirebaseService _service;

  AddTenantRepositoryImpl(this._service);

  @override
  Future<void> addTenant(Tenant tenant) {
    return _service.addTenant(tenant);
  }
}

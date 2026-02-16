import 'package:rentdone/features/owner/add_tenant/domain/repositories/add_tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';


class AddTenantUseCase {
  final TenantRepository repository;

  AddTenantUseCase(this.repository);

  Future<void> call(Tenant tenant) {
    return repository.addTenant(tenant);
  }
}

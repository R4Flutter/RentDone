import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';

class WatchPropertyTenantsUseCase {
  final TenantRepository repository;

  WatchPropertyTenantsUseCase(this.repository);

  Stream<List<Tenant>> call(String propertyId) {
    return repository.watchPropertyTenants(propertyId);
  }
}

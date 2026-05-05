import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/tenant_repository.dart';

class WatchAllTenantsUseCase {
  final TenantRepository repository;

  WatchAllTenantsUseCase(this.repository);

  Stream<List<Tenant>> call(String ownerId) {
    return repository.watchAllTenants(ownerId);
  }
}

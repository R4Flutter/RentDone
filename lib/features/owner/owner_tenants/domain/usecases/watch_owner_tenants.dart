import 'package:rentdone/features/owner/owner_tenants/domain/repositories/owner_tenants_repository.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

class WatchOwnerTenants {
  final OwnerTenantsRepository _repository;

  const WatchOwnerTenants(this._repository);

  Stream<List<Tenant>> call() {
    return _repository.watchAllTenants();
  }
}

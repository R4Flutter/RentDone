import 'package:rentdone/features/owner/owner_tenants/domain/repositories/owner_tenants_repository.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class WatchOwnerTenantProperties {
  final OwnerTenantsRepository _repository;

  const WatchOwnerTenantProperties(this._repository);

  Stream<List<Property>> call() {
    return _repository.watchAllProperties();
  }
}

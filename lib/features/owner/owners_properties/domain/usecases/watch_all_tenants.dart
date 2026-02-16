import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class WatchAllTenantsUseCase {
  final PropertyRepository _repository;

  const WatchAllTenantsUseCase(this._repository);

  Stream<List<Tenant>> call() {
    return _repository.watchAllTenants();
  }
}

import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class WatchPropertyTenantsUseCase {
  final PropertyRepository _repository;

  const WatchPropertyTenantsUseCase(this._repository);

  Stream<List<Tenant>> call(String propertyId) {
    return _repository.watchTenantsForProperty(propertyId);
  }
}

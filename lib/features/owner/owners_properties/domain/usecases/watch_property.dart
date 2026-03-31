import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class WatchPropertyUseCase {
  final PropertyRepository _repository;

  const WatchPropertyUseCase(this._repository);

  Stream<Property> call(String propertyId) {
    return _repository.watchProperty(propertyId);
  }
}

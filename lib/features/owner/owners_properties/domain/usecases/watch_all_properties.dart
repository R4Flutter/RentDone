import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class WatchAllPropertiesUseCase {
  final PropertyRepository _repository;

  const WatchAllPropertiesUseCase(this._repository);

  Stream<List<Property>> call() {
    return _repository.watchAllProperties();
  }
}

import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class AddPropertyUseCase {
  final PropertyRepository _repository;

  const AddPropertyUseCase(this._repository);

  Future<void> call(Property property) {
    return _repository.addProperty(property);
  }
}

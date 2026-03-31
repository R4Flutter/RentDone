import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class DeletePropertyUseCase {
  final PropertyRepository _repository;

  const DeletePropertyUseCase(this._repository);

  Future<void> call(String propertyId) {
    return _repository.deleteProperty(propertyId);
  }
}

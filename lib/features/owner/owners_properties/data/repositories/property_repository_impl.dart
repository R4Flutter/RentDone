import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/data/services/property_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/repositories/property_repository.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  final PropertyFirebaseService _service;

  PropertyRepositoryImpl(this._service);

  @override
  Stream<List<Property>> watchAllProperties() {
    return _service.watchAllProperties().map(
      (items) => items.map((dto) => dto.toEntity()).toList(),
    );
  }

  @override
  Stream<Property> watchProperty(String propertyId) {
    return _service.watchProperty(propertyId).map((dto) => dto.toEntity());
  }

  @override
  Future<void> addProperty(Property property) {
    return _service.addProperty(PropertyDto.fromEntity(property));
  }

  @override
  Future<void> updateProperty(Property property) {
    return _service.updateProperty(PropertyDto.fromEntity(property));
  }

  @override
  Future<void> deleteProperty(String propertyId) {
    return _service.deleteProperty(propertyId);
  }
}

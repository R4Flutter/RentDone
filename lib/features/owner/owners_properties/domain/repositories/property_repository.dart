import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

abstract class PropertyRepository {
  Stream<List<Property>> watchAllProperties();
  Stream<Property> watchProperty(String propertyId);

  Future<void> addProperty(Property property);
  Future<void> updateProperty(Property property);
  Future<void> deleteProperty(String propertyId);
}

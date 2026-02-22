import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class TenantPropertyFirebaseService {
  final FirebaseFirestore firestore;

  const TenantPropertyFirebaseService(this.firestore);

  Stream<List<Property>> watchPublishedPropertiesForCity({
    required String city,
  }) {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      return const Stream<List<Property>>.empty();
    }

    // We assume your properties collection is "properties"
    final query = firestore
        .collection('properties')
        .where('city', isEqualTo: trimmed)
        .where('isPublished', isEqualTo: true);

    return query.snapshots().map((snapshot) {
      final items = <Property>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // If your stored 'id' field doesn't exist, fallback to doc.id
        data['id'] = (data['id'] ?? doc.id).toString();

        final dto = PropertyDto.fromMap(data);
        final entity = dto.toEntity();

        // Skip invalid coordinates (prevents map crash / markers at 0,0)
        if (entity.lat == 0.0 && entity.lng == 0.0) continue;

        items.add(entity);
      }

      return items;
    });
  }
}
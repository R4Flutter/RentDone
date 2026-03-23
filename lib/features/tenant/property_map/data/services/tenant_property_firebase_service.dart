import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class TenantPropertyFirebaseService {
  final FirebaseFirestore firestore;

  const TenantPropertyFirebaseService(this.firestore);

  Stream<List<Property>> watchPublishedPropertiesForCity({
    required String city,
    LatLng? cityCenter,
  }) {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      return const Stream<List<Property>>.empty();
    }

    final normalizedSearchCity = _normalizeText(trimmed);
    final query = firestore
        .collection('properties')
        .where('isPublished', isEqualTo: true)
        .limit(400);

    return query.snapshots().asyncMap((snapshot) async {
      final byId = <String, Property>{};
      final ownerLocationCache = <String, (double, double)?>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = (data['id'] ?? doc.id).toString();

        // Backward compatibility: if property coords are invalid,
        // use owner-saved location copied into property doc if present.
        final lat = _toDouble(data['lat']);
        final lng = _toDouble(data['lng']);
        if (!_isValidCoordinates(lat, lng)) {
          final ownerLat = _toDouble(data['ownerLocationLatitude']);
          final ownerLng = _toDouble(data['ownerLocationLongitude']);
          if (_isValidCoordinates(ownerLat, ownerLng)) {
            data['lat'] = ownerLat;
            data['lng'] = ownerLng;
          } else {
            final ownerId = (data['ownerId'] ?? '').toString();
            if (ownerId.isNotEmpty) {
              final ownerCoords = ownerLocationCache.containsKey(ownerId)
                  ? ownerLocationCache[ownerId]
                  : await _readOwnerCoordinates(ownerId);
              ownerLocationCache[ownerId] = ownerCoords;
              if (ownerCoords != null) {
                data['lat'] = ownerCoords.$1;
                data['lng'] = ownerCoords.$2;
              }
            }
          }
        }

        final dto = PropertyDto.fromMap(data);
        final entity = dto.toEntity();

        final isCityTextMatch = _cityMatches(normalizedSearchCity, entity.city);
        final isNearCityCenter = _isNearCityCenter(
          cityCenter: cityCenter,
          propertyLat: entity.lat,
          propertyLng: entity.lng,
        );

        // Include by either city text match OR coordinate proximity to searched city.
        if (!isCityTextMatch && !isNearCityCenter) {
          continue;
        }

        // Skip invalid coordinates (prevents map crashes and bad markers).
        if (entity.lat == 0.0 && entity.lng == 0.0) continue;

        byId[entity.id] = entity;
      }

      final items = byId.values.toList()
        ..sort((a, b) => b.vacantRooms.compareTo(a.vacantRooms));
      return items;
    });
  }

  bool _cityMatches(String normalizedSearchCity, String propertyCityRaw) {
    final propertyCity = _normalizeText(propertyCityRaw);
    if (propertyCity.isEmpty || normalizedSearchCity.isEmpty) return false;

    if (propertyCity == normalizedSearchCity) return true;
    if (propertyCity.contains(normalizedSearchCity)) return true;
    if (normalizedSearchCity.contains(propertyCity)) return true;

    final searchTokens = normalizedSearchCity
        .split(' ')
        .where((t) => t.isNotEmpty);
    final propertyTokens = propertyCity
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toSet();
    return searchTokens.any(propertyTokens.contains);
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isValidCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0.0 && lng == 0.0);
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<(double, double)?> _readOwnerCoordinates(String ownerId) async {
    final snapshot = await firestore.collection('users').doc(ownerId).get();
    final data = snapshot.data();
    if (data == null) return null;

    final geoPoint = data['location'] is GeoPoint
        ? data['location'] as GeoPoint
        : null;
    final ownerLat = _toDouble(data['locationLatitude']) ?? geoPoint?.latitude;
    final ownerLng =
        _toDouble(data['locationLongitude']) ?? geoPoint?.longitude;

    if (_isValidCoordinates(ownerLat, ownerLng)) {
      return (ownerLat!, ownerLng!);
    }
    return null;
  }

  bool _isNearCityCenter({
    required LatLng? cityCenter,
    required double propertyLat,
    required double propertyLng,
  }) {
    if (cityCenter == null) return false;
    if (!_isValidCoordinates(propertyLat, propertyLng)) return false;

    const distance = Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      cityCenter,
      LatLng(propertyLat, propertyLng),
    );

    // 45km captures city + nearby localities and reduces strict text dependency.
    return meters <= 45000;
  }
}

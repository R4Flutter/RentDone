import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/core/utils/city_key_normalizer.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

class TenantPropertyFirebaseService {
  final FirebaseFirestore firestore;

  const TenantPropertyFirebaseService(this.firestore);

  Stream<List<Property>> watchPublishedPropertiesForCity({
    required String city,
    LatLng? cityCenter,
  }) {
    final cityKey = normalizeCityKey(city);
    if (cityKey.isEmpty) {
      return const Stream<List<Property>>.empty();
    }

    final query = firestore
        .collection('properties')
        .where('isPublished', isEqualTo: true)
        .where('cityKey', isEqualTo: cityKey)
        .limit(400);

    return query.snapshots().asyncMap((snapshot) async {
      final byId = <String, Property>{};
      final ownerLocationCache = <String, (double, double)?>{};
      final ownerValidityCache = <String, bool>{};

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

        // Show only RentDone owners on tenant map.
        final ownerId = entity.ownerId.trim();
        if (ownerId.isEmpty) {
          continue;
        }
        final isKnownOwner = ownerValidityCache.containsKey(ownerId)
            ? ownerValidityCache[ownerId]!
            : await _isRentDoneOwner(ownerId);
        ownerValidityCache[ownerId] = isKnownOwner;
        if (!isKnownOwner) {
          continue;
        }

        // Ensure returned coordinates are still around selected city area.
        final isWithinSelectedArea = _isNearCityCenter(
          cityCenter: cityCenter,
          propertyLat: entity.lat,
          propertyLng: entity.lng,
          radiusMeters: 65000,
        );
        if (cityCenter != null && !isWithinSelectedArea) {
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
    const maxAttempts = 3;
    const retryDelays = <Duration>[
      Duration(milliseconds: 180),
      Duration(milliseconds: 520),
    ];

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final snapshot = await firestore
            .collection('users')
            .doc(ownerId)
            .get()
            .timeout(const Duration(seconds: 4));
        final data = snapshot.data();
        if (data == null) return null;

        final geoPoint = data['location'] is GeoPoint
            ? data['location'] as GeoPoint
            : null;
        final ownerLat =
            _toDouble(data['locationLatitude']) ?? geoPoint?.latitude;
        final ownerLng =
            _toDouble(data['locationLongitude']) ?? geoPoint?.longitude;

        if (_isValidCoordinates(ownerLat, ownerLng)) {
          return (ownerLat!, ownerLng!);
        }
        return null;
      } on FirebaseException catch (error, stackTrace) {
        developer.log(
          'Owner location lookup failed for owner=$ownerId on attempt $attempt.',
          name: 'tenant_map.location_lookup',
          error: error,
          stackTrace: stackTrace,
        );
      } on TimeoutException catch (error, stackTrace) {
        developer.log(
          'Owner location lookup timeout for owner=$ownerId on attempt $attempt.',
          name: 'tenant_map.location_lookup',
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(retryDelays[attempt - 1]);
      }
    }

    return null;
  }

  Future<bool> _isRentDoneOwner(String ownerId) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final ownerSnapshot = await firestore
            .collection('owners')
            .doc(ownerId)
            .get()
            .timeout(const Duration(seconds: 3));
        return ownerSnapshot.exists;
      } on FirebaseException catch (error, stackTrace) {
        developer.log(
          'Owner validation failed for owner=$ownerId on attempt $attempt.',
          name: 'tenant_map.owner_validation',
          error: error,
          stackTrace: stackTrace,
        );
      } on TimeoutException catch (error, stackTrace) {
        developer.log(
          'Owner validation timeout for owner=$ownerId on attempt $attempt.',
          name: 'tenant_map.owner_validation',
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
    }
    return false;
  }

  bool _isNearCityCenter({
    required LatLng? cityCenter,
    required double propertyLat,
    required double propertyLng,
    int radiusMeters = 45000,
  }) {
    if (cityCenter == null) return false;
    if (!_isValidCoordinates(propertyLat, propertyLng)) return false;

    const distance = Distance();
    final meters = distance.as(
      LengthUnit.Meter,
      cityCenter,
      LatLng(propertyLat, propertyLng),
    );

    return meters <= radiusMeters;
  }
}

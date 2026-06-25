import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rentdone/core/exceptions/security_exceptions.dart';
import 'package:rentdone/core/logging/app_logger.dart';
import 'package:rentdone/features/owner/owners_properties/data/models/property_dto.dart';

class PropertyFirebaseService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  PropertyFirebaseService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  String _requireOwnerId() {
    final ownerId = _auth.currentUser?.uid;
    if (ownerId == null || ownerId.isEmpty) {
      throw StateError('Owner session not found. Please sign in again.');
    }
    return ownerId;
  }

  Stream<List<PropertyDto>> watchAllProperties() {
    try {
      final ownerId = _auth.currentUser?.uid;
      if (ownerId == null || ownerId.isEmpty) {
        return const Stream<List<PropertyDto>>.empty();
      }

      return _db
          .collection('properties')
          .where('ownerId', isEqualTo: ownerId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => PropertyDto.fromMap({'id': doc.id, ...doc.data()}))
                .toList();
          });
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error watching all properties');
      return Stream.error(e);
    }
  }

  Stream<PropertyDto> watchProperty(String propertyId) {
    final ownerId = _auth.currentUser?.uid;
    
    try {
      return _db.collection('properties').doc(propertyId).snapshots().map((doc) {
        final data = doc.data();
        if (data == null) {
          throw StateError('Property $propertyId not found');
        }
        
        // SECURITY: Verify ownership
        final propOwnerId = (data['ownerId'] as String? ?? '').trim();
        if (ownerId == null || propOwnerId != ownerId) {
          throw UnauthorizedException('Unauthorized property access');
        }
        
        return PropertyDto.fromMap({'id': doc.id, ...data});
      });
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error watching property');
      return Stream.error(e);
    }
  }

  Future<void> addProperty(PropertyDto property) async {
    try {
      final ownerId = _requireOwnerId();
      final ownerCoordinates = await _readOwnerCoordinates(ownerId);
      final resolvedCoords = await _resolveCoordinates(
        ownerId: ownerId,
        propertyLat: property.lat,
        propertyLng: property.lng,
        cachedOwnerCoordinates: ownerCoordinates,
      );

      await _db.collection('properties').doc(property.id).set({
        ...property.toMap(),
        'lat': resolvedCoords.$1,
        'lng': resolvedCoords.$2,
        if (ownerCoordinates != null) 'ownerLocationLatitude': ownerCoordinates.$1,
        if (ownerCoordinates != null) 'ownerLocationLongitude': ownerCoordinates.$2,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error adding property');
      rethrow;
    }
  }

  Future<void> updateProperty(PropertyDto property) async {
    try {
      final ownerId = _requireOwnerId();
      
      // SECURITY: Verify ownership before update
      final doc = await _db.collection('properties').doc(property.id).get();
      if (!doc.exists) {
        throw StateError('Property not found');
      }
      if ((doc.data()?['ownerId'] as String? ?? '').trim() != ownerId) {
        throw UnauthorizedException('Unauthorized property update attempt');
      }

      final ownerCoordinates = await _readOwnerCoordinates(ownerId);
      final resolvedCoords = await _resolveCoordinates(
        ownerId: ownerId,
        propertyLat: property.lat,
        propertyLng: property.lng,
        cachedOwnerCoordinates: ownerCoordinates,
      );

      await _db.collection('properties').doc(property.id).update({
        ...property.toMap(),
        'lat': resolvedCoords.$1,
        'lng': resolvedCoords.$2,
        if (ownerCoordinates != null) 'ownerLocationLatitude': ownerCoordinates.$1,
        if (ownerCoordinates != null) 'ownerLocationLongitude': ownerCoordinates.$2,
        'ownerId': ownerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error updating property');
      rethrow;
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    try {
      try {
        final callable = _functions.httpsCallable('deleteOwnerPropertyCascade');
        await callable.call(<String, dynamic>{'propertyId': propertyId});
        return;
      } on FirebaseFunctionsException catch (error) {
        const terminalCodes = {
          'permission-denied',
          'unauthenticated',
          'invalid-argument',
        };
        if (terminalCodes.contains(error.code)) {
          throw StateError(error.message ?? 'Property delete not allowed.');
        }
        AppLogger.warning('Cascade delete failed, falling back to client-side delete: ${error.message}');
      }

      await _deletePropertyClientSide(propertyId);
    } catch (e, stack) {
      AppLogger.exception(e, stackTrace: stack, context: 'Error deleting property');
      rethrow;
    }
  }

  Future<void> _deletePropertyClientSide(String propertyId) async {
    final ownerId = _requireOwnerId();
    final propertyRef = _db.collection('properties').doc(propertyId);
    final propertyDoc = await propertyRef.get();

    if (!propertyDoc.exists) {
      return;
    }

    final propertyOwnerId = propertyDoc.data()?['ownerId']?.toString();
    if (propertyOwnerId != null &&
        propertyOwnerId.isNotEmpty &&
        propertyOwnerId != ownerId) {
      throw StateError('You are not allowed to delete this property.');
    }

    final tenantsSnapshot = await _db
        .collection('tenants')
        .where('propertyId', isEqualTo: propertyId)
        .get();

    const chunkSize = 400;
    for (
      var start = 0;
      start < tenantsSnapshot.docs.length;
      start += chunkSize
    ) {
      final end = (start + chunkSize) > tenantsSnapshot.docs.length
          ? tenantsSnapshot.docs.length
          : start + chunkSize;
      final batch = _db.batch();
      for (final doc in tenantsSnapshot.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await propertyRef.delete();
  }

  Future<(double, double)?> _readOwnerCoordinates(String ownerId) async {
    final snapshot = await _db.collection('users').doc(ownerId).get();
    final data = snapshot.data();
    if (data == null) return null;

    final geoPoint =
        data['location'] is GeoPoint ? data['location'] as GeoPoint : null;

    final lat = _toDouble(data['locationLatitude']) ?? geoPoint?.latitude;
    final lng = _toDouble(data['locationLongitude']) ?? geoPoint?.longitude;

    if (_isValidCoordinates(lat, lng)) {
      return (lat!, lng!);
    }
    return null;
  }

  Future<(double, double)> _resolveCoordinates({
    required String ownerId,
    required double propertyLat,
    required double propertyLng,
    (double, double)? cachedOwnerCoordinates,
  }) async {
    if (_isValidCoordinates(propertyLat, propertyLng)) {
      return (propertyLat, propertyLng);
    }

    final ownerCoordinates =
        cachedOwnerCoordinates ?? await _readOwnerCoordinates(ownerId);
    if (ownerCoordinates != null) {
      return ownerCoordinates;
    }

    return (propertyLat, propertyLng);
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _isValidCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0.0 && lng == 0.0);
  }
}

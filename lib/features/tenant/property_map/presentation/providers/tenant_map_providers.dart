import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/tenant/property_map/data/services/nominatim_geocoding_service.dart';
import 'package:rentdone/features/tenant/property_map/data/services/tenant_property_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

/// ✅ Notifier-based city state (avoids StateProvider underline issues)
class SelectedCityNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setCity(String city) {
    state = city.trim();
  }

  void clear() {
    state = '';
  }
}

final selectedCityProvider = NotifierProvider<SelectedCityNotifier, String>(
  SelectedCityNotifier.new,
);

final nominatimGeocodingServiceProvider = Provider<NominatimGeocodingService>(
  (ref) => const NominatimGeocodingService(),
);

final tenantPropertyFirebaseServiceProvider =
    Provider<TenantPropertyFirebaseService>((ref) {
      return TenantPropertyFirebaseService(ref.watch(firestoreProvider));
    });

final cityCenterProvider = FutureProvider<LatLng>((ref) async {
  final city = ref.watch(selectedCityProvider).trim();
  if (city.isEmpty) {
    throw Exception('No city selected');
  }

  final service = ref.watch(nominatimGeocodingServiceProvider);
  return service.geocodeCity(city: city);
});

final tenantCityPropertiesProvider = StreamProvider<List<Property>>((ref) {
  final city = ref.watch(selectedCityProvider).trim();
  final service = ref.watch(tenantPropertyFirebaseServiceProvider);
  final centerAsync = ref.watch(cityCenterProvider);
  final cityCenter = centerAsync.when<LatLng?>(
    data: (value) => value,
    loading: () => null,
    error: (_, _) => null,
  );
  return service.watchPublishedPropertiesForCity(
    city: city,
    cityCenter: cityCenter,
  );
});

class OwnerMapCardData {
  final String name;
  final String phoneNumber;
  final String locationAddress;

  const OwnerMapCardData({
    required this.name,
    required this.phoneNumber,
    required this.locationAddress,
  });
}

final ownerMapCardProvider = FutureProvider.autoDispose
    .family<OwnerMapCardData?, String>((ref, ownerId) async {
      final trimmedOwnerId = ownerId.trim();
      if (trimmedOwnerId.isEmpty) return null;

      final firestore = ref.watch(firestoreProvider);
      final usersData = await _readDocDataWithRetry(
        firestore: firestore,
        collection: 'users',
        docId: trimmedOwnerId,
      );
      final ownersData = await _readDocDataWithRetry(
        firestore: firestore,
        collection: 'owners',
        docId: trimmedOwnerId,
      );

      final name = _pickFirstText([
        ownersData?['ownerName'],
        ownersData?['fullName'],
        ownersData?['name'],
        usersData?['ownerName'],
        usersData?['fullName'],
        usersData?['name'],
      ]);
      final phone = _pickFirstText([
        ownersData?['phoneNumber'],
        ownersData?['phone'],
        usersData?['phoneNumber'],
        usersData?['phone'],
      ]);
      final location = _pickFirstText([
        usersData?['locationAddress'],
        ownersData?['locationAddress'],
        ownersData?['address'],
      ]);

      if (name.isEmpty && phone.isEmpty && location.isEmpty) {
        return null;
      }

      return OwnerMapCardData(
        name: name,
        phoneNumber: phone,
        locationAddress: location,
      );
    });

Future<Map<String, dynamic>?> _readDocDataWithRetry({
  required FirebaseFirestore firestore,
  required String collection,
  required String docId,
}) async {
  const maxAttempts = 3;
  const delays = <Duration>[
    Duration(milliseconds: 160),
    Duration(milliseconds: 420),
  ];

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final snapshot = await firestore
          .collection(collection)
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 4));
      return snapshot.data();
    } on FirebaseException catch (error, stackTrace) {
      developer.log(
        'Firestore read failed for $collection/$docId on attempt $attempt.',
        name: 'tenant_map.owner_profile',
        error: error,
        stackTrace: stackTrace,
      );
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'Firestore read timeout for $collection/$docId on attempt $attempt.',
        name: 'tenant_map.owner_profile',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (attempt < maxAttempts) {
      await Future<void>.delayed(delays[attempt - 1]);
    }
  }

  return null;
}

String _pickFirstText(List<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

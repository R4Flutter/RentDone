import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/features/tenant/property_map/data/services/nominatim_geocoding_service.dart';
import 'package:rentdone/features/tenant/property_map/data/services/tenant_property_firebase_service.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';

/// Holds the currently selected city in memory.
final selectedCityProvider = StateProvider<String>((ref) => '');

final nominatimGeocodingServiceProvider =
    Provider<NominatimGeocodingService>((ref) {
  return const NominatimGeocodingService();
});

final tenantPropertyFirebaseServiceProvider =
    Provider<TenantPropertyFirebaseService>((ref) {
  return TenantPropertyFirebaseService(ref.watch(firestoreProvider));
});

/// Converts city name -> LatLng center (FutureProvider)
final cityCenterProvider = FutureProvider<LatLng>((ref) async {
  final city = ref.watch(selectedCityProvider);
  if (city.trim().isEmpty) {
    throw Exception('No city selected');
  }

  final service = ref.watch(nominatimGeocodingServiceProvider);
  return service.geocodeCity(city: city);
});

/// Watches Firestore -> list of properties for that city (StreamProvider)
final tenantCityPropertiesProvider = StreamProvider<List<Property>>((ref) {
  final city = ref.watch(selectedCityProvider);
  final service = ref.watch(tenantPropertyFirebaseServiceProvider);

  return service.watchPublishedPropertiesForCity(city: city);
});
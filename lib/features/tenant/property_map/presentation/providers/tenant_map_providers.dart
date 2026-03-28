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

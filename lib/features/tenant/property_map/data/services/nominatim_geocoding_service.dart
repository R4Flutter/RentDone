import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimGeocodingService {
  const NominatimGeocodingService();

  static const Duration _requestTimeout = Duration(seconds: 8);

  // Known major-city fallback keeps the map usable if geocoding API is unavailable.
  static const Map<String, LatLng> _knownCityCenters = {
    'mumbai': LatLng(19.0760, 72.8777),
    'delhi': LatLng(28.6139, 77.2090),
    'new delhi': LatLng(28.6139, 77.2090),
    'bengaluru': LatLng(12.9716, 77.5946),
    'bangalore': LatLng(12.9716, 77.5946),
    'hyderabad': LatLng(17.3850, 78.4867),
    'chennai': LatLng(13.0827, 80.2707),
    'kolkata': LatLng(22.5726, 88.3639),
    'pune': LatLng(18.5204, 73.8567),
    'ahmedabad': LatLng(23.0225, 72.5714),
    'jaipur': LatLng(26.9124, 75.7873),
    'surat': LatLng(21.1702, 72.8311),
    'lucknow': LatLng(26.8467, 80.9462),
    'kanpur': LatLng(26.4499, 80.3319),
    'nagpur': LatLng(21.1458, 79.0882),
    'indore': LatLng(22.7196, 75.8577),
    'bhopal': LatLng(23.2599, 77.4126),
    'patna': LatLng(25.5941, 85.1376),
    'kochi': LatLng(9.9312, 76.2673),
    'thiruvananthapuram': LatLng(8.5241, 76.9366),
  };

  Future<LatLng> geocodeCity({required String city}) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      throw Exception('City name is empty');
    }

    final normalized = _normalizeCity(trimmed);
    final knownCenter = _knownCityCenters[normalized];

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{'q': trimmed, 'format': 'json', 'limit': '1'},
    );

    http.Response res;
    try {
      res = await http
          .get(
            uri,
            headers: const {
              // Nominatim requires a User-Agent identifying your app.
              'User-Agent': 'rentdone/1.0 (tenant-map)',
              'Accept': 'application/json',
            },
          )
          .timeout(_requestTimeout);
    } catch (_) {
      if (knownCenter != null) return knownCenter;
      throw Exception(
        'Could not geocode city. Please check internet and try again.',
      );
    }

    if (res.statusCode != 200) {
      if (knownCenter != null) return knownCenter;
      throw Exception('Geocoding service unavailable (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) {
      if (knownCenter != null) return knownCenter;
      throw Exception('City not found');
    }

    final first = decoded.first;
    final lat = double.tryParse((first['lat'] ?? '').toString()) ?? 0.0;
    final lon = double.tryParse((first['lon'] ?? '').toString()) ?? 0.0;

    if (lat == 0.0 && lon == 0.0) {
      if (knownCenter != null) return knownCenter;
      throw Exception('Invalid geocode result');
    }

    return LatLng(lat, lon);
  }

  String _normalizeCity(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

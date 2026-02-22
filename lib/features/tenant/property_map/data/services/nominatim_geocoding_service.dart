import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NominatimGeocodingService {
  const NominatimGeocodingService();

  Future<LatLng> geocodeCity({
    required String city,
  }) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      throw Exception('City name is empty');
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': trimmed,
        'format': 'json',
        'limit': '1',
      },
    );

    final res = await http.get(
      uri,
      headers: const {
        // Nominatim requires a User-Agent identifying your app
        'User-Agent': 'rentdone/1.0 (tenant-map)',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Geocoding failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) {
      throw Exception('City not found');
    }

    final first = decoded.first;
    final lat = double.tryParse((first['lat'] ?? '').toString()) ?? 0.0;
    final lon = double.tryParse((first['lon'] ?? '').toString()) ?? 0.0;

    if (lat == 0.0 && lon == 0.0) {
      throw Exception('Invalid geocode result');
    }

    return LatLng(lat, lon);
  }
}
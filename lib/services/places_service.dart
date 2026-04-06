import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/restaurants.dart';

class PlacesService {
  // No API key needed — uses OpenStreetMap (Overpass) + OSRM (free routing)
  PlacesService({String apiKey = ''});

  /// Nearby restaurants via Overpass API (OpenStreetMap)
  Future<List<RestaurantModel>> getNearbyRestaurants({
    required double lat,
    required double lng,
    int radius = 5000,
    String? keyword,
  }) async {
    final nameFilter = (keyword != null && keyword.isNotEmpty)
        ? '["name"~"${keyword.replaceAll('"', '')}",i]'
        : '';

    final query = '''
[out:json][timeout:25];
(
  node["amenity"="restaurant"]$nameFilter(around:$radius,$lat,$lng);
  way["amenity"="restaurant"]$nameFilter(around:$radius,$lat,$lng);
);
out body center 60;
''';

    try {
      final response = await http.post(
        Uri.https('overpass-api.de', '/api/interpreter'),
        body: {'data': query},
      );
      debugPrint('Overpass HTTP ${response.statusCode}');
      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];
      debugPrint('Overpass found: ${elements.length} elements');

      return elements
          .where((e) => e['tags']?['name'] != null)
          .map((e) =>
              RestaurantModel.fromOverpassJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Overpass error: $e');
      return [];
    }
  }

  /// Text search via Overpass name filter
  Future<List<RestaurantModel>> searchRestaurants({
    required String query,
    double? lat,
    double? lng,
    int radius = 5000,
  }) async {
    final safe = query.replaceAll('"', '');
    final area =
        (lat != null && lng != null) ? '(around:$radius,$lat,$lng)' : '';

    final overpassQuery = '''
[out:json][timeout:25];
(
  node["amenity"="restaurant"]["name"~"$safe",i]$area;
  way["amenity"="restaurant"]["name"~"$safe",i]$area;
);
out body center 20;
''';

    try {
      final response = await http.post(
        Uri.https('overpass-api.de', '/api/interpreter'),
        body: {'data': overpassQuery},
      );
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];
      return elements
          .map((e) =>
              RestaurantModel.fromOverpassJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Overpass search error: $e');
      return [];
    }
  }

  /// Fetch full details for a single OSM element
  Future<RestaurantModel?> getPlaceDetails(String osmId) async {
    if (osmId.isEmpty) return null;
    String nodeType = 'node';
    String numericId = osmId;
    if (osmId.contains('/')) {
      final parts = osmId.split('/');
      nodeType = parts[0];
      numericId = parts[1];
    }
    final q = '[out:json];$nodeType($numericId);out body;';
    try {
      final response = await http.post(
        Uri.https('overpass-api.de', '/api/interpreter'),
        body: {'data': q},
      );
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      final elements = data['elements'] as List<dynamic>? ?? [];
      if (elements.isEmpty) return null;
      return RestaurantModel.fromOverpassJson(
          elements.first as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Overpass detail error: $e');
      return null;
    }
  }

  /// Directions via OSRM (free, no API key)
  Future<DirectionsResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async {
    final profile = mode == 'walking'
        ? 'foot'
        : mode == 'bicycling'
            ? 'bike'
            : 'driving';

    // OSRM expects lon,lat order
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/$profile/$originLng,$originLat;$destLng,$destLat',
      {'overview': 'full', 'geometries': 'polyline'},
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body);
      debugPrint('OSRM code: ${data['code']}');
      if (data['code'] != 'Ok') return null;

      final route = data['routes'][0];
      final distM = (route['distance'] as num).toInt();
      final durS = (route['duration'] as num).toInt();

      final distText = distM >= 1000
          ? '${(distM / 1000).toStringAsFixed(1)} km'
          : '$distM m';
      final durMins = (durS / 60).round();
      final durText = durMins >= 60
          ? '${durMins ~/ 60} giờ ${durMins % 60} phút'
          : '$durMins phút';

      return DirectionsResult(
        encodedPolyline: route['geometry'] as String,
        distanceText: distText,
        durationText: durText,
        distanceMeters: distM,
        durationSeconds: durS,
        startAddress: '',
        endAddress: '',
      );
    } catch (e) {
      debugPrint('OSRM error: $e');
      return null;
    }
  }
}

class DirectionsResult {
  final String encodedPolyline;
  final String distanceText;
  final String durationText;
  final int distanceMeters;
  final int durationSeconds;
  final String startAddress;
  final String endAddress;

  DirectionsResult({
    required this.encodedPolyline,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startAddress,
    required this.endAddress,
  });
}

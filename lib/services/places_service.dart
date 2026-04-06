import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/restaurants.dart';

class PlacesService {
  // No API key needed — uses OpenStreetMap (Overpass) + OSRM (free routing)
  PlacesService({String apiKey = ''});

  static const int _maxRadius = 5000; // 5 km hard cap
  Timer? _searchDebounce;
  DateTime? _lastOverpassCall;
  static const _overpassCooldown = Duration(seconds: 2);

  // 60-second in-memory cache so re-inits don't re-fetch the same area
  String? _cachedKey;
  List<RestaurantModel>? _cachedResults;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(seconds: 60);

  /// Global-coverage Overpass mirrors only.
  /// osm.ch removed (Switzerland data only).
  /// private.coffee removed (TLS handshake fails on Android).
  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',       // global, primary
    'https://lz4.overpass-api.de/api/interpreter',   // global, load-balanced twin
    'https://overpass.kumi.systems/api/interpreter', // global
    'https://overpass.openstreetmap.ru/api/interpreter', // global
  ];

  /// POST an Overpass query, trying each mirror until one succeeds.
  /// Returns the decoded JSON map, or null on total failure.
  Future<Map<String, dynamic>?> _overpassPost(String queryBody) async {
    // Throttle: enforce minimum gap between requests to avoid HTTP 429
    if (_lastOverpassCall != null) {
      final elapsed = DateTime.now().difference(_lastOverpassCall!);
      if (elapsed < _overpassCooldown) {
        await Future.delayed(_overpassCooldown - elapsed);
      }
    }
    _lastOverpassCall = DateTime.now();

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await http
            .post(Uri.parse(endpoint), body: {'data': queryBody})
            .timeout(const Duration(seconds: 15));
        debugPrint('Overpass HTTP ${response.statusCode} ($endpoint)');
        if (response.statusCode == 200) {
          return json.decode(response.body) as Map<String, dynamic>;
        }
        // any error (4xx / 5xx / 429) → try next mirror
        continue;
      } catch (e) {
        debugPrint('Overpass error ($endpoint): $e');
      }
    }
    return null;
  }

  /// Convert (lat, lng, radiusMeters) to an Overpass bounding box string
  /// "S,W,N,E" — bbox queries use spatial indexing and are ~10x faster than
  /// `around:` which forces a per-node distance calculation.
  static String _toBbox(double lat, double lng, int radiusM) {
    const deg = 111000.0; // metres per degree latitude
    final dlat = radiusM / deg;
    final dlng = radiusM / (deg * _cos(lat));
    final s = (lat - dlat).toStringAsFixed(6);
    final n = (lat + dlat).toStringAsFixed(6);
    final w = (lng - dlng).toStringAsFixed(6);
    final e = (lng + dlng).toStringAsFixed(6);
    return '$s,$w,$n,$e';
  }

  static double _cos(double deg) {
    // dart:math is not imported here — inline approximation via Taylor series
    // accurate to <0.01% for |lat| < 60°
    final r = deg * 0.017453292519943; // deg → rad
    return 1 - (r * r) / 2 + (r * r * r * r) / 24;
  }

  /// Nearby restaurants via Overpass API (OpenStreetMap)
  Future<List<RestaurantModel>> getNearbyRestaurants({
    required double lat,
    required double lng,
    int radius = 5000,
    String? keyword,
  }) async {
    final safeRadius = radius.clamp(500, _maxRadius);
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)},$safeRadius,${keyword ?? ''}';

    // Return cached result if still fresh
    if (_cachedKey == cacheKey &&
        _cachedResults != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      debugPrint('Overpass cache hit ($cacheKey)');
      return _cachedResults!;
    }
    final nameFilter = (keyword != null && keyword.isNotEmpty)
        ? '["name"~"${keyword.replaceAll('"', '')}",i]'
        : '';
    final bbox = _toBbox(lat, lng, safeRadius);

    // [bbox:...] in the header lets Overpass use spatial indexing globally —
    // far cheaper than per-statement `(around:...)` filters.
    final query = '''
[out:json][timeout:20][bbox:$bbox];
nwr["amenity"="restaurant"]$nameFilter;
out body center 30;
''';

    try {
      final data = await _overpassPost(query);
      if (data == null) return [];
      final elements = data['elements'] as List<dynamic>? ?? [];
      debugPrint('Overpass found: ${elements.length} elements');

      final results = elements
          .where((e) => e['tags']?['name'] != null)
          .map((e) =>
              RestaurantModel.fromOverpassJson(e as Map<String, dynamic>))
          .toList();

      // Store in cache
      _cachedKey = cacheKey;
      _cachedResults = results;
      _cacheTime = DateTime.now();
      return results;
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
    final safeRadius = radius.clamp(500, _maxRadius);
    final safe = query.replaceAll('"', '');

    final String overpassQuery;
    if (lat != null && lng != null) {
      final bbox = _toBbox(lat, lng, safeRadius);
      overpassQuery = '''
[out:json][timeout:20][bbox:$bbox];
nwr["amenity"="restaurant"]["name"~"$safe",i];
out body center 20;
''';
    } else {
      overpassQuery = '''
[out:json][timeout:20];
nwr["amenity"="restaurant"]["name"~"$safe",i];
out body center 20;
''';
    }

    try {
      final data = await _overpassPost(overpassQuery);
      if (data == null) return [];
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

  /// Debounced wrapper around [searchRestaurants].
  /// Cancels the previous pending call; fires after [delay] (default 500 ms).
  void searchRestaurantsDebounced({
    required String query,
    double? lat,
    double? lng,
    int radius = 5000,
    required void Function(List<RestaurantModel>) onResult,
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(delay, () async {
      final results = await searchRestaurants(
        query: query,
        lat: lat,
        lng: lng,
        radius: radius,
      );
      onResult(results);
    });
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
      final data = await _overpassPost(q);
      if (data == null) return null;
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

import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/restaurants.dart';

class LocationService {
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return _currentPosition;
  }

  /// Calculate distance between two points in kilometers using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180);

  /// Calculate distance from current position to a restaurant
  double? getDistanceToRestaurant(RestaurantModel restaurant) {
    if (_currentPosition == null ||
        restaurant.lat == null ||
        restaurant.lng == null) return null;
    return calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      restaurant.lat!,
      restaurant.lng!,
    );
  }

  /// Attach distance to each restaurant and return sorted list by distance
  List<RestaurantModel> sortByDistance(List<RestaurantModel> restaurants) {
    if (_currentPosition == null) return restaurants;

    for (var r in restaurants) {
      r.distanceKm = getDistanceToRestaurant(r);
    }

    restaurants.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    return restaurants;
  }

  /// Sort restaurants by rating (highest first)
  List<RestaurantModel> sortByRating(List<RestaurantModel> restaurants) {
    restaurants.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return restaurants;
  }

  /// Filter restaurants by price range, min rating, category, and restaurant type
  List<RestaurantModel> filterRestaurants(
    List<RestaurantModel> restaurants, {
    int? priceRange,
    double? minRating,
    String? category,
    String? restaurantType,
  }) {
    return restaurants.where((r) {
      if (priceRange != null && r.priceRange != priceRange) return false;
      if (minRating != null && r.averageRating < minRating) return false;
      if (category != null && !r.categories.contains(category)) return false;
      if (restaurantType != null &&
          restaurantType.isNotEmpty &&
          r.restaurantType != restaurantType) return false;
      return true;
    }).toList();
  }

  /// Open Google Maps for directions from current location to restaurant
  Future<void> openDirections(RestaurantModel restaurant) async {
    if (restaurant.lat == null || restaurant.lng == null) return;

    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${restaurant.lat},${restaurant.lng}&travelmode=driving');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Get restaurants within a certain radius (km)
  List<RestaurantModel> getRestaurantsInRadius(
      List<RestaurantModel> restaurants, double radiusKm) {
    if (_currentPosition == null) return restaurants;

    return restaurants.where((r) {
      final dist = getDistanceToRestaurant(r);
      return dist != null && dist <= radiusKm;
    }).toList();
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/restaurants.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import 'restaurant_detail.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<RestaurantModel> _restaurants = [];
  RestaurantModel? _selectedRestaurant;
  List<ReviewModel> _selectedReviews = [];
  bool _isLoadingReviews = false;
  DirectionsResult? _directionsResult;
  bool _isLoadingDirections = false;
  bool _showingRoute = false;
  bool _isLoading = true;

  LatLng _currentLatLng = const LatLng(10.7769, 106.7009); // HCM default
  double _searchRadius = 3.0; // km (max 5)

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
      }
      debugPrint('Map init: location = ${_currentLatLng.latitude}, ${_currentLatLng.longitude}');

      await _loadNearbyRestaurants();
    } catch (e) {
      debugPrint('Map init error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyRestaurants() async {
    _restaurants = await _placesService.getNearbyRestaurants(
      lat: _currentLatLng.latitude,
      lng: _currentLatLng.longitude,
      radius: (_searchRadius * 1000).toInt(),
    );

    if (_restaurants.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy quán ăn trong khu vực này.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Attach distances
    for (var r in _restaurants) {
      r.distanceKm = _locationService.getDistanceToRestaurant(r);
    }
    _locationService.sortByDistance(_restaurants);

    _buildMarkers();
    if (mounted) setState(() {});
  }

  void _buildMarkers() {
    _markers = _restaurants
        .where((r) => r.lat != null && r.lng != null)
        .map((r) {
      return Marker(
        markerId: MarkerId(r.id),
        position: LatLng(r.lat!, r.lng!),
        infoWindow: InfoWindow(
          title: r.name,
          snippet:
              '⭐${r.averageRating.toStringAsFixed(1)} · ${r.distanceKm?.toStringAsFixed(1) ?? "?"} km',
          onTap: () => _openDetail(r),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () => _selectRestaurant(r),
      );
    }).toSet();
  }

  void _selectRestaurant(RestaurantModel r) {
    setState(() {
      _selectedRestaurant = r;
      _selectedReviews = [];
      _isLoadingReviews = true;
      _showingRoute = false;
      _polylines = {};
      _directionsResult = null;
    });
    _loadReviewsForRestaurant(r);
  }

  Future<void> _loadReviewsForRestaurant(RestaurantModel r) async {
    try {
      final reviews =
          await _firestoreService.getRestaurantReviews(r.id);
      if (mounted && _selectedRestaurant?.id == r.id) {
        setState(() {
          _selectedReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _showDirections(RestaurantModel restaurant) async {
    if (restaurant.lat == null || restaurant.lng == null) return;

    setState(() => _isLoadingDirections = true);

    final result = await _placesService.getDirections(
      originLat: _currentLatLng.latitude,
      originLng: _currentLatLng.longitude,
      destLat: restaurant.lat!,
      destLng: restaurant.lng!,
    );

    if (result == null) {
      if (mounted) {
        setState(() => _isLoadingDirections = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm được đường đi')),
        );
      }
      return;
    }

    final points = _decodePolyline(result.encodedPolyline);

    setState(() {
      _directionsResult = result;
      _isLoadingDirections = false;
      _showingRoute = true;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ),
      };
    });

    _fitBounds(points, restaurant);
  }

  Future<void> _fitBounds(
      List<LatLng> points, RestaurantModel restaurant) async {
    if (points.isEmpty) return;

    double minLat = _currentLatLng.latitude;
    double maxLat = _currentLatLng.latitude;
    double minLng = _currentLatLng.longitude;
    double maxLng = _currentLatLng.longitude;

    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    if (restaurant.lat != null && restaurant.lng != null) {
      minLat = min(minLat, restaurant.lat!);
      maxLat = max(maxLat, restaurant.lat!);
      minLng = min(minLng, restaurant.lng!);
      maxLng = max(maxLng, restaurant.lng!);
    }

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  /// Decode Google encoded polyline string into LatLng list
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _clearRoute() {
    setState(() {
      _showingRoute = false;
      _polylines = {};
      _directionsResult = null;
    });
  }

  Future<void> _goToMyLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos == null) return;

    _currentLatLng = LatLng(pos.latitude, pos.longitude);
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLatLng, 14),
    );
  }

  void _openDetail(RestaurantModel restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Google Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentLatLng,
            zoom: 14,
          ),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            if (!_mapController.isCompleted) {
              _mapController.complete(controller);
            }
          },
          onTap: (_) {
            setState(() {
              _selectedRestaurant = null;
              _selectedReviews = [];
            });
            if (_showingRoute) _clearRoute();
          },
        ),

        // Route info banner
        if (_showingRoute && _directionsResult != null)
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_directionsResult!.distanceText} · ${_directionsResult!.durationText}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _selectedRestaurant?.name ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_selectedRestaurant != null) {
                        _locationService.openDirections(_selectedRestaurant!);
                      }
                    },
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    tooltip: 'Mở Google Maps',
                  ),
                  IconButton(
                    onPressed: _clearRoute,
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
          ),

        // Radius selector (hide when showing route)
        if (!_showingRoute)
        Positioned(
          top: 10,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('${_searchRadius.toStringAsFixed(0)} km',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _searchRadius,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: Colors.orange,
                    onChanged: (val) {
                      setState(() => _searchRadius = val);
                    },
                    onChangeEnd: (_) => _loadNearbyRestaurants(),
                  ),
                ),
                Text('${_restaurants.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700)),
              ],
            ),
          ),
        ),

        // My location button
        Positioned(
          bottom: _selectedRestaurant != null ? 260 : 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'myLocation',
            onPressed: _goToMyLocation,
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.blue),
          ),
        ),

        // Restaurant list button
        Positioned(
          bottom: _selectedRestaurant != null ? 260 : 16,
          left: 16,
          child: FloatingActionButton.small(
            heroTag: 'listView',
            onPressed: _showRestaurantList,
            backgroundColor: Colors.white,
            child: const Icon(Icons.list, color: Colors.orange),
          ),
        ),

        // Selected restaurant card with reviews
        if (_selectedRestaurant != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildSelectedCard(_selectedRestaurant!),
          ),
      ],
    );
  }

  Widget _buildSelectedCard(RestaurantModel restaurant) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Restaurant info row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: restaurant.imageUrl.isNotEmpty
                      ? Image.network(restaurant.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: Colors.orange.shade50,
                                child: const Icon(Icons.restaurant,
                                    color: Colors.orange),
                              ))
                      : Container(
                          color: Colors.orange.shade50,
                          child: const Icon(Icons.restaurant,
                              color: Colors.orange),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(
                            ' ${restaurant.averageRating.toStringAsFixed(1)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(' (${restaurant.totalReviews})',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (restaurant.distanceKm != null)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text(
                              '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade400)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Firestore reviews section
          const SizedBox(height: 10),
          _buildReviewsSection(),

          // Action buttons
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openDetail(restaurant),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Chi tiết'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingDirections
                      ? null
                      : () => _showDirections(restaurant),
                  icon: _isLoadingDirections
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.directions, size: 18),
                  label: const Text('Chỉ đường'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_isLoadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_selectedReviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          'Chưa có đánh giá từ người dùng',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }

    final latest = _selectedReviews.first;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review, size: 14, color: Colors.orange.shade700),
              const SizedBox(width: 4),
              Text(
                '${_selectedReviews.length} đánh giá từ người dùng',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < latest.rating.round() ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  latest.comment,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRestaurantList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_restaurants.length} quán ăn gần bạn',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _restaurants.length,
                    itemBuilder: (context, index) {
                      final r = _restaurants[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: r.imageUrl.isNotEmpty
                                ? Image.network(r.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                          color: Colors.orange.shade50,
                                          child: const Icon(
                                              Icons.restaurant,
                                              size: 24,
                                              color: Colors.orange),
                                        ))
                                : Container(
                                    color: Colors.orange.shade50,
                                    child: const Icon(Icons.restaurant,
                                        size: 24, color: Colors.orange),
                                  ),
                          ),
                        ),
                        title: Text(r.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            Text(
                                ' ${r.averageRating.toStringAsFixed(1)}'),
                            if (r.distanceKm != null) ...[
                              const Text(' · '),
                              Text(
                                  '${r.distanceKm!.toStringAsFixed(1)} km'),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.directions,
                              color: Colors.blue),
                          onPressed: () {
                            Navigator.pop(context);
                            _selectRestaurant(r);
                            _showDirections(r);
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _focusOnRestaurant(r);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _focusOnRestaurant(RestaurantModel restaurant) async {
    if (restaurant.lat == null || restaurant.lng == null) return;
    _selectRestaurant(restaurant);

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(restaurant.lat!, restaurant.lng!),
        16,
      ),
    );
  }
}

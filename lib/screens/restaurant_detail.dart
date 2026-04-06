import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/restaurants.dart';
import '../models/reviews.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';

const String _kApiKey = 'place_holder_apikey';

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService();
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  RestaurantModel? _detailedRestaurant;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadReviews();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await _placesService.getPlaceDetails(
          widget.restaurant.googlePlaceId);
      if (details != null && mounted) {
        setState(() => _detailedRestaurant = details);
      }
    } catch (e) {
      debugPrint('Error loading place details: $e');
    }
  }

  Future<void> _loadReviews() async {
    try {
      _reviews =
          await _firestoreService.getRestaurantReviews(widget.restaurant.id);
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _detailedRestaurant ?? widget.restaurant;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(r.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              background: r.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: r.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.orange.shade100,
                        child: const Icon(Icons.restaurant,
                            size: 80, color: Colors.orange),
                      ),
                    )
                  : Container(
                      color: Colors.orange.shade100,
                      child: const Icon(Icons.restaurant,
                          size: 80, color: Colors.orange),
                    ),
            ),
            backgroundColor: Colors.orange.shade700,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating & Price
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(r.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text(' (${r.totalReviews})',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          List.filled(r.priceRange, '₫').join(),
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                      const Spacer(),
                      if (r.distanceKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.directions_walk,
                                  size: 16, color: Colors.blue.shade400),
                              const SizedBox(width: 4),
                              Text('${r.distanceKm!.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Categories
                  if (r.categories.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: r.categories
                          .map((tag) => Chip(
                                label: Text(tag,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.orange.shade50,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Address
                  _infoRow(Icons.location_on, r.address),
                  if (r.phone.isNotEmpty) _infoRow(Icons.phone, r.phone),
                  if (r.openingHours.isNotEmpty)
                    _infoRow(Icons.access_time, r.openingHours),
                  if (r.restaurantType.isNotEmpty)
                    _infoRow(Icons.restaurant_menu, r.restaurantType),

                  // Description
                  if (r.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(r.description,
                        style: TextStyle(
                            color: Colors.grey.shade700, height: 1.4)),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _locationService.openDirections(r),
                          icon: const Icon(Icons.directions),
                          label: const Text('Chỉ đường'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Mini map
                  if (r.lat != null && r.lng != null) ...[
                    const SizedBox(height: 20),
                    const Text('Vị trí',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(r.lat!, r.lng!),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: MarkerId(r.id),
                              position: LatLng(r.lat!, r.lng!),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueOrange),
                            ),
                          },
                          zoomControlsEnabled: false,
                          scrollGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          myLocationButtonEnabled: false,
                          liteModeEnabled: true,
                        ),
                      ),
                    ),
                  ],

                  // Reviews section
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Đánh giá',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_reviews.length} reviews',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Reviews list
          _isLoadingReviews
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : _reviews.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Chưa có đánh giá nào',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildReviewCard(_reviews[index]),
                        childCount: _reviews.length,
                      ),
                    ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stars
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(review.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (review.createdAt != null)
                Text(
                  '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}',
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Comment
          if (review.comment.isNotEmpty)
            Text(review.comment,
                style: const TextStyle(height: 1.3, fontSize: 14)),
          // Tags
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: review.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tag,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700)),
                      ))
                  .toList(),
            ),
          ],
          // Photos
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: review.photoUrls[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

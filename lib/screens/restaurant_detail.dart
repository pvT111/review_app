import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurants.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import 'package:review_app/widget/review_list_widget.dart';
import 'package:review_app/screens/add_review_screen.dart';
import 'package:review_app/screens/my_restaurant_management_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService();
  RestaurantModel? _detailedRestaurant;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await _placesService.getPlaceDetails(widget.restaurant.googlePlaceId);
      if (details != null && mounted) {
        setState(() => _detailedRestaurant = details);
      }
    } catch (e) {
      debugPrint('Error loading place details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _detailedRestaurant ?? widget.restaurant;
    final String cleanId = r.id.replaceAll('/', '_');

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').doc(cleanId).snapshots(),
        builder: (context, snapshot) {
          // Lấy dữ liệu Realtime từ Firestore nếu có, nếu không thì dùng dữ liệu truyền vào ban đầu
          double currentRating = r.averageRating;
          int currentTotalReviews = r.totalReviews;
          String currentImageUrl = r.imageUrl;
          String currentOwnerUid = r.ownerUid ?? '';
          final currentImages = <String>[...r.images];
          final currentMenu = <Map<String, dynamic>>[...r.menu];
          final currentDescription = r.description;
          final currentPhone = r.phone;
          final currentOpeningHours = r.openingHours;
          final currentType = r.restaurantType;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            currentRating = (data['averageRating'] as num? ?? 0.0).toDouble();
            currentTotalReviews = data['totalReviews'] as int? ?? 0;
            currentImageUrl = (data['imageUrl'] as String?)?.trim().isNotEmpty == true
                ? data['imageUrl'] as String
                : currentImageUrl;
            currentOwnerUid = (data['ownerUid'] as String?) ?? currentOwnerUid;
            currentImages
              ..clear()
              ..addAll(List<String>.from(data['images'] ?? currentImages));
            currentMenu
              ..clear()
              ..addAll(List<Map<String, dynamic>>.from(
                (data['menu'] as List<dynamic>? ?? currentMenu)
                    .map((item) => Map<String, dynamic>.from(item as Map)),
              ));
          }

          final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
          final isOwner = currentUserUid != null && currentUserUid == currentOwnerUid;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(r.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  background: currentImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: currentImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.orange.shade100,
                            child: const Icon(Icons.restaurant, size: 80, color: Colors.orange),
                          ),
                        )
                      : Container(
                          color: Colors.orange.shade100,
                          child: const Icon(Icons.restaurant, size: 80, color: Colors.orange),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(currentRating.toStringAsFixed(1),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(' ($currentTotalReviews)',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              List.filled(r.priceRange, '₫').join(),
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const Spacer(),
                          if (r.distanceKm != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.directions_walk, size: 16, color: Colors.blue.shade400),
                                  const SizedBox(width: 4),
                                  Text('${r.distanceKm!.toStringAsFixed(1)} km',
                                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (r.categories.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: r.categories
                              .map((tag) => Chip(
                                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                                    backgroundColor: Colors.orange.shade50,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _infoRow(Icons.location_on, r.address),
                      if (currentPhone.isNotEmpty) _infoRow(Icons.phone, currentPhone),
                      if (currentOpeningHours.isNotEmpty) _infoRow(Icons.access_time, currentOpeningHours),
                      if (currentType.isNotEmpty) _infoRow(Icons.restaurant_menu, currentType),
                      if (currentDescription.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(currentDescription, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                      ],
                      if (isOwner) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MyRestaurantManagementScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Quản lý quán của tôi'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _locationService.openDirections(r),
                              icon: const Icon(Icons.directions),
                              label: const Text('Chỉ đường'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddReviewScreen(restaurantId: r.id),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.rate_review),
                              label: const Text('Viết đánh giá'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade700,
                                side: BorderSide(color: Colors.orange.shade700),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (currentMenu.isEmpty)
                        Text('Chưa có menu cập nhật.', style: TextStyle(color: Colors.grey.shade600))
                      else
                        ...currentMenu.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text((item['name'] ?? '').toString()),
                            subtitle: Text(
                              [
                                if ((item['price'] ?? '').toString().isNotEmpty) 'Giá: ${item['price']}',
                                if ((item['note'] ?? '').toString().isNotEmpty) 'Ghi chú: ${item['note']}',
                              ].join(' • '),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Text('Hình ảnh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (currentImages.isEmpty)
                        Text('Chưa có ảnh bổ sung.', style: TextStyle(color: Colors.grey.shade600))
                      else
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: currentImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: currentImages[index],
                                width: 130,
                                height: 110,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 130,
                                  height: 110,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (r.lat != null && r.lng != null) ...[
                        const SizedBox(height: 20),
                        const Text('Vị trí', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 180,
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(target: LatLng(r.lat!, r.lng!), zoom: 15),
                              markers: {
                                Marker(
                                  markerId: MarkerId(r.id),
                                  position: LatLng(r.lat!, r.lng!),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                ),
                              },
                              zoomControlsEnabled: false,
                              scrollGesturesEnabled: false,
                              liteModeEnabled: true,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Đánh giá thực tế',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('$currentTotalReviews lượt đánh giá', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ReviewListWidget(restaurantId: r.id),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
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
            child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
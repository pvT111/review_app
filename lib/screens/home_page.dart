import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/restaurants.dart';
import '../services/location_service.dart';
import 'restaurant_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  String _sortBy = 'rating';
  String? _selectedCategory;
  int? _selectedPriceRange;
  double? _selectedMinRating;
  String? _selectedType;

  static const List<Map<String, dynamic>> _categories = [
    {'label': 'Ngon rẻ', 'icon': Icons.money_off, 'color': Color(0xFF4CAF50)},
    {'label': 'Healthy', 'icon': Icons.eco, 'color': Color(0xFF8BC34A)},
    {'label': 'Cay', 'icon': Icons.local_fire_department, 'color': Color(0xFFF44336)},
    {'label': 'Trà sữa', 'icon': Icons.local_cafe, 'color': Color(0xFFE91E63)},
    {'label': 'Lẩu', 'icon': Icons.soup_kitchen, 'color': Color(0xFFFF9800)},
    {'label': 'BBQ', 'icon': Icons.outdoor_grill, 'color': Color(0xFF795548)},
    {'label': 'Hải sản', 'icon': Icons.set_meal, 'color': Color(0xFF2196F3)},
    {'label': 'Chay', 'icon': Icons.spa, 'color': Color(0xFF009688)},
  ];

  // Hàm xử lý logic lọc dữ liệu từ Stream
  List<RestaurantModel> _processData(List<RestaurantModel> data) {
    List<RestaurantModel> filtered = _locationService.filterRestaurants(
      data,
      priceRange: _selectedPriceRange,
      minRating: _selectedMinRating,
      category: _selectedCategory,
      restaurantType: _selectedType,
    );

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((r) =>
          r.name.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query)).toList();
    }

    if (_sortBy == 'distance') {
      _locationService.sortByDistance(filtered);
    } else {
      _locationService.sortByRating(filtered);
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Đã xảy ra lỗi'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Chuyển đổi dữ liệu từ Firestore sang Model
          List<RestaurantModel> allRestaurants = snapshot.data!.docs
              .map((doc) => RestaurantModel.fromFirestore(doc))
              .toList();

          // Xử lý logic hiển thị
          List<RestaurantModel> filteredList = _processData(allRestaurants);
          List<RestaurantModel> featuredList = List.from(allRestaurants)
            ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
          featuredList = featuredList.take(5).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildSearchBar()),
              if (featuredList.isNotEmpty)
                SliverToBoxAdapter(child: _buildFeaturedSlider(featuredList)),
              SliverToBoxAdapter(child: _buildCategories()),
              SliverToBoxAdapter(child: _buildSortBar(filteredList.length)),
              filteredList.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Không tìm thấy quán ăn nào', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildRestaurantCard(filteredList[index]),
                        childCount: filteredList.length,
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasActiveFilters = _selectedPriceRange != null || _selectedMinRating != null || _selectedType != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm quán ăn...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _showFilterSheet,
            icon: Badge(isLabelVisible: hasActiveFilters, child: const Icon(Icons.tune)),
            style: IconButton.styleFrom(backgroundColor: Colors.orange.shade50),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSlider(List<RestaurantModel> featured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Quán ăn nổi bật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        CarouselSlider.builder(
          itemCount: featured.length,
          options: CarouselOptions(height: 180, autoPlay: true, enlargeCenterPage: true, viewportFraction: 0.85),
          itemBuilder: (context, index, _) {
            final r = featured[index];
            return GestureDetector(
              onTap: () => _openDetail(r),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    r.imageUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: r.imageUrl, fit: BoxFit.cover)
                        : Container(color: Colors.orange.shade100, child: const Icon(Icons.restaurant, size: 60, color: Colors.orange)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12, left: 12, right: 12,
                      child: Text(r.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () {
              setState(() { _selectedCategory = isSelected ? null : cat['label']; });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: isSelected ? cat['color'] : (cat['color'] as Color).withValues(alpha: 0.2),
                    child: Icon(cat['icon'], color: isSelected ? Colors.white : cat['color']),
                  ),
                  Text(cat['label'], style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortBar(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$count quán ăn'),
          DropdownButton<String>(
            value: _sortBy,
            items: const [
              DropdownMenuItem(value: 'rating', child: Text('Rating')),
              DropdownMenuItem(value: 'distance', child: Text('Gần nhất')),
            ],
            onChanged: (v) { if(v != null) setState(() => _sortBy = v); },
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(RestaurantModel r) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: r.imageUrl.isNotEmpty 
          ? CachedNetworkImage(imageUrl: r.imageUrl, width: 60, height: 60, fit: BoxFit.cover)
          : Container(width: 60, height: 60, color: Colors.orange.shade50, child: const Icon(Icons.restaurant)),
      ),
      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${r.averageRating.toStringAsFixed(1)} ★ (${r.totalReviews} reviews)'),
      onTap: () => _openDetail(r),
    );
  }

  void _showFilterSheet() {
    // Giữ nguyên logic showModalBottomSheet cũ của bạn nhưng gọi setState(() {}) khi hoàn tất
  }

  void _openDetail(RestaurantModel r) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: r)));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
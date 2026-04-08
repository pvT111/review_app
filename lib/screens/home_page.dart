import 'dart:async';

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/category.dart';
import '../models/restaurants.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import 'restaurant_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<RestaurantModel>>? _restaurantSubscription;
  StreamSubscription<List<CategoryModel>>? _categorySubscription;

  List<RestaurantModel> _allRestaurants = [];
  List<RestaurantModel> _filteredRestaurants = [];
  List<RestaurantModel> _featuredRestaurants = [];
  List<String> _adminCategoryLabels = [];
  List<String> _dynamicCategories = [];
  Set<String> _nearbyRestaurantIds = <String>{};
  double _originLat = 10.7769;
  double _originLng = 106.7009;
  bool _isLoading = true;
  String _sortBy = 'rating'; // 'rating' or 'distance'
  String? _selectedCategory;
  int? _selectedPriceRange;
  double? _selectedMinRating;
  String? _selectedType;

  List<String> get _availableRestaurantTypes {
    final types = _allRestaurants
        .map((r) => r.restaurantType.trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (types.isEmpty) {
      return const ['Quán ăn', 'Nhà hàng', 'Café', 'Quán vỉa hè'];
    }

    return types;
  }

  @override
  void initState() {
    super.initState();
    _listenAdminCategories();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      final lat = pos?.latitude ?? _originLat;
      final lng = pos?.longitude ?? _originLng;
      _originLat = lat;
      _originLng = lng;

      final nearbyRestaurants = await _placesService.getNearbyRestaurants(
        lat: lat,
        lng: lng,
        radius: 5000,
      );
      _nearbyRestaurantIds = nearbyRestaurants.map((r) => r.id).toSet();

      // SỬA LỖI: Await việc đẩy dữ liệu lên Firestore để đảm bảo thành công
      // Sử dụng Future.wait để đẩy song song nhưng vẫn đợi kết quả
      if (nearbyRestaurants.isNotEmpty) {
        await Future.wait(nearbyRestaurants.map((r) => _firestoreService.ensureRestaurantExists(r)));
        debugPrint('Đã đồng bộ ${nearbyRestaurants.length} quán lên Firestore');
      }
      _listenRestaurantsRealtime();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenRestaurantsRealtime() {
    _restaurantSubscription?.cancel();
    _restaurantSubscription = _firestoreService.getRestaurantsStream().listen((restaurants) {
      final source = _nearbyRestaurantIds.isNotEmpty
          ? restaurants.where((r) => _nearbyRestaurantIds.contains(r.id)).toList()
          : restaurants;

      for (final r in source) {
        r.distanceKm = _locationService.getDistanceToRestaurant(r);
      }

      _allRestaurants = source;
      _featuredRestaurants = List<RestaurantModel>.from(source)
        ..sort((a, b) => b.averageRating.compareTo(a.averageRating));
      _featuredRestaurants = _featuredRestaurants.take(5).toList();

      _rebuildDynamicCategories();
      _applyFiltersAndSort();
    });
  }

  void _listenAdminCategories() {
    _categorySubscription?.cancel();
    _categorySubscription = _firestoreService.getCategoriesStream().listen((categories) {
      _adminCategoryLabels = categories
          .map((c) => c.label.trim())
          .where((label) => label.isNotEmpty)
          .toList();
      _rebuildDynamicCategories();
      _applyFiltersAndSort();
    });
  }

  void _rebuildDynamicCategories() {
    final merged = <String>{};

    for (final category in _adminCategoryLabels) {
      merged.add(category);
    }

    for (final restaurant in _allRestaurants) {
      final type = restaurant.restaurantType.trim();
      if (type.isNotEmpty) {
        merged.add(type);
      }
    }

    _dynamicCategories = merged.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (_selectedCategory != null && !_dynamicCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }
  }

  void _applyFiltersAndSort() {
    _filteredRestaurants = List<RestaurantModel>.from(_allRestaurants).where((r) {
      if (_selectedPriceRange != null && r.priceRange != _selectedPriceRange) return false;
      if (_selectedMinRating != null && r.averageRating < _selectedMinRating!) return false;
      if (_selectedType != null && _selectedType!.isNotEmpty && r.restaurantType != _selectedType) {
        return false;
      }

      if (_selectedCategory != null) {
        final selected = _selectedCategory!;
        final hasCategory = r.categories.contains(selected);
        final isRestaurantType = r.restaurantType == selected;
        if (!hasCategory && !isRestaurantType) {
          return false;
        }
      }
      return true;
    }).toList();

    // Search filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      _filteredRestaurants = _filteredRestaurants
          .where((r) =>
              r.name.toLowerCase().contains(query) ||
              r.address.toLowerCase().contains(query) ||
              r.description.toLowerCase().contains(query))
          .toList();
    }

    // Sort
    if (_sortBy == 'distance') {
      _locationService.sortByDistance(_filteredRestaurants);
    } else {
      _locationService.sortByRating(_filteredRestaurants);
    }

    if (mounted) setState(() {});
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int? tempPrice = _selectedPriceRange;
        double? tempRating = _selectedMinRating;
        String? tempType = _selectedType;
        final typeOptions = _availableRestaurantTypes;

        if (tempType != null && !typeOptions.contains(tempType)) {
          tempType = null;
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bộ lọc',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempPrice = null;
                            tempRating = null;
                            tempType = null;
                          });
                        },
                        child: const Text('Xóa bộ lọc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price range
                  const Text('Mức giá',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 2, 3].map((price) {
                      final selected = tempPrice == price;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(List.filled(price, '₫').join()),
                          selected: selected,
                          onSelected: (val) {
                            setSheetState(
                                () => tempPrice = val ? price : null);
                          },
                          selectedColor: Colors.orange.shade100,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Min rating
                  const Text('Đánh giá tối thiểu',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [3.0, 3.5, 4.0, 4.5].map((rating) {
                      final selected = tempRating == rating;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$rating'),
                              const SizedBox(width: 2),
                              const Icon(Icons.star,
                                  size: 14, color: Colors.amber),
                            ],
                          ),
                          selected: selected,
                          onSelected: (val) {
                            setSheetState(
                                () => tempRating = val ? rating : null);
                          },
                          selectedColor: Colors.amber.shade100,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Restaurant type
                  const Text('Loại hình',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: typeOptions.map((type) {
                      final selected = tempType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        onSelected: (val) {
                          setSheetState(
                              () => tempType = val ? type : null);
                        },
                        selectedColor: Colors.blue.shade100,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        _selectedPriceRange = tempPrice;
                        _selectedMinRating = tempRating;
                        _selectedType = tempType;
                        _applyFiltersAndSort();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Áp dụng',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Search bar
                SliverToBoxAdapter(child: _buildSearchBar()),

                // Featured slider
                if (_featuredRestaurants.isNotEmpty)
                  SliverToBoxAdapter(child: _buildFeaturedSlider()),

                // Categories
                SliverToBoxAdapter(child: _buildCategories()),

                // Sort bar
                SliverToBoxAdapter(child: _buildSortBar()),

                // Restaurant list
                _filteredRestaurants.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Không tìm thấy quán ăn nào',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRestaurantCard(
                              _filteredRestaurants[index]),
                          childCount: _filteredRestaurants.length,
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    final hasActiveFilters = _selectedPriceRange != null ||
        _selectedMinRating != null ||
        _selectedType != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFiltersAndSort(),
              decoration: InputDecoration(
                hintText: 'Tìm quán ăn, món ăn...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFiltersAndSort();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: hasActiveFilters,
            child: IconButton(
              onPressed: _showFilterSheet,
              icon: const Icon(Icons.tune),
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Quán ăn nổi bật',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        CarouselSlider.builder(
          itemCount: _featuredRestaurants.length,
          options: CarouselOptions(
            height: 180,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: true,
            viewportFraction: 0.85,
          ),
          itemBuilder: (context, index, _) {
            final restaurant = _featuredRestaurants[index];
            return GestureDetector(
              onTap: () => _openDetail(restaurant),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      restaurant.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: restaurant.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.orange.shade100,
                                child: const Icon(Icons.restaurant,
                                    size: 60, color: Colors.orange),
                              ),
                            )
                          : Container(
                              color: Colors.orange.shade100,
                              child: const Icon(Icons.restaurant,
                                  size: 60, color: Colors.orange),
                            ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      // Info
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(restaurant.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  restaurant.averageRating.toStringAsFixed(1),
                                  style:
                                      const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${restaurant.totalReviews} reviews)',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12),
                                ),
                                const Spacer(),
                                if (restaurant.distanceKm != null)
                                  Text(
                                    '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text('Danh mục',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _dynamicCategories.length,
            itemBuilder: (context, index) {
              final category = _dynamicCategories[index];
              final isSelected = _selectedCategory == category;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = isSelected ? null : category;
                  });
                  _applyFiltersAndSort();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory = isSelected ? null : category;
                      });
                      _applyFiltersAndSort();
                    },
                    selectedColor: Colors.orange.shade100,
                    side: BorderSide(
                      color: isSelected ? Colors.orange.shade400 : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredRestaurants.length} quán ăn',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                icon: const Icon(Icons.sort, size: 18),
                items: const [
                  DropdownMenuItem(
                      value: 'rating', child: Text('Rating cao nhất')),
                  DropdownMenuItem(
                      value: 'distance', child: Text('Gần nhất')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _sortBy = value;
                    _applyFiltersAndSort();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(RestaurantModel restaurant) {
    return GestureDetector(
      onTap: () => _openDetail(restaurant),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 110,
                height: 110,
                child: restaurant.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: restaurant.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.restaurant,
                              color: Colors.grey),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.orange.shade50,
                          child: const Icon(Icons.restaurant,
                              color: Colors.orange),
                        ),
                      )
                    : Container(
                        color: Colors.orange.shade50,
                        child: const Icon(Icons.restaurant,
                            color: Colors.orange, size: 40),
                      ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          restaurant.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          ' (${restaurant.totalReviews})',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          List.filled(restaurant.priceRange, '₫').join(),
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            restaurant.address,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (restaurant.distanceKm != null) ...[
                          Icon(Icons.directions_walk,
                              size: 14, color: Colors.blue.shade400),
                          const SizedBox(width: 2),
                          Text(
                            '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade400,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (restaurant.categories.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              children: restaurant.categories
                                  .take(2)
                                  .map((tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(tag,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors
                                                    .orange.shade800)),
                                      ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  void dispose() {
    _restaurantSubscription?.cancel();
    _categorySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String googlePlaceId;
  final double? lat;
  final double? lng;
  final double averageRating;
  final int totalReviews;
  final String? ownerUid;
  final List<String> categories;
  final int priceRange; 
  final String imageUrl;
  final List<String> images;
  final String phone;
  final String openingHours;
  final String description;
  final bool isFeatured;
  final String restaurantType;
  final bool isOpenNow;

  // Runtime-only
  double? distanceKm;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.googlePlaceId,
    this.lat,
    this.lng,
    required this.averageRating,
    required this.totalReviews,
    this.ownerUid,
    this.categories = const [],
    this.priceRange = 1,
    this.imageUrl = '',
    this.images = const [],
    this.phone = '',
    this.openingHours = '',
    this.description = '',
    this.isFeatured = false,
    this.restaurantType = '',
    this.isOpenNow = false,
    this.distanceKm,
  });

  factory RestaurantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final GeoPoint? geoPoint = data['location'] is GeoPoint ? data['location'] : null;

    return RestaurantModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      googlePlaceId: data['googlePlaceId'] ?? doc.id,
      lat: geoPoint?.latitude ?? (data['lat'] as num?)?.toDouble(),
      lng: geoPoint?.longitude ?? (data['lng'] as num?)?.toDouble(),
      averageRating: (data['averageRating'] as num? ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] as int? ?? 0,
  /// Create from OpenStreetMap Overpass API element
  factory RestaurantModel.fromOverpassJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    final osmType = json['type'] as String? ?? 'node';
    final osmId = json['id']?.toString() ?? '';
    // Sửa ID từ 'node/123' thành 'node_123' để tránh lỗi path trong Firestore
    final id = '${osmType}_$osmId';

    double? lat, lng;
    if (json['lat'] != null) {
      lat = (json['lat'] as num).toDouble();
      lng = (json['lon'] as num).toDouble();
    } else if (json['center'] != null) {
      lat = (json['center']['lat'] as num).toDouble();
      lng = (json['center']['lon'] as num).toDouble();
    }

    final parts = <String>[
      if ((tags['addr:housenumber'] ?? '').isNotEmpty)
        tags['addr:housenumber']!,
      if ((tags['addr:street'] ?? '').isNotEmpty) tags['addr:street']!,
      if ((tags['addr:city'] ?? '').isNotEmpty) tags['addr:city']!,
    ];
    final address = parts.isNotEmpty
        ? parts.join(', ')
        : tags['addr:full'] ?? '';

    final cuisine = tags['cuisine'] as String? ?? '';
    final categories = cuisine.isNotEmpty
        ? cuisine.split(';').map((c) => c.trim()).toList()
        : <String>['restaurant'];

    return RestaurantModel(
      id: id,
      name: tags['name'] as String? ??
          tags['name:en'] as String? ??
          'Nhà hàng',
      address: address,
      googlePlaceId: id,
      lat: lat,
      lng: lng,
      averageRating: 0.0,
      totalReviews: 0,
      phone: tags['phone'] ?? tags['contact:phone'] ?? '',
      openingHours: tags['opening_hours'] ?? '',
      categories: categories,
      restaurantType: categories.isNotEmpty ? categories.first : 'restaurant',
      imageUrl: '',
      images: const [],
      isOpenNow: false,
    );
  }

  // Giữ nguyên các factory methods khác...
  factory RestaurantModel.fromPlacesJson(Map<String, dynamic> json, String apiKey) {
    final geometry = json['geometry']?['location'] ?? {};
    final photos = json['photos'] as List<dynamic>? ?? [];
    String photoUrl = '';
    List<String> photoUrls = [];
    for (var photo in photos) {
      final ref = photo['photo_reference'];
      if (ref != null) {
        final url = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$ref&key=$apiKey';
        photoUrls.add(url);
        if (photoUrl.isEmpty) photoUrl = url;
      }
    }
    final types = List<String>.from(json['types'] ?? []);
    return RestaurantModel(
      id: json['place_id'] ?? '',
      name: json['name'] ?? '',
      address: json['vicinity'] ?? json['formatted_address'] ?? '',
      googlePlaceId: json['place_id'] ?? '',
      lat: (geometry['lat'] as num?)?.toDouble(),
      lng: (geometry['lng'] as num?)?.toDouble(),
      averageRating: (json['rating'] ?? 0.0).toDouble(),
      totalReviews: json['user_ratings_total'] ?? 0,
      priceRange: json['price_level'] ?? 1,
      imageUrl: photoUrl,
      images: photoUrls,
      restaurantType: types.isNotEmpty ? types.first : '',
      categories: types,
      isOpenNow: json['opening_hours']?['open_now'] ?? false,
    );
  }

  factory RestaurantModel.fromPlacesV1Json(Map<String, dynamic> json, String apiKey) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final photos = json['photos'] as List<dynamic>? ?? [];
    final displayName = json['displayName'] as Map<String, dynamic>?;
    String photoUrl = '';
    List<String> photoUrls = [];
    for (var photo in photos) {
      final photoName = photo['name'];
      if (photoName != null) {
        final url = 'https://places.googleapis.com/v1/$photoName/media?maxWidthPx=400&key=$apiKey';
        photoUrls.add(url);
        if (photoUrl.isEmpty) photoUrl = url;
      }
    }
    final types = List<String>.from(json['types'] ?? []);
    final priceLevelStr = json['priceLevel'] as String? ?? '';
    int priceRange = 1;
    if (priceLevelStr.contains('MODERATE')) priceRange = 2;
    else if (priceLevelStr.contains('EXPENSIVE') || priceLevelStr.contains('VERY_EXPENSIVE')) priceRange = 3;

    final openingHours = json['regularOpeningHours'] ?? json['currentOpeningHours'] as Map<String, dynamic>?;
    String hoursText = '';
    if (openingHours != null) {
      final weekday = openingHours['weekdayDescriptions'] as List<dynamic>? ?? [];
      hoursText = weekday.join('\n');
    }
    final placeId = json['id'] as String? ?? '';
    return RestaurantModel(
      id: placeId,
      name: displayName?['text'] as String? ?? json['name'] as String? ?? '',
      address: json['formattedAddress'] as String? ?? '',
      googlePlaceId: placeId,
      lat: (location['latitude'] as num?)?.toDouble(),
      lng: (location['longitude'] as num?)?.toDouble(),
      averageRating: (json['rating'] as num? ?? 0.0).toDouble(),
      totalReviews: json['userRatingCount'] as int? ?? 0,
      priceRange: priceRange,
      imageUrl: photoUrl,
      images: photoUrls,
      phone: json['nationalPhoneNumber'] as String? ?? '',
      openingHours: hoursText,
      restaurantType: types.isNotEmpty ? types.first : '',
      categories: types,
      isOpenNow: (json['currentOpeningHours'] as Map<String, dynamic>?)?['openNow'] as bool? ?? false,
    );
  }

  factory RestaurantModel.fromMap(Map<String, dynamic> data, String id) {
    return RestaurantModel(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      googlePlaceId: data['googlePlaceId'] ?? '',
      lat: data['lat']?.toDouble(),
      lng: data['lng']?.toDouble(),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      ownerUid: data['ownerUid'],
      categories: List<String>.from(data['categories'] ?? []),
      priceRange: data['priceRange'] as int? ?? 1,
      imageUrl: data['imageUrl'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      phone: data['phone'] ?? '',
      openingHours: data['openingHours'] ?? '',
      description: data['description'] ?? '',
      isFeatured: data['isFeatured'] ?? false,
      restaurantType: data['restaurantType'] ?? '',
    );
  }

  factory RestaurantModel.fromMap(Map<String, dynamic> data, String id) {
    return RestaurantModel.fromFirestore(_MockDocumentSnapshot(data, id));
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'googlePlaceId': googlePlaceId,
      'lat': lat,
      'lng': lng,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ownerUid': ownerUid,
      'categories': categories,
      'priceRange': priceRange,
      'imageUrl': imageUrl,
      'images': images,
      'phone': phone,
      'openingHours': openingHours,
      'description': description,
      'isFeatured': isFeatured,
      'restaurantType': restaurantType,
    };
  }

  
  factory RestaurantModel.fromOverpassJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    final id = '${json['type']}/${json['id']}';
    double? lat = (json['lat'] ?? json['center']?['lat'] as num?)?.toDouble();
    double? lng = (json['lon'] ?? json['center']?['lon'] as num?)?.toDouble();

    return RestaurantModel(
      id: id,
      name: tags['name'] ?? 'Nhà hàng',
      address: tags['addr:full'] ?? '',
      googlePlaceId: id,
      lat: lat, lng: lng,
      averageRating: 0.0,
      totalReviews: 0,
    );
  }
}

class _MockDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;
  _MockDocumentSnapshot(this._data, this._id);
  @override String get id => _id;
  @override Map<String, dynamic> data() => _data;
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
}

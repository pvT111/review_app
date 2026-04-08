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
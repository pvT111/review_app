import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String googlePlaceId;
  final GeoPoint? location;
  final double averageRating;
  final int totalReviews;
  final String? ownerUid;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    required this.googlePlaceId,
    this.location,
    required this.averageRating,
    required this.totalReviews,
    this.ownerUid,
  });

  factory RestaurantModel.fromMap(Map<String, dynamic> data, String id) {
    return RestaurantModel(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      googlePlaceId: data['googlePlaceId'] ?? '',
      location: data['location'],
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      ownerUid: data['ownerUid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'googlePlaceId': googlePlaceId,
      'location': location,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ownerUid': ownerUid,
    };
  }
}
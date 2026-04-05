import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? id;
  final String userId;
  final String restaurantId;
  final double rating;
  final String comment;
  final List<String> tags;
  final List<String> photoUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    this.id,
    required this.userId,
    required this.restaurantId,
    required this.rating,
    required this.comment,
    required this.tags,
    required this.photoUrls,
    this.createdAt,
    this.updatedAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> data, String id) {
    return ReviewModel(
      id: id,
      userId: data['userId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantId': restaurantId,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'photoUrls': photoUrls,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }
}

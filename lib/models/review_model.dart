import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? id;
  final String restaurantId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final String imageUrl;
  final List<String> tags;
  final DateTime createdAt;

  ReviewModel({
    this.id,
    required this.restaurantId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.imageUrl,
    required this.tags,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) {
    return ReviewModel(
      id: id,
      restaurantId: map['restaurantId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Người dùng ẩn danh',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'imageUrl': imageUrl,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
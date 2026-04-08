import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? id;
  final String restaurantId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final String imageUrl;
  final List<String> photoUrls;
  final List<String> tags;
  final bool isHidden;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    this.id,
    required this.restaurantId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.imageUrl = '',
    this.photoUrls = const [],
    required this.tags,
    this.isHidden = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    final mappedPhotoUrls = List<String>.from(map['photoUrls'] ?? const []);
    final mappedImageUrl = (map['imageUrl'] ?? '').toString();
    return ReviewModel(
      id: id,
      restaurantId: map['restaurantId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Người dùng ẩn danh',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      imageUrl: mappedImageUrl.isNotEmpty
          ? mappedImageUrl
          : (mappedPhotoUrls.isNotEmpty ? mappedPhotoUrls.first : ''),
      photoUrls: mappedPhotoUrls,
      tags: List<String>.from(map['tags'] ?? []),
      isHidden: map['isHidden'] == true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedPhotoUrls = photoUrls.isNotEmpty
        ? photoUrls
        : (imageUrl.isNotEmpty ? <String>[imageUrl] : <String>[]);
    return {
      'restaurantId': restaurantId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'imageUrl': imageUrl,
      'photoUrls': normalizedPhotoUrls,
      'tags': tags,
      'isHidden': isHidden,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }
}
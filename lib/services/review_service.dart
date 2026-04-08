import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'cloudinary_config.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  String _normalizeRestaurantId(String id) => id.replaceAll('/', '_');

  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (pickedFile != null) return File(pickedFile.path);
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
    }
    return null;
  }

  Future<bool> postReview(ReviewModel review, File? imageFile) async {
    try {
      String finalImageUrl = "";
      final normalizedRestaurantId = _normalizeRestaurantId(review.restaurantId);

      if (imageFile != null) {
        String url =
            "https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload";
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
          "upload_preset": CloudinaryConfig.uploadPreset,
        });

        var response = await _dio.post(url, data: formData);
        if (response.statusCode == 200) {
          finalImageUrl = response.data['secure_url'];
        }
      }

      await _firestore.collection('reviews').add({
        ...review.toMap(),
        'restaurantId': normalizedRestaurantId,
        'imageUrl': finalImageUrl,
        'photoUrls': finalImageUrl.isNotEmpty ? [finalImageUrl] : [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _updateRestaurantRating(normalizedRestaurantId);
      return true;
    } catch (e) {
      debugPrint("Lỗi postReview: $e");
      return false;
    }
  }

  Future<void> _updateRestaurantRating(String restaurantId) async {
    try {
      final cleanId = _normalizeRestaurantId(restaurantId);
      final ids = cleanId == restaurantId
          ? <String>[restaurantId]
          : <String>[restaurantId, cleanId];

      var reviewsQuery = await _firestore
          .collection('reviews')
          .where('restaurantId', whereIn: ids)
          .get();

      if (reviewsQuery.docs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in reviewsQuery.docs) {
          // Ép kiểu num an toàn để tránh lỗi crash khi dữ liệu là int
          var data = doc.data();
          totalRating += (data['rating'] as num).toDouble();
        }
        
        double average = totalRating / reviewsQuery.docs.length;

        await _firestore.collection('restaurants').doc(cleanId).set({
          'averageRating': average,
          'totalReviews': reviewsQuery.docs.length,
        }, SetOptions(merge: true));
        
        debugPrint("Đã cập nhật Rating cho quán: $cleanId thành công!");
      }
      if (reviewsQuery.docs.isEmpty) {
        await _firestore.collection('restaurants').doc(cleanId).set({
          'averageRating': 0.0,
          'totalReviews': 0,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Lỗi tại _updateRestaurantRating: $e");
    }
  }

  Future<bool> updateReview({
    required String reviewId,
    required String restaurantId,
    required double rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'comment': comment.trim(),
        'tags': tags,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _updateRestaurantRating(_normalizeRestaurantId(restaurantId));
      return true;
    } catch (e) {
      debugPrint('Lỗi updateReview: $e');
      return false;
    }
  }

  Future<bool> deleteReview({
    required String reviewId,
    required String restaurantId,
  }) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).delete();
      await _updateRestaurantRating(_normalizeRestaurantId(restaurantId));
      return true;
    } catch (e) {
      debugPrint('Lỗi deleteReview: $e');
      return false;
    }
  }
}
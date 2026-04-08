import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  final String cloudName = "dzk2czpmn";
  final String uploadPreset = "review_app";

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

      if (imageFile != null) {
        String url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            imageFile.path,
            contentType: MediaType('image', 'jpeg'),
          ),
          "upload_preset": uploadPreset,
        });

        var response = await _dio.post(url, data: formData);
        if (response.statusCode == 200) {
          finalImageUrl = response.data['secure_url'];
        }
      }

      await _firestore.collection('reviews').add({
        ...review.toMap(),
        'imageUrl': finalImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _updateRestaurantRating(review.restaurantId);
      return true;
    } catch (e) {
      debugPrint("Lỗi postReview: $e");
      return false;
    }
  }

  Future<void> _updateRestaurantRating(String restaurantId) async {
    try {
      // 1. Xử lý lỗi "3 segments": Thay thế các ký tự lạ trong ID
      // Chuyển "node/123" thành "node_123" để Firestore không bị lỗi đường dẫn
      String cleanId = restaurantId.replaceAll('/', '_');

      // 2. Lấy danh sách review để tính toán
      var reviewsQuery = await _firestore
          .collection('reviews')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();

      if (reviewsQuery.docs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in reviewsQuery.docs) {
          // Ép kiểu num an toàn để tránh lỗi crash khi dữ liệu là int
          var data = doc.data();
          totalRating += (data['rating'] as num).toDouble();
        }
        
        double average = totalRating / reviewsQuery.docs.length;

        // 3. Cập nhật vào đúng Document của Người 1
        // Dùng .set với merge: true để tự tạo field nếu chưa có
        await _firestore.collection('restaurants').doc(cleanId).set({
          'averageRating': average,
          'totalReviews': reviewsQuery.docs.length,
        }, SetOptions(merge: true));
        
        debugPrint("Đã cập nhật Rating cho quán: $cleanId thành công!");
      }
    } catch (e) {
      debugPrint("Lỗi tại _updateRestaurantRating: $e");
    }
  }
}
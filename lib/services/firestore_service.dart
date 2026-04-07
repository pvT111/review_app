import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/users.dart';
import '../models/restaurants.dart';
import '../models/reviews.dart';
import '../models/claim.dart';
import '../models/reports.dart';
import '../models/category.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cloudinary Config
  final String _cloudName = "dxkfxl4tf";
  final String _uploadPreset = "review_app_preset";

  // --- User methods ---
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  // --- Restaurant methods ---
  Future<void> ensureRestaurantExists(RestaurantModel restaurant) async {
    final docRef = _db.collection('restaurants').doc(restaurant.id);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set(restaurant.toMap());
    }
  }

  Future<List<RestaurantModel>> getAllRestaurants() async {
    var snapshot = await _db.collection('restaurants').get();
    return snapshot.docs.map((doc) => RestaurantModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<RestaurantModel>> getFeaturedRestaurants() async {
    var snapshot = await _db.collection('restaurants').where('isFeatured', isEqualTo: true).limit(10).get();
    return snapshot.docs.map((doc) => RestaurantModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<RestaurantModel>> getRestaurantsByCategory(String category) async {
    var snapshot = await _db.collection('restaurants').where('categories', arrayContains: category).get();
    return snapshot.docs.map((doc) => RestaurantModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<List<RestaurantModel>> getTopRatedRestaurants({int limit = 20}) async {
    var snapshot = await _db.collection('restaurants').orderBy('averageRating', descending: true).limit(limit).get();
    return snapshot.docs.map((doc) => RestaurantModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<RestaurantModel?> getRestaurant(String id) async {
    var doc = await _db.collection('restaurants').doc(id).get();
    if (doc.exists) return RestaurantModel.fromMap(doc.data()!, doc.id);
    return null;
  }

  Future<List<RestaurantModel>> searchRestaurants(String query) async {
    var snapshot = await _db
        .collection('restaurants')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) => RestaurantModel.fromMap(doc.data(), doc.id)).toList();
  }

  // --- Review methods ---
  Future<List<ReviewModel>> getRestaurantReviews(String restaurantId) async {
    var snapshot = await _db
        .collection('reviews')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<ReviewModel?> getReview(String reviewId) async {
    var doc = await _db.collection('reviews').doc(reviewId).get();
    if (doc.exists) return ReviewModel.fromMap(doc.data()!, doc.id);
    return null;
  }

  // --- Image Upload (Cloudinary) ---
  Future<String> uploadImage(dynamic imageFile, String folder) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      var request = http.MultipartRequest("POST", url);
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', imageFile as Uint8List, filename: 'upload.jpg'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', (imageFile as File).path));
      }

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var responseString = String.fromCharCodes(responseData);
      var jsonResponse = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw "Cloudinary Upload Failed: ${jsonResponse['error']['message']}";
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      rethrow;
    }
  }

  // --- Claim & Admin methods ---
  Future<void> submitClaim(ClaimModel claim) async {
    await _db.collection('claims').add(claim.toMap());
  }

  Future<List<ClaimModel>> getPendingClaims() async {
    var snapshot = await _db.collection('claims').where('status', isEqualTo: 'pending').get();
    return snapshot.docs.map((doc) => ClaimModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> processClaim(String claimId, String status, String userId, String restaurantId) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('claims').doc(claimId), {'status': status});
    if (status == 'approved') {
      batch.update(_db.collection('users').doc(userId), {
        'role': 'owner',
        'ownerOf': FieldValue.arrayUnion([restaurantId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection('restaurants').doc(restaurantId), {'ownerId': userId});
    }
    await batch.commit();
  }

  Future<List<ReportModel>> getPendingReports() async {
    var snapshot = await _db.collection('reports').where('status', isEqualTo: 'pending').get();
    return snapshot.docs.map((doc) => ReportModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> resolveReport(String reportId, String reviewId, String action) async {
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('reports').doc(reportId), {
      'status': action == 'dismiss' ? 'dismissed' : 'resolved',
      'updatedAt': FieldValue.serverTimestamp()
    });
    if (action == 'delete') {
      batch.delete(_db.collection('reviews').doc(reviewId));
    } else if (action == 'hide') {
      batch.update(_db.collection('reviews').doc(reviewId), {'isHidden': true});
    }
    await batch.commit();
  }

  // --- Category Management ---
  Stream<List<CategoryModel>> getCategoriesStream() {
    return _db.collection('categories').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CategoryModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addCategory(CategoryModel category) async => await _db.collection('categories').add(category.toMap());
  Future<void> updateCategory(CategoryModel category) async => await _db.collection('categories').doc(category.id).update(category.toMap());
  Future<void> deleteCategory(String id) async => await _db.collection('categories').doc(id).delete();

  // --- Statistics ---
  Future<List<Map<String, dynamic>>> getReviewGrowthData() async {
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> data = [];
    for (int i = 5; i >= 0; i--) {
      DateTime monthStart = DateTime(now.year, now.month - i, 1);
      DateTime nextMonth = DateTime(now.year, now.month - i + 1, 1);
      DateTime monthEnd = nextMonth.subtract(const Duration(seconds: 1));
      var snapshot = await _db.collection('reviews').where('createdAt', isGreaterThanOrEqualTo: monthStart).where('createdAt', isLessThanOrEqualTo: monthEnd).count().get();
      data.add({'month': '${monthStart.month}/${monthStart.year}', 'count': snapshot.count, 'index': (5 - i).toDouble()});
    }
    return data;
  }
}

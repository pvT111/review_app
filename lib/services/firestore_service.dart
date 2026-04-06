import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/users.dart';
import '../models/restaurants.dart';
import '../models/reviews.dart';
import '../models/claim.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  Future<List<RestaurantModel>> getAllRestaurants() async {
    var snapshot = await _db.collection('restaurants').get();
    return snapshot.docs
        .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<RestaurantModel>> getFeaturedRestaurants() async {
    var snapshot = await _db
        .collection('restaurants')
        .where('isFeatured', isEqualTo: true)
        .limit(10)
        .get();
    return snapshot.docs
        .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<RestaurantModel>> getRestaurantsByCategory(String category) async {
    var snapshot = await _db
        .collection('restaurants')
        .where('categories', arrayContains: category)
        .get();
    return snapshot.docs
        .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<RestaurantModel>> getTopRatedRestaurants({int limit = 20}) async {
    var snapshot = await _db
        .collection('restaurants')
        .orderBy('averageRating', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<RestaurantModel?> getRestaurant(String id) async {
    var doc = await _db.collection('restaurants').doc(id).get();
    if (doc.exists) {
      return RestaurantModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<List<ReviewModel>> getRestaurantReviews(String restaurantId) async {
    var snapshot = await _db
        .collection('reviews')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<RestaurantModel>> searchRestaurants(String query) async {
    var snapshot = await _db
        .collection('restaurants')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs
        .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> uploadImage(dynamic imageFile, String folder) async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference ref = _storage.ref().child('$folder/$fileName');
    
    UploadTask uploadTask;
    if (kIsWeb) {
      uploadTask = ref.putData(imageFile as Uint8List);
    } else {
      uploadTask = ref.putFile(imageFile as File);
    }

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> submitClaim(ClaimModel claim) async {
    await _db.collection('claims').add(claim.toMap());
  }
}

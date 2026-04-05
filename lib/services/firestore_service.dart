import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/users.dart';
import '../models/restaurants.dart';
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

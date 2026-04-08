import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/users.dart';
import '../models/restaurants.dart';
import '../models/review.dart';
import '../models/claim.dart';
import '../models/reports.dart';
import '../models/category.dart';
import 'cloudinary_config.dart';

class EnrichedClaimModel {
  final ClaimModel claim;
  final String userName;
  final String restaurantName;

  const EnrichedClaimModel({
    required this.claim,
    required this.userName,
    required this.restaurantName,
  });
}

class EnrichedReportModel {
  final ReportModel report;
  final ReviewModel? review;
  final String reporterName;
  final String reviewerName;
  final String restaurantName;

  const EnrichedReportModel({
    required this.report,
    required this.review,
    required this.reporterName,
    required this.reviewerName,
    required this.restaurantName,
  });
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String normalizeRestaurantId(String id) => id.replaceAll('/', '_');

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
    final normalizedId = normalizeRestaurantId(restaurant.id);
    final docRef = _db.collection('restaurants').doc(normalizedId);
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

  Stream<List<RestaurantModel>> getRestaurantsStream() {
    return _db.collection('restaurants').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<RestaurantModel?> getRestaurant(String id) async {
    final normalizedId = normalizeRestaurantId(id);
    var doc = await _db.collection('restaurants').doc(normalizedId).get();
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

  Future<void> updateRestaurantFields(
    String restaurantId,
    Map<String, dynamic> updates,
  ) async {
    final normalizedId = normalizeRestaurantId(restaurantId);
    await _db.collection('restaurants').doc(normalizedId).set(
      {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<ReviewModel>> getUserReviewsStream(String userId) {
    return _db
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data(), doc.id)).toList()
              ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))));
  }

  Stream<List<ReviewModel>> getRestaurantReviewsStream(String restaurantId) {
    final normalizedId = normalizeRestaurantId(restaurantId);
    final ids = normalizedId == restaurantId
        ? <String>[restaurantId]
        : <String>[restaurantId, normalizedId];

    return _db
        .collection('reviews')
        .where('restaurantId', whereIn: ids)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<RestaurantModel>> getOwnerRestaurantsStream(String ownerUid) {
    return _db
        .collection('restaurants')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RestaurantModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // --- Review methods ---
  Future<List<ReviewModel>> getRestaurantReviews(String restaurantId) async {
    final normalizedId = normalizeRestaurantId(restaurantId);
    final ids = normalizedId == restaurantId
        ? <String>[restaurantId]
        : <String>[restaurantId, normalizedId];

    var snapshot = await _db
        .collection('reviews')
        .where('restaurantId', whereIn: ids)
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
      final url = Uri.parse(
          "https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload");
      var request = http.MultipartRequest("POST", url);
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
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

  Stream<List<ClaimModel>> getPendingClaimsStream() {
    return _db
        .collection('claims')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ClaimModel.fromMap(doc.data(), doc.id)).toList()
              ..sort((a, b) => (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))));
  }

  Stream<List<EnrichedClaimModel>> getPendingClaimsEnrichedStream() {
    return getPendingClaimsStream().asyncMap((claims) async {
      if (claims.isEmpty) return const <EnrichedClaimModel>[];

      try {
        final userIds = claims.map((c) => c.userId).where((id) => id.isNotEmpty).toSet();
        final restaurantIds = claims
            .map((c) => normalizeRestaurantId(c.restaurantId))
            .where((id) => id.isNotEmpty)
            .toSet();

        final userResults = await Future.wait(
          userIds.map((id) => _db.collection('users').doc(id).get()),
        );
        final restaurantResults = await Future.wait(
          restaurantIds.map((id) => _db.collection('restaurants').doc(id).get()),
        );

        final userById = <String, String>{};
        for (final doc in userResults) {
          final data = doc.data();
          userById[doc.id] = (data?['name'] as String?)?.trim().isNotEmpty == true
              ? (data!['name'] as String)
              : 'Người dùng';
        }

        final restaurantById = <String, String>{};
        for (final doc in restaurantResults) {
          final data = doc.data();
          restaurantById[doc.id] = (data?['name'] as String?)?.trim().isNotEmpty == true
              ? (data!['name'] as String)
              : 'Quán không xác định';
        }

        return claims
            .map(
              (claim) => EnrichedClaimModel(
                claim: claim,
                userName: userById[claim.userId] ?? 'Người dùng',
                restaurantName: restaurantById[normalizeRestaurantId(claim.restaurantId)] ??
                    'Quán không xác định',
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('Enrich claim stream fallback: $e');
        return claims
            .map(
              (claim) => EnrichedClaimModel(
                claim: claim,
                userName: claim.userId,
                restaurantName: claim.restaurantId,
              ),
            )
            .toList();
      }
    });
  }

  Future<void> processClaim(String claimId, String status, String userId, String restaurantId) async {
    final normalizedRestaurantId = normalizeRestaurantId(restaurantId);
    WriteBatch batch = _db.batch();
    batch.update(_db.collection('claims').doc(claimId), {'status': status});
    if (status == 'approved') {
      batch.update(_db.collection('users').doc(userId), {
        'role': 'owner',
        'ownerOf': FieldValue.arrayUnion([normalizedRestaurantId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection('restaurants').doc(normalizedRestaurantId), {
        'ownerUid': userId,
      });
    }
    await batch.commit();
  }

  Future<List<ReportModel>> getPendingReports() async {
    var snapshot = await _db.collection('reports').where('status', isEqualTo: 'pending').get();
    return snapshot.docs.map((doc) => ReportModel.fromMap(doc.data(), doc.id)).toList();
  }

  Stream<List<ReportModel>> getPendingReportsStream() {
    return _db
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ReportModel.fromMap(doc.data(), doc.id)).toList()
              ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))));
  }

  Stream<List<EnrichedReportModel>> getPendingReportsEnrichedStream() {
    return getPendingReportsStream().asyncMap((reports) async {
      if (reports.isEmpty) return const <EnrichedReportModel>[];

      try {
        final reviewResults = await Future.wait(
          reports
              .map((r) => r.reviewId)
              .where((id) => id.isNotEmpty)
              .toSet()
              .map((id) => _db.collection('reviews').doc(id).get()),
        );

        final reviewById = <String, ReviewModel>{};
        for (final doc in reviewResults) {
          final data = doc.data();
          if (doc.exists && data != null) {
            reviewById[doc.id] = ReviewModel.fromMap(data, doc.id);
          }
        }

        final reporterIds = reports.map((r) => r.reporterId).where((id) => id.isNotEmpty).toSet();
        final reviewerIds = reviewById.values.map((r) => r.userId).where((id) => id.isNotEmpty).toSet();
        final allUserIds = <String>{...reporterIds, ...reviewerIds};

        final userResults = await Future.wait(
          allUserIds.map((id) => _db.collection('users').doc(id).get()),
        );
        final userById = <String, String>{};
        for (final doc in userResults) {
          final data = doc.data();
          userById[doc.id] = (data?['name'] as String?)?.trim().isNotEmpty == true
              ? (data!['name'] as String)
              : 'Người dùng';
        }

        final restaurantIds = reviewById.values
            .map((r) => normalizeRestaurantId(r.restaurantId))
            .where((id) => id.isNotEmpty)
            .toSet();
        final restaurantResults = await Future.wait(
          restaurantIds.map((id) => _db.collection('restaurants').doc(id).get()),
        );
        final restaurantById = <String, String>{};
        for (final doc in restaurantResults) {
          final data = doc.data();
          restaurantById[doc.id] = (data?['name'] as String?)?.trim().isNotEmpty == true
              ? (data!['name'] as String)
              : 'Quán không xác định';
        }

        return reports.map((report) {
          final linkedReview = reviewById[report.reviewId];
          final reviewerName = linkedReview != null
              ? (linkedReview.userName.trim().isNotEmpty
                  ? linkedReview.userName
                  : (userById[linkedReview.userId] ?? 'Người đánh giá'))
              : 'Người đánh giá';
          final restaurantName = linkedReview != null
              ? (restaurantById[normalizeRestaurantId(linkedReview.restaurantId)] ?? 'Quán không xác định')
              : 'Quán không xác định';

          return EnrichedReportModel(
            report: report,
            review: linkedReview,
            reporterName: userById[report.reporterId] ?? 'Người báo cáo',
            reviewerName: reviewerName,
            restaurantName: restaurantName,
          );
        }).toList();
      } catch (e) {
        debugPrint('Enrich report stream fallback: $e');
        return reports
            .map(
              (r) => EnrichedReportModel(
                report: r,
                review: null,
                reporterName: r.reporterId,
                reviewerName: 'Người đánh giá',
                restaurantName: 'Quán không xác định',
              ),
            )
            .toList();
      }
    });
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

  Future<void> submitReviewReport({
    required String reviewId,
    required String reporterId,
    required String reason,
  }) async {
    await _db.collection('reports').add({
      'reviewId': reviewId,
      'reporterId': reporterId,
      'reason': reason.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

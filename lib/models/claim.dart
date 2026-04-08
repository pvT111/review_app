import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimModel {
  final String id;
  final String userId;
  final String restaurantId;
  final String status; // pending, approved, rejected
  final List<String> proofImages;
  final String note;
  final DateTime? submittedAt;

  ClaimModel({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.status,
    required this.proofImages,
    this.note = '',
    this.submittedAt,
  });

  factory ClaimModel.fromMap(Map<String, dynamic> data, String id) {
    return ClaimModel(
      id: id,
      userId: data['userId'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
      status: data['status'] ?? 'pending',
      proofImages: List<String>.from(data['proofImages'] ?? []),
      note: data['note'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantId': restaurantId,
      'status': status,
      'proofImages': proofImages,
      'note': note,
      'submittedAt': submittedAt ?? FieldValue.serverTimestamp(),
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reviewId;
  final String reporterId;
  final String reason;
  final String status; // pending, resolved, dismissed
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReportModel({
    required this.id,
    required this.reviewId,
    required this.reporterId,
    required this.reason,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportModel.fromMap(Map<String, dynamic> data, String id) {
    return ReportModel(
      id: id,
      reviewId: data['reviewId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewId': reviewId,
      'reporterId': reporterId,
      'reason': reason,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/review_model.dart';
import 'review_card_item.dart';

class ReviewListWidget extends StatelessWidget {
  final String restaurantId;

  const ReviewListWidget({super.key, required this.restaurantId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Lỗi StreamBuilder: ${snapshot.error}");
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Không thể tải đánh giá vào lúc này.'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'Chưa có đánh giá nào.\nHãy là người đầu tiên!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            try {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              ReviewModel review = ReviewModel.fromMap(doc.id, data);
              
              return ReviewCardItem(review: review);
            } catch (e) {
              debugPrint("Lỗi render ReviewCardItem: $e");
              return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }
}
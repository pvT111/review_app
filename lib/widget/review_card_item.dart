import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Để định dạng ngày tháng
import '../models/review.dart';

class ReviewCardItem extends StatelessWidget {
  final ReviewModel review;

  const ReviewCardItem({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final createdAt = review.createdAt;
    final createdAtText = createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
        : 'Chua cap nhat';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Text(review.userName[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        createdAtText,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(" ${review.rating}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(review.comment, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),

            if (review.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                children: review.tags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.blueGrey[50],
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),

            const SizedBox(height: 8),
            if (review.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  review.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 50),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
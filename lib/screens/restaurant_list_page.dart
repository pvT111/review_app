import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/restaurants.dart';
import 'restaurant_detail.dart';

class RestaurantListPage extends StatelessWidget {
  const RestaurantListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn quán để đánh giá'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Lỗi tải dữ liệu'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final r = RestaurantModel.fromFirestore(docs[index]);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: r.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: r.imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          color: Colors.orange.shade50,
                          child: const Icon(Icons.restaurant, color: Colors.orange),
                        ),
                ),
                title: Text(
                  r.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('${r.averageRating.toStringAsFixed(1)} (${r.totalReviews} đánh giá)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Khi bấm vào quán, dẫn sang trang chi tiết (nơi có danh sách đánh giá và nút viết bài)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RestaurantDetailScreen(restaurant: r),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';
import '../services/review_service.dart';

class ReviewHistoryScreen extends StatefulWidget {
  const ReviewHistoryScreen({super.key});

  @override
  State<ReviewHistoryScreen> createState() => _ReviewHistoryScreenState();
}

class _ReviewHistoryScreenState extends State<ReviewHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ReviewService _reviewService = ReviewService();

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Không rõ thời gian';
    final d = dateTime.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditDialog(ReviewModel review) async {
    final commentCtrl = TextEditingController(text: review.comment);
    double editedRating = review.rating;
    final selectedTags = <String>[...review.tags];
    final availableTags = <String>[
      'Ngon',
      'Rẻ',
      'Cay',
      'Không gian đẹp',
      'Phục vụ tốt',
      'Sạch sẽ',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chỉnh sửa đánh giá',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('Điểm đánh giá', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Slider(
                      value: editedRating,
                      min: 1,
                      max: 5,
                      divisions: 8,
                      label: editedRating.toStringAsFixed(1),
                      onChanged: (value) => setSheetState(() => editedRating = value),
                    ),
                    const SizedBox(height: 8),
                    const Text('Gắn thẻ', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTags.map((tag) {
                        final selected = selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                selectedTags.add(tag);
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung đánh giá',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (commentCtrl.text.trim().isEmpty) return;
                          final ok = await _reviewService.updateReview(
                            reviewId: review.id!,
                            restaurantId: review.restaurantId,
                            rating: editedRating,
                            comment: commentCtrl.text.trim(),
                            tags: selectedTags,
                          );

                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Đã cập nhật đánh giá.' : 'Không thể cập nhật đánh giá.',
                              ),
                            ),
                          );
                        },
                        child: const Text('Lưu thay đổi'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteReview(ReviewModel review) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa đánh giá'),
        content: const Text('Bạn có chắc muốn xóa đánh giá này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final ok = await _reviewService.deleteReview(
      reviewId: review.id!,
      restaurantId: review.restaurantId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã xóa đánh giá.' : 'Không thể xóa đánh giá.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử đánh giá')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem lịch sử đánh giá.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đánh giá')),
      body: StreamBuilder<List<ReviewModel>>(
        stream: _firestoreService.getUserReviewsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải lịch sử đánh giá: ${snapshot.error}'),
              ),
            );
          }

          final reviews = snapshot.data ?? const <ReviewModel>[];
          if (reviews.isEmpty) {
            return const Center(child: Text('Bạn chưa có đánh giá nào.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  review.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(review.updatedAt ?? review.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        review.comment,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (review.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: review.tags
                              .map((tag) => Chip(
                                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showEditDialog(review),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Sửa'),
                          ),
                          TextButton.icon(
                            onPressed: () => _deleteReview(review),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text('Xóa', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

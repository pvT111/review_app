import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';
import '../services/review_service.dart';

class AddReviewScreen extends StatefulWidget {
  final String restaurantId;
  const AddReviewScreen({super.key, required this.restaurantId});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _commentController = TextEditingController();

  File? _image;
  double _currentRating = 3.0;
  final List<String> _selectedTags = [];
  bool _isLoading = false;

  final List<String> _availableTags = [
    'Ngon',
    'Rẻ',
    'Cay',
    'Không gian đẹp',
    'Phục vụ tốt',
    'Sạch sẽ',
  ];

  Future<void> _takePicture() async {
    final image = await _reviewService.pickImageFromCamera();
    if (image != null) {
      setState(() {
        _image = image;
      });
    }
  }

  void _submit() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập cảm nhận của bạn!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập để gửi đánh giá.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final userData = await _firestoreService.getUser(user.uid);

      final newReview = ReviewModel(
        restaurantId: widget.restaurantId,
        userId: user.uid,
        userName: (userData?.name.trim().isNotEmpty == true)
            ? userData!.name
            : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!
                : 'Người dùng'),
        rating: _currentRating,
        comment: _commentController.text,
        imageUrl: '',
        tags: _selectedTags,
        createdAt: DateTime.now(),
      );

      bool success = await _reviewService.postReview(newReview, _image);

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đánh giá thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viết đánh giá'), centerTitle: true),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Đang gửi đánh giá của bạn...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hình ảnh thực tế (Tùy chọn)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: _image == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 50,
                                  color: Colors.orange,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Bấm để thêm ảnh minh họa',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(_image!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Chất lượng món ăn & dịch vụ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: RatingBar.builder(
                      initialRating: 3,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) =>
                          const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) => _currentRating = rating,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Gắn thẻ đặc điểm:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _availableTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: Colors.orange[200],
                        onSelected: (bool selected) {
                          setState(() {
                            selected
                                ? _selectedTags.add(tag)
                                : _selectedTags.remove(tag);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Ghi chú:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Chia sẻ trải nghiệm của bạn về món ăn, không gian...',
                      fillColor: Colors.grey[50],
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'GỬI ĐÁNH GIÁ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
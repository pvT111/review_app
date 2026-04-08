import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/restaurants.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';

class MyRestaurantManagementScreen extends StatefulWidget {
  const MyRestaurantManagementScreen({super.key});

  @override
  State<MyRestaurantManagementScreen> createState() => _MyRestaurantManagementScreenState();
}

class _MyRestaurantManagementScreenState extends State<MyRestaurantManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedRestaurantId;
  String _reviewFilter = 'all';

  Future<void> _editBasicInfo(RestaurantModel restaurant) async {
    final nameCtrl = TextEditingController(text: restaurant.name);
    final addressCtrl = TextEditingController(text: restaurant.address);
    final phoneCtrl = TextEditingController(text: restaurant.phone);
    final openingCtrl = TextEditingController(text: restaurant.openingHours);
    final descriptionCtrl = TextEditingController(text: restaurant.description);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
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
              const Text('Cập nhật thông tin chung',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên quán'),
              ),
              TextField(
                controller: addressCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
              TextField(
                controller: openingCtrl,
                decoration: const InputDecoration(labelText: 'Giờ mở cửa'),
              ),
              TextField(
                controller: descriptionCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await _firestoreService.updateRestaurantFields(restaurant.id, {
                      'name': nameCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'openingHours': openingCtrl.text.trim(),
                      'description': descriptionCtrl.text.trim(),
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Lưu thông tin'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addMenuItem(RestaurantModel restaurant) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm món mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên món')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Giá')),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Ghi chú')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final itemName = nameCtrl.text.trim();
              if (itemName.isEmpty) return;

              final nextMenu = <Map<String, dynamic>>[
                ...restaurant.menu,
                {
                  'name': itemName,
                  'price': priceCtrl.text.trim(),
                  'note': noteCtrl.text.trim(),
                }
              ];

              await _firestoreService.updateRestaurantFields(
                restaurant.id,
                {'menu': nextMenu},
              );

              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Thêm'),
          )
        ],
      ),
    );
  }

  Future<void> _removeMenuItem(RestaurantModel restaurant, int index) async {
    final nextMenu = <Map<String, dynamic>>[...restaurant.menu]..removeAt(index);
    await _firestoreService.updateRestaurantFields(restaurant.id, {'menu': nextMenu});
  }

  Future<void> _addImage(RestaurantModel restaurant) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chức năng thêm ảnh bằng máy ảnh chưa hỗ trợ trên web.')),
      );
      return;
    }

    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    final imageUrl = await _firestoreService.uploadImage(File(picked.path), 'restaurants');
    final nextImages = <String>[...restaurant.images];
    if (!nextImages.contains(imageUrl)) {
      nextImages.add(imageUrl);
    }

    final nextCover = restaurant.imageUrl.isEmpty ? imageUrl : restaurant.imageUrl;
    await _firestoreService.updateRestaurantFields(
      restaurant.id,
      {
        'images': nextImages,
        'imageUrl': nextCover,
      },
    );
  }

  Future<void> _removeImage(RestaurantModel restaurant, String imageUrl) async {
    final nextImages = <String>[...restaurant.images]..remove(imageUrl);
    final nextCover = restaurant.imageUrl == imageUrl
        ? (nextImages.isNotEmpty ? nextImages.first : '')
        : restaurant.imageUrl;

    await _firestoreService.updateRestaurantFields(
      restaurant.id,
      {
        'images': nextImages,
        'imageUrl': nextCover,
      },
    );
  }

  Future<void> _reportReview(ReviewModel review) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String reason = 'Nội dung không phù hợp';
    final reasons = <String>[
      'Nội dung không phù hợp',
      'Spam hoặc quảng cáo',
      'Ngôn từ xúc phạm',
      'Thông tin sai sự thật',
      'Khác',
    ];

    final customReasonCtrl = TextEditingController();
    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Báo cáo đánh giá',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...reasons.map(
                    (item) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      value: item,
                      groupValue: reason,
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => reason = value);
                      },
                    ),
                  ),
                  if (reason == 'Khác')
                    TextField(
                      controller: customReasonCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lý do cụ thể',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Gửi báo cáo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldSubmit != true) return;

    final finalReason = reason == 'Khác' && customReasonCtrl.text.trim().isNotEmpty
        ? customReasonCtrl.text.trim()
        : reason;

    await _firestoreService.submitReviewReport(
      reviewId: review.id ?? '',
      reporterId: user.uid,
      reason: finalReason,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi báo cáo đánh giá tới admin.')),
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.orange.shade700),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _metricChip({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildRestaurantSection(RestaurantModel restaurant) {
    final totalMenuItems = restaurant.menu.length;
    final totalImages = restaurant.images.length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade100, Colors.orange.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                restaurant.address,
                style: TextStyle(color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricChip(
                    label: 'Menu',
                    value: '$totalMenuItems món',
                    color: Colors.deepOrange,
                  ),
                  _metricChip(
                    label: 'Ảnh',
                    value: '$totalImages ảnh',
                    color: Colors.blue,
                  ),
                  _metricChip(
                    label: 'Đánh giá',
                    value: '${restaurant.totalReviews}',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
        Card(
          elevation: 0.8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'Thông tin chung',
                  Icons.store_outlined,
                  trailing: TextButton.icon(
                    onPressed: () => _editBasicInfo(restaurant),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tên quán: ${restaurant.name}'),
                Text('Địa chỉ: ${restaurant.address}'),
                if (restaurant.phone.isNotEmpty) Text('SĐT: ${restaurant.phone}'),
                if (restaurant.openingHours.isNotEmpty) Text('Giờ mở cửa: ${restaurant.openingHours}'),
                if (restaurant.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(restaurant.description),
                ],
              ],
            ),
          ),
        ),
        Card(
          elevation: 0.8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'Menu',
                  Icons.restaurant_menu,
                  trailing: ElevatedButton.icon(
                    onPressed: () => _addMenuItem(restaurant),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm món'),
                  ),
                ),
                const SizedBox(height: 8),
                if (restaurant.menu.isEmpty)
                  const Text('Chưa có món nào trong menu.')
                else
                  ...restaurant.menu.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text((item['name'] ?? '').toString()),
                      subtitle: Text(
                        [
                          if ((item['price'] ?? '').toString().isNotEmpty)
                            'Giá: ${item['price']}',
                          if ((item['note'] ?? '').toString().isNotEmpty)
                            'Ghi chú: ${item['note']}',
                        ].join(' • '),
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeMenuItem(restaurant, index),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        Card(
          elevation: 0.8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  'Hình ảnh',
                  Icons.photo_library_outlined,
                  trailing: ElevatedButton.icon(
                    onPressed: () => _addImage(restaurant),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Thêm ảnh'),
                  ),
                ),
                const SizedBox(height: 8),
                if (restaurant.images.isEmpty)
                  const Text('Chưa có ảnh nào.')
                else
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: restaurant.images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final imageUrl = restaurant.images[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                width: 130,
                                height: 110,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 130,
                                  height: 110,
                                  color: Colors.grey.shade200,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: InkWell(
                                onTap: () => _removeImage(restaurant, imageUrl),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      topRight: Radius.circular(10),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            )
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Card(
          elevation: 0.8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Danh sách đánh giá', Icons.rate_review_outlined),
                const SizedBox(height: 8),
                StreamBuilder<List<ReviewModel>>(
                  stream: _firestoreService.getRestaurantReviewsStream(restaurant.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Không thể tải đánh giá: ${snapshot.error}');
                    }
                    final reviews = snapshot.data ?? const <ReviewModel>[];
                    if (reviews.isEmpty) {
                      return const Text('Chưa có đánh giá nào.');
                    }

                    final filteredReviews = reviews.where((review) {
                      switch (_reviewFilter) {
                        case 'low':
                          return review.rating <= 2.0;
                        case 'mid':
                          return review.rating > 2.0 && review.rating < 4.0;
                        case 'high':
                          return review.rating >= 4.0;
                        default:
                          return true;
                      }
                    }).toList();

                    return Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Tất cả'),
                                selected: _reviewFilter == 'all',
                                onSelected: (_) => setState(() => _reviewFilter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('1-2 sao'),
                                selected: _reviewFilter == 'low',
                                onSelected: (_) => setState(() => _reviewFilter = 'low'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('3 sao'),
                                selected: _reviewFilter == 'mid',
                                onSelected: (_) => setState(() => _reviewFilter = 'mid'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('4-5 sao'),
                                selected: _reviewFilter == 'high',
                                onSelected: (_) => setState(() => _reviewFilter = 'high'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (filteredReviews.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Không có đánh giá nào theo bộ lọc đã chọn.'),
                          )
                        else
                          ...filteredReviews.take(10).map((review) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                title: Text(
                                  review.userName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(review.comment, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star, size: 14, color: Colors.amber),
                                              const SizedBox(width: 2),
                                              Text(review.rating.toStringAsFixed(1)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () => _reportReview(review),
                                          icon: const Icon(Icons.flag_outlined, size: 16),
                                          label: const Text('Báo cáo'),
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: Colors.red.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý quán của tôi')),
        body: const Center(child: Text('Vui lòng đăng nhập để quản lý quán.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý quán của tôi')),
      body: StreamBuilder<List<RestaurantModel>>(
        stream: _firestoreService.getOwnerRestaurantsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Không thể tải dữ liệu quán.'));
          }

          final restaurants = snapshot.data ?? const <RestaurantModel>[];
          if (restaurants.isEmpty) {
            return const Center(
              child: Text('Bạn chưa sở hữu quán nào hoặc chưa được duyệt claim.'),
            );
          }

          _selectedRestaurantId ??= restaurants.first.id;
          final selectedRestaurant = restaurants.firstWhere(
            (r) => r.id == _selectedRestaurantId,
            orElse: () => restaurants.first,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: DropdownButtonFormField<String>(
                  value: selectedRestaurant.id,
                  decoration: const InputDecoration(
                    labelText: 'Chọn quán cần quản lý',
                    border: OutlineInputBorder(),
                  ),
                  items: restaurants
                      .map(
                        (r) => DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(r.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRestaurantId = value);
                  },
                ),
              ),
              Expanded(child: _buildRestaurantSection(selectedRestaurant)),
            ],
          );
        },
      ),
    );
  }
}

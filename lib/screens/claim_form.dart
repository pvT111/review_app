import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/claim.dart';
import '../models/restaurants.dart';
import '../services/firestore_service.dart';

class ClaimFormScreen extends StatefulWidget {
  const ClaimFormScreen({super.key});

  @override
  State<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

class _ClaimFormScreenState extends State<ClaimFormScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  RestaurantModel? _selectedRestaurant;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  bool _isSearching = false;
  List<RestaurantModel> _searchResults = [];
  
  XFile? _googleMapsImage;
  XFile? _licenseImage;
  bool _isSubmitting = false;

  Future<void> _pickImage(bool isGoogleMaps) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        if (isGoogleMaps) {
          _googleMapsImage = image;
        } else {
          _licenseImage = image;
        }
      });
    }
  }

  void _search(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _firestoreService.searchRestaurants(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedRestaurant == null) {
      _showError('Vui lòng CHỌN quán ăn từ danh sách gợi ý.');
      return;
    }
    if (_googleMapsImage == null || _licenseImage == null) {
      _showError('Vui lòng cung cấp đầy đủ 2 ảnh minh chứng.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Bạn cần đăng nhập để thực hiện chức năng này.';

      final uploadTasks = await Future.wait([
        _uploadXFile(_googleMapsImage!, 'claims/google_maps'),
        _uploadXFile(_licenseImage!, 'claims/licenses'),
      ]);

      final claim = ClaimModel(
        id: '', 
        userId: user.uid,
        restaurantId: _selectedRestaurant!.id,
        status: 'pending',
        proofImages: uploadTasks,
        submittedAt: DateTime.now(),
      );

      await _firestoreService.submitClaim(claim);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Thành công'),
            content: const Text('Yêu cầu của bạn đã được gửi. Admin sẽ phê duyệt trong vòng 24-48h.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                },
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('Lỗi hệ thống: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String> _uploadXFile(XFile xFile, String folder) async {
    if (kIsWeb) {
      final bytes = await xFile.readAsBytes();
      return await _firestoreService.uploadImage(bytes, folder);
    } else {
      return await _firestoreService.uploadImage(File(xFile.path), folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu cầu nhận quán'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('1. Tìm và chọn quán của bạn'),
              const SizedBox(height: 12),
              
              // Ô tìm kiếm - Chỉ hiện khi chưa chọn quán
              if (_selectedRestaurant == null) ...[
                TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Nhập tên quán (ví dụ: Dumpling...)',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Kết quả tìm kiếm (Nhấn để chọn):', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final r = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.restaurant, color: Colors.orange),
                              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(r.address, maxLines: 1),
                              onTap: () {
                                FocusScope.of(context).unfocus(); // Ẩn bàn phím
                                setState(() {
                                  _selectedRestaurant = r;
                                  _searchResults = [];
                                  _searchController.text = r.name;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],

              // Trạng thái ĐÃ CHỌN QUÁN
              if (_selectedRestaurant != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đã chọn quán:', style: TextStyle(fontSize: 12, color: Colors.green)),
                            Text(_selectedRestaurant!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_selectedRestaurant!.address, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedRestaurant = null),
                        child: const Text('Thay đổi', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              _buildSectionTitle('2. Minh chứng quyền sở hữu'),
              const Text('Tải lên ảnh quản lý Google Maps và Giấy phép/Ảnh quán.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildImageSelector('Ảnh Google Maps', _googleMapsImage, () => _pickImage(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildImageSelector('Giấy phép/Ảnh quán', _licenseImage, () => _pickImage(false))),
                ],
              ),

              const SizedBox(height: 32),
              _buildSectionTitle('3. Ghi chú (không bắt buộc)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập thông tin xác minh thêm...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Gửi xác minh ngay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold));
  }

  Widget _buildImageSelector(String label, XFile? image, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: image != null ? Colors.green : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: image != null 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  kIsWeb ? Image.network(image.path, fit: BoxFit.cover) : Image.file(File(image.path), fit: BoxFit.cover),
                  Container(color: Colors.black26),
                  const Center(child: Icon(Icons.edit, color: Colors.white)),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
      ),
    );
  }
}

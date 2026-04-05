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
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
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
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await _firestoreService.searchRestaurants(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedRestaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn quán')));
      return;
    }
    if (_googleMapsImage == null || _licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn đủ 2 ảnh minh chứng')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Upload ảnh
      String googleMapsUrl = await _uploadXFile(_googleMapsImage!, 'claims/google_maps');
      String licenseUrl = await _uploadXFile(_licenseImage!, 'claims/licenses');

      final claim = ClaimModel(
        id: '',
        userId: user?.uid ?? '',
        restaurantId: _selectedRestaurant!.id,
        status: 'pending',
        proofImages: [googleMapsUrl, licenseUrl],
        submittedAt: DateTime.now(),
      );

      await _firestoreService.submitClaim(claim);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gửi yêu cầu thành công!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
      appBar: AppBar(title: const Text('Nhận quán')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. Tìm quán của bạn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tên quán...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _search(_searchController.text),
                    icon: const Icon(Icons.search),
                    style: IconButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ],
              ),
              if (_isSearching) const LinearProgressIndicator(),
              if (_searchResults.isNotEmpty && _selectedRestaurant == null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final r = _searchResults[index];
                      return ListTile(
                        title: Text(r.name),
                        subtitle: Text(r.address),
                        onTap: () => setState(() {
                          _selectedRestaurant = r;
                          _searchResults = [];
                          _searchController.text = r.name;
                        }),
                      );
                    },
                  ),
                ),
              if (_selectedRestaurant != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      title: Text(_selectedRestaurant!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_selectedRestaurant!.address),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _selectedRestaurant = null),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 40),
              const Text('2. Ảnh minh chứng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildImageSelector('Ảnh Business Profile Google Maps', _googleMapsImage, () => _pickImage(true)),
              const SizedBox(height: 20),
              const Text('3. Ghi chú thêm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Nhập thông tin bổ sung nếu có...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                  child: _isSubmitting 
                    ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(width: 10), Text('Đang upload...')])
                    : const Text('Gửi yêu cầu nhận quán', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelector(String label, XFile? image, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: image != null ? Colors.green : Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: image != null 
          ? kIsWeb 
            ? Stack(children: [Image.network(image.path, fit: BoxFit.cover, width: double.infinity), Center(child: Container(padding: const EdgeInsets.all(4), color: Colors.black45, child: const Text('Đã chọn (Click để thay đổi)', style: TextStyle(color: Colors.white, fontSize: 12))))])
            : Stack(children: [Image.file(File(image.path), fit: BoxFit.cover, width: double.infinity), Center(child: Container(padding: const EdgeInsets.all(4), color: Colors.black45, child: const Text('Đã chọn (Click để thay đổi)', style: TextStyle(color: Colors.white, fontSize: 12))))])
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                const SizedBox(height: 5),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ],
            ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/users.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'auth.dart';
import 'claim_form.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'restaurant_list_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  static const List<Widget> _pages = [
    HomePage(), 
    MapPage(),  
    RestaurantListPage(), 
    Center(child: Text('Account Page')), 
  ];

  void _onItemTapped(int index) {
    if (index == 3) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      } else {
        _showAccountPopup();
      }
      return; 
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAccountPopup() {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<UserModel?>(
          future: _firestoreService.getUser(user?.uid ?? ''),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final userData = snapshot.data;
            final isOwner = userData?.role == 'owner';

            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(userData?.name ?? 'Người dùng'),
                      subtitle: Text(user?.email ?? ''),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Thông tin cá nhân'),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.rate_review_outlined),
                      title: const Text('Lịch sử đánh giá'),
                      onTap: () => Navigator.pop(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_business_outlined),
                      title: const Text('Đăng ký chủ quán'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ClaimFormScreen()),
                        );
                      },
                    ),
                    if (isOwner)
                      ListTile(
                        leading: const Icon(Icons.store_outlined),
                        title: const Text('Quản lý quán của tôi'),
                        onTap: () => Navigator.pop(context),
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                      onTap: () async {
                        Navigator.pop(context);
                        await _authService.signOut();
                        if (mounted) {
                          setState(() => _selectedIndex = 0);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange.shade800,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Bản đồ'),
          BottomNavigationBarItem(icon: Icon(Icons.rate_review_outlined), activeIcon: Icon(Icons.rate_review), label: 'Đánh giá'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
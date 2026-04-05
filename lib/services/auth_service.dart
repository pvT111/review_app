import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/users.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Đăng nhập Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Với Google, ta lấy name trực tiếp từ userCredential
      await _syncUserToFirestore(userCredential.user, name: userCredential.user?.displayName);
      
      return userCredential;
    } catch (e) {
      print("DEBUG: Google Sign-In Error -> $e");
      rethrow;
    }
  }

  // Đăng ký Email
  Future<UserCredential?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Cập nhật Profile trong Firebase Auth
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();
      
      // Đồng bộ sang Firestore với tên người dùng đã nhập
      await _syncUserToFirestore(_auth.currentUser, name: name);
      
      return userCredential;
    } catch (e) {
      print("DEBUG: Register Error -> $e");
      rethrow;
    }
  }

  // Đăng nhập Email
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Đồng bộ thông tin (nếu cần cập nhật lastSeen/updatedAt)
      await _syncUserToFirestore(userCredential.user);
      
      return userCredential;
    } catch (e) {
      print("DEBUG: Login Error -> $e");
      rethrow;
    }
  }

  // Hàm đồng bộ dữ liệu người dùng sang Firestore
  Future<void> _syncUserToFirestore(User? firebaseUser, {String? name}) async {
    if (firebaseUser == null) return;

    final userRef = _db.collection('users').doc(firebaseUser.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      // Nếu user chưa tồn tại (Đăng ký mới hoặc lần đầu Google)
      final newUser = UserModel(
        uid: firebaseUser.uid,
        name: name ?? firebaseUser.displayName ?? 'Người dùng mới',
        email: firebaseUser.email ?? '',
        avatarUrl: firebaseUser.photoURL ?? '',
        role: 'customer',
        ownerOf: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userRef.set(newUser.toMap());
    } else {
      // Nếu user đã tồn tại, chỉ cập nhật updatedAt và các thông tin thay đổi (nếu có)
      Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Nếu có truyền name mới vào (ví dụ lúc đăng ký), cập nhật luôn
      if (name != null) updates['name'] = name;
      
      await userRef.update(updates);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Stream<User?> get user => _auth.authStateChanges();
}

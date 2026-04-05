import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLogin = true; 
  bool _isLoading = false;
  
  String _email = '';
  String _password = '';
  String _name = '';

  void _switchAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(_email, _password);
      } else {
        await _authService.registerWithEmailAndPassword(_email, _password, _name);
      }
      if (mounted) {
        Navigator.of(context).pop(); // Quay về Home sau khi đăng nhập thành công
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Đã xảy ra lỗi!';
      if (e.code == 'user-not-found') message = 'Không tìm thấy người dùng.';
      else if (e.code == 'wrong-password') message = 'Mật khẩu không đúng.';
      else if (e.code == 'email-already-in-use') message = 'Email đã được sử dụng.';
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pop(); // Quay về Home sau khi đăng nhập thành công
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi Google Sign-In: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Đăng nhập' : 'Đăng ký')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLogin)
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                        validator: (val) => val!.isEmpty ? 'Vui lòng nhập tên' : null,
                        onSaved: (val) => _name = val!,
                      ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => !val!.contains('@') ? 'Email không hợp lệ' : null,
                      onSaved: (val) => _email = val!,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Mật khẩu'),
                      obscureText: true,
                      validator: (val) => val!.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
                      onSaved: (val) => _password = val!,
                    ),
                    const SizedBox(height: 20),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_isLogin ? 'Đăng nhập' : 'Đăng ký'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _switchAuthMode,
                        child: Text(_isLogin ? 'Chưa có tài khoản? Đăng ký ngay' : 'Đã có tài khoản? Đăng nhập'),
                      ),
                      const Divider(),
                      const Text('Hoặc'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _handleGoogleSignIn,
                        icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                          height: 20,
                        ),
                        label: const Text('Tiếp tục với Google'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// login_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/auth/services/google_auth_service.dart';
import 'package:here4help/auth/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final savedEmail = prefs.getString('remember_email') ?? '';
      final savedPass = prefs.getString('remember_password') ?? '';
      final savedFlag = prefs.getBool('remember_me') ?? false;

      if (savedFlag) {
        setState(() {
          emailController.text = savedEmail;
          passwordController.text = savedPass;
          rememberMe = savedFlag;
        });
      }
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      _handleLogin(email, password);
    }
  }

  Future<void> _handleLogin(String email, String password) async {
    setState(() {
      isLoading = true;
    });

    try {
      // 先測試網路連線
      print('🔍 開始測試網路連線...');
      final isConnected = await AuthService.testConnection();
      if (!isConnected) {
        throw Exception('無法連接到伺服器，請檢查網路連線');
      }
      print('✅ 網路連線正常');

      // 執行登入
      final authData = await AuthService.login(email, password);
      final user = authData['user'];

      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remember_email', email);
        await prefs.setString('remember_password', password);
        await prefs.setBool('remember_me', true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remember_email');
        await prefs.remove('remember_password');
        await prefs.setBool('remember_me', false);
      }

      // 更新 Provider
      Provider.of<UserService>(context, listen: false).setUser(UserModel(
        id: user['id'],
        name: user['name'],
        nickname: user['nickname'] ?? user['name'],
        email: user['email'],
        phone: user['phone'] ?? '',
        points: user['points'] ?? 0,
        avatar_url: user['avatar'] ?? '',
        status: user['status'] ?? 'active',
        provider: user['provider'] ?? 'email',
        created_at: user['created_at'] ?? '',
        updated_at: user['updated_at'] ?? '',
        referral_code: user['referral_code'],
        google_id: user['google_id'],
        primary_language: user['primary_language'] ?? 'English',
        permission_level: user['permission'] ?? 0,
      ));

      // 儲存用戶 email 到 SharedPreferences（用於路由重定向）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user['email']);
      print('💾 用戶 email 已儲存: ${user['email']}');

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入成功：$email')),
      );

      print('🚀 準備跳轉到首頁...');
      print('📍 當前路徑: ${GoRouterState.of(context).uri.path}');

      context.go('/home');

      print('✅ 跳轉指令已執行');
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      String errorMessage = '登入失敗';
      if (e.toString().contains('Invalid email or password')) {
        errorMessage = '帳號或密碼錯誤';
      } else if (e.toString().contains('No token available')) {
        errorMessage = '認證失敗，請重新登入';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Widget _buildSocialButton(
      IconData icon, String label, VoidCallback? onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(icon, color: Colors.black54),
            ),
            Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Google 登入處理
  Future<void> _handleGoogleLogin() async {
    setState(() {
      isLoading = true;
    });

    try {
      final googleAuthService = GoogleAuthService();
      final userData = await googleAuthService.signInWithGoogle();

      if (userData != null) {
        // 儲存用戶資料到本地
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'auth_token', 'Bearer ${userData['token'] ?? ''}');
        await prefs.setString('user_email', userData['email'] ?? '');
        await prefs.setInt('user_permission', userData['permission'] ?? 0);
        await prefs.setString('user_name', userData['name'] ?? '');
        await prefs.setInt('user_points', userData['points'] ?? 0);
        await prefs.setString('user_avatarUrl', userData['avatar_url'] ?? '');
        await prefs.setString(
            'user_primaryLang', userData['primary_language'] ?? '');

        // 更新 Provider
        Provider.of<UserService>(context, listen: false).setUser(UserModel(
          id: userData['id'],
          name: userData['name'],
          nickname: userData['nickname'] ?? userData['name'],
          email: userData['email'],
          phone: userData['phone'] ?? '',
          points: userData['points'] ?? 0,
          avatar_url: userData['avatar_url'] ?? '',
          status: userData['status'] ?? 'active',
          provider: userData['provider'] ?? 'email',
          created_at: userData['created_at'] ?? '',
          updated_at: userData['updated_at'] ?? '',
          referral_code: userData['referral_code'],
          google_id: userData['google_id'],
          primary_language: userData['primary_language'] ?? 'English',
          permission_level: userData['permission'] ?? 0,
        ));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 登入成功：${userData['email']}')),
        );
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google 登入失敗，請重試')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 登入錯誤: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                Image.asset(
                  'assets/icon/app_icon_bordered.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Here4Help',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Account',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入帳號';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submitForm(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入密碼';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submitForm(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value ?? false;
                    });
                  },
                ),
                const Text('Remember me'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submitForm,
                child: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(thickness: 1),
            const SizedBox(height: 12),
            const Text(
              'SIGN UP WITH',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // 第三方登入按鈕
            Column(
              children: [
                _buildSocialButton(
                    Icons.g_mobiledata, 'Google', _handleGoogleLogin),
                _buildSocialButton(Icons.facebook, 'Facebook', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Facebook 登入功能正在開發中...')),
                  );
                }),
                _buildSocialButton(Icons.email, 'Email', () {
                  context.go('/signup');
                }),
                _buildSocialButton(Icons.apple, 'Apple', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Apple 登入功能正在開發中...')),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

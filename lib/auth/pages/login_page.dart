// login_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/auth/services/third_party_auth_service.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'dart:async';

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
  Timer? _timeoutTimer;

  // 登入超時設定（秒）
  static const int _loginTimeoutSeconds = 30;

  // 跨平台第三方登入服務
  final ThirdPartyAuthService _platformAuthService = ThirdPartyAuthService();

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

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      _handleLogin(email, password);
    }
  }

  /// 開始登入超時計時器
  void _startLoginTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: _loginTimeoutSeconds), () {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Login Timeout, Please Check Network Connection and Try Again'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });
  }

  /// 停止登入超時計時器
  void _stopLoginTimeout() {
    _timeoutTimer?.cancel();
  }

  Future<void> _handleLogin(String email, String password) async {
    // 防止重複點擊
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    // 開始超時計時器
    _startLoginTimeout();

    try {
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
        avatar_url: user['avatar_url'] ?? '',
        status: user['status'] ?? 'active',
        provider: user['provider'] ?? 'email',
        created_at: user['created_at'] ?? '',
        updated_at: user['updated_at'] ?? '',
        referral_code: user['referral_code'],
        google_id: user['google_id'],
        primary_language: user['primary_language'] ?? 'English',
        permission: user['permission'] ?? 0,
      ));

      // 同步 PermissionProvider 權限狀態
      final permissionProvider =
          Provider.of<PermissionProvider>(context, listen: false);
      permissionProvider.syncWithBackendResponse(authData);

      // 儲存用戶 email 到 SharedPreferences（用於路由重定向）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', user['email']);

      // 停止超時計時器
      _stopLoginTimeout();

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login Success: $email')),
      );

      context.go('/home');
    } catch (e) {
      // 停止超時計時器
      _stopLoginTimeout();

      setState(() {
        isLoading = false;
      });

      String errorMessage = 'Login Failed';
      if (e.toString().contains('Invalid email or password')) {
        errorMessage = 'Invalid email or password';
      } else if (e.toString().contains('No token available')) {
        errorMessage = 'Authentication failed, please login again';
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
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                icon,
                color: isLoading ? Colors.grey : Colors.black54,
              ),
            ),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isLoading ? Colors.grey : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 跨平台 Google 登入處理
  Future<void> _handleGoogleLogin() async {
    // 防止重複點擊
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    // 開始超時計時器
    _startLoginTimeout();

    try {
      final userData = await _platformAuthService.signInWithProvider('google');

      if (userData != null) {
        // 檢查是否為新用戶，如果是則導向註冊頁面
        if (userData['is_new_user'] == true) {
          // 將 Google 資料傳遞到註冊頁面
          await _saveGoogleDataForSignup(userData);
          context.go('/signup/oauth');
        } else {
          // 現有用戶，使用 AuthService 正確儲存登入資訊
          debugPrint('✅ Google 登入成功，儲存用戶資料...');

          // 安全地顯示 token 預覽（避免 RangeError）
          final token = userData['token'] ?? '';
          final tokenPreview =
              token.length > 20 ? token.substring(0, 20) : token;
          debugPrint('🔑 Token preview: ${tokenPreview}...');

          // 使用 AuthService 儲存 token（不添加 Bearer 前綴，避免雙重前綴問題）
          await AuthService.saveToken(userData['token'] ?? '');
          await AuthService.saveUserData(userData);

          // 儲存額外的用戶資訊到 SharedPreferences（用於兼容現有邏輯）
          final prefs = await SharedPreferences.getInstance();
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
            provider: userData['provider'] ?? 'google',
            created_at: userData['created_at'] ?? '',
            updated_at: userData['updated_at'] ?? '',
            referral_code: userData['referral_code'],
            google_id: userData['google_id'],
            primary_language: userData['primary_language'] ?? 'English',
            permission: userData['permission'] ?? 0,
          ));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Google Login Success: ${userData['email']}')),
          );
          context.go('/home');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Google Login Failed, Please Try Again')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Login Error: $e')),
      );
    } finally {
      // 停止超時計時器
      _stopLoginTimeout();

      setState(() {
        isLoading = false;
      });
    }
  }

  // 新增：儲存 Google 資料到註冊頁面
  Future<void> _saveGoogleDataForSignup(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('signup_full_name', userData['name'] ?? '');
    await prefs.setString('signup_nickname', userData['name'] ?? '');
    await prefs.setString('signup_email', userData['email'] ?? '');
    await prefs.setString('signup_avatar_url', userData['avatar_url'] ?? '');
    await prefs.setString('signup_provider', 'google');
    await prefs.setString(
        'signup_provider_user_id', userData['provider_user_id'] ?? '');
  }

  // 跨平台 Facebook 登入處理
  Future<void> _handleFacebookLogin() async {
    // 防止重複點擊
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    // 開始超時計時器
    _startLoginTimeout();

    try {
      final userData =
          await _platformAuthService.signInWithProvider('facebook');

      if (userData != null) {
        // 檢查是否為新用戶，如果是則導向註冊頁面
        if (userData['is_new_user'] == true) {
          // 將 Facebook 資料傳遞到註冊頁面
          await _saveFacebookDataForSignup(userData);
          context.go('/signup/oauth');
        } else {
          // 現有用戶，使用 AuthService 正確儲存登入資訊
          debugPrint('✅ Facebook 登入成功，儲存用戶資料...');

          // 安全地顯示 token 預覽（避免 RangeError）
          final token = userData['token'] ?? '';
          final tokenPreview =
              token.length > 20 ? token.substring(0, 20) : token;
          debugPrint('🔑 Token preview: ${tokenPreview}...');

          // 使用 AuthService 儲存 token（不添加 Bearer 前綴，避免雙重前綴問題）
          await AuthService.saveToken(userData['token'] ?? '');
          await AuthService.saveUserData(userData);

          // 儲存額外的用戶資訊到 SharedPreferences（用於兼容現有邏輯）
          final prefs = await SharedPreferences.getInstance();
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
            provider: userData['provider'] ?? 'facebook',
            created_at: userData['created_at'] ?? '',
            updated_at: userData['updated_at'] ?? '',
            referral_code: userData['referral_code'],
            google_id: userData['google_id'],
            primary_language: userData['primary_language'] ?? 'English',
            permission: userData['permission'] ?? 0,
          ));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Facebook Login Success: ${userData['email'] ?? userData['name']}')),
          );
          context.go('/home');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Facebook Login Failed, Please Try Again')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Facebook Login Error: $e')),
      );
    } finally {
      // 停止超時計時器
      _stopLoginTimeout();

      setState(() {
        isLoading = false;
      });
    }
  }

  // 新增：儲存 Facebook 資料到註冊頁面
  Future<void> _saveFacebookDataForSignup(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('signup_full_name', userData['name'] ?? '');
    await prefs.setString('signup_nickname', userData['name'] ?? '');
    await prefs.setString('signup_email', userData['email'] ?? '');
    await prefs.setString('signup_avatar_url', userData['avatar_url'] ?? '');
    await prefs.setString('signup_provider', 'facebook');
    await prefs.setString(
        'signup_provider_user_id', userData['provider_user_id'] ?? '');
  }

  // 跨平台 Apple 登入處理
  Future<void> _handleAppleLogin() async {
    // 防止重複點擊
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    // 開始超時計時器
    _startLoginTimeout();

    try {
      final userData = await _platformAuthService.signInWithProvider('apple');

      if (userData != null) {
        // 檢查是否為新用戶，如果是則導向註冊頁面
        if (userData['is_new_user'] == true) {
          // 將 Apple 資料傳遞到註冊頁面
          await _saveAppleDataForSignup(userData);
          context.go('/signup/oauth');
        } else {
          // 現有用戶，使用 AuthService 正確儲存登入資訊
          debugPrint('✅ Apple 登入成功，儲存用戶資料...');

          // 安全地顯示 token 預覽（避免 RangeError）
          final token = userData['token'] ?? '';
          final tokenPreview =
              token.length > 20 ? token.substring(0, 20) : token;
          debugPrint('🔑 Token preview: ${tokenPreview}...');

          // 使用 AuthService 儲存 token（不添加 Bearer 前綴，避免雙重前綴問題）
          await AuthService.saveToken(userData['token'] ?? '');
          await AuthService.saveUserData(userData);

          // 儲存額外的用戶資訊到 SharedPreferences（用於兼容現有邏輯）
          final prefs = await SharedPreferences.getInstance();
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
            provider: userData['provider'] ?? 'apple',
            created_at: userData['created_at'] ?? '',
            updated_at: userData['updated_at'] ?? '',
            referral_code: userData['referral_code'],
            google_id: userData['google_id'],
            primary_language: userData['primary_language'] ?? 'English',
            permission: userData['permission'] ?? 0,
          ));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Apple Login Success: ${userData['email'] ?? userData['name']}')),
          );
          context.go('/home');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple Login Failed, Please Try Again')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple Login Error: $e')),
      );
    } finally {
      // 停止超時計時器
      _stopLoginTimeout();

      setState(() {
        isLoading = false;
      });
    }
  }

  // 新增：儲存 Apple 資料到註冊頁面
  Future<void> _saveAppleDataForSignup(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('signup_full_name', userData['name'] ?? '');
    await prefs.setString('signup_nickname', userData['name'] ?? '');
    await prefs.setString('signup_email', userData['email'] ?? '');
    await prefs.setString('signup_avatar_url', userData['avatar_url'] ?? '');
    await prefs.setString('signup_provider', 'apple');
    await prefs.setString(
        'signup_provider_user_id', userData['provider_user_id'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // App 圖示置中顯示
                            Image(
                              image: const AssetImage(
                                  'assets/icon/app_icon_bordered.png'),
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.image_not_supported,
                                      size: 56),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Here4Help',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return 'Please enter a valid email format';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submitForm(),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submitForm(),
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  rememberMe = value ?? false;
                                });
                              },
                              title: const Text('Remember me'),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: isLoading ? null : _submitForm,
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
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
                            // 跨平台第三方登入按鈕
                            Column(
                              children: [
                                _buildSocialButton(Icons.g_mobiledata, 'Google',
                                    _handleGoogleLogin),
                                _buildSocialButton(Icons.facebook, 'Facebook',
                                    _handleFacebookLogin),
                                _buildSocialButton(Icons.email, 'Email', () {
                                  context.go('/signup');
                                }),
                                // 只在 iOS 和 Web 顯示 Apple 登入
                                if (_platformAuthService.isIOS ||
                                    _platformAuthService.isWeb)
                                  _buildSocialButton(
                                      Icons.apple, 'Apple', _handleAppleLogin),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 全螢幕 Loading 遮罩
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Logging in...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

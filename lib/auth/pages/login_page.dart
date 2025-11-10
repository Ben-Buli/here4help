// login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/auth/services/third_party_auth_service.dart';
import 'package:here4help/auth/services/signup_draft_service.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/providers/permission_provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginEmailKey = GlobalKey<FormFieldState<String>>();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;
  bool showPassword = false;
  Timer? _timeoutTimer;

  static const double _socialButtonHeight = 52;
  static const Color _googleTextColor = Color(0xFF3C4043);
  static const Color _googleBorderColor = Color(0xFFDADCE0);
  static const Color _facebookBlue = Color(0xFF1877F2);
  static const Color _appleBlack = Color(0xFF000000);

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
      String errorType =
          'general'; // 'general', 'deleted_by_admin', 'self_deleted'

      final errorString = e.toString();

      // 檢查是否為已刪除帳號的錯誤
      if (errorString.contains('removed by an administrator')) {
        errorMessage =
            'This account has been soft deleted by an administrator and cannot be used. Please contact support if you believe this is an error.';
        errorType = 'deleted_by_admin';
      } else if (errorString.contains('has been deleted and cannot be used')) {
        errorMessage =
            'This account has been soft deleted and cannot be used. If you wish to use our service again, please create a new account.';
        errorType = 'self_deleted';
      } else if (errorString.contains('Invalid email or password')) {
        errorMessage = 'Invalid email or password';
      } else if (errorString.contains('No token available')) {
        errorMessage = 'Authentication failed, please login again';
      } else {
        // 顯示後端返回的原始錯誤訊息
        errorMessage = errorString.replaceAll('Exception: ', '');
      }

      // 顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor:
              errorType == 'deleted_by_admin' || errorType == 'self_deleted'
                  ? Colors.red.shade700
                  : null,
          duration:
              errorType == 'deleted_by_admin' || errorType == 'self_deleted'
                  ? const Duration(seconds: 6)
                  : const Duration(seconds: 3),
          action: errorType == 'deleted_by_admin'
              ? SnackBarAction(
                  label: 'Contact Support',
                  textColor: Colors.white,
                  onPressed: () {
                    // 可以導向到客服頁面
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                )
              : null,
        ),
      );
    }
  }

  Widget _buildBrandedButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
  }) {
    final bool disableInteraction = isLoading || onPressed == null;
    final Color effectiveTextColor =
        disableInteraction ? textColor.withOpacity(0.6) : textColor;
    final Color? effectiveBorderColor = borderColor != null
        ? (disableInteraction ? borderColor.withOpacity(0.6) : borderColor)
        : null;

    final borderRadius = BorderRadius.circular(8);
    final Color effectiveBackgroundColor =
        disableInteraction ? backgroundColor.withOpacity(0.6) : backgroundColor;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: effectiveBackgroundColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: effectiveBorderColor != null
              ? BorderSide(color: effectiveBorderColor, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: disableInteraction ? null : onPressed,
          borderRadius: borderRadius,
          child: SizedBox(
            height: _socialButtonHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Opacity(
                      opacity: disableInteraction ? 0.6 : 1,
                      child: icon,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return _buildBrandedButton(
      onPressed: _handleGoogleLogin,
      icon: SvgPicture.asset(
        'assets/third-party-login-icon/google_icon.svg',
        width: 24,
        height: 24,
      ),
      label: 'Sign in with Google',
      backgroundColor: Colors.white,
      textColor: _googleTextColor,
      borderColor: _googleBorderColor,
    );
  }

  Widget _buildFacebookButton() {
    return _buildBrandedButton(
      onPressed: _handleFacebookLogin,
      icon: SvgPicture.asset(
        'assets/third-party-login-icon/facebook_icon.svg',
        width: 24,
        height: 24,
      ),
      label: 'Continue with Facebook',
      backgroundColor: _facebookBlue,
      textColor: Colors.white,
    );
  }

  Widget _buildAppleButton() {
    return _buildBrandedButton(
      onPressed: _handleAppleLogin,
      icon: SvgPicture.asset(
        'assets/third-party-login-icon/apple_icon.svg',
        width: 20,
        height: 20,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
      label: 'Sign in with Apple',
      backgroundColor: _appleBlack,
      textColor: Colors.white,
    );
  }

  Widget _buildEmailButton() {
    return _buildBrandedButton(
      onPressed: () {
        unawaited(_handleEmailSignupNavigation());
      },
      icon: const Icon(
        Icons.mail_outline,
        size: 24,
        color: _googleTextColor,
      ),
      label: 'Sign up with Email',
      backgroundColor: Colors.white,
      textColor: _googleTextColor,
      borderColor: _googleBorderColor,
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

      // Web 平台特殊處理：OAuth popup 流程
      if (kIsWeb && userData != null && userData['oauth_started'] == true) {
        // Web 平台使用 OAuth popup，等待 popup 結果
        debugPrint('🌐 Web 平台：OAuth popup 已開啟，等待結果...');

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在開啟 Google 登入視窗...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 處理 popup 視窗返回的 OAuth 結果
      debugPrint('🔍 檢查 OAuth 結果: userData = $userData');
      debugPrint('🔍 userData 類型: ${userData.runtimeType}');
      debugPrint('🔍 userData 包含 data: ${userData?['data'] != null}');

      if (kIsWeb && userData != null && userData['data'] != null) {
        final rawOauthData = userData['data'];
        final oauthData = rawOauthData is Map
            ? Map<String, dynamic>.from(rawOauthData)
            : null;
        debugPrint('🔍 OAuth 數據: $oauthData');

        if (oauthData != null) {
          if (oauthData['success'] == true) {
            // OAuth 成功，處理登入結果
            debugPrint('🔍 調用 _handleOAuthSuccess');
            await _handleOAuthSuccess(oauthData);
            return;
          } else {
            // OAuth 失敗
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google 登入失敗: ${oauthData['error'] ?? '未知錯誤'}'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } else {
          debugPrint('❌ OAuth 數據轉換失敗');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google 登入數據解析失敗'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // 如果沒有進入上面的條件，檢查是否直接包含 OAuth 數據
      if (kIsWeb && userData != null && userData['success'] == true) {
        debugPrint('🔍 直接處理 OAuth 數據: $userData');
        // 安全地轉換 LinkedMap 為 Map<String, dynamic>
        final safeUserData = Map<String, dynamic>.from(userData);
        await _handleOAuthSuccess(safeUserData);
        return;
      }

      if (userData != null) {
        // 檢查是否為新用戶，如果是則導向註冊頁面
        if (userData['is_new_user'] == true) {
          final tempToken = _extractOAuthTempToken(userData);
          if (tempToken == null) {
            debugPrint('❌ 缺少 OAuth 暫存 token，無法導向註冊流程');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('暫存登入資料缺失，請重新嘗試 Google 登入'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          } else {
            final provider = (userData['provider'] ?? 'google').toString();
            await _saveGoogleDataForSignup(userData);
            final prefillData =
                _buildSignupPrefillData(userData, provider, tempToken);
            final uri = Uri(
              path: '/signup',
              queryParameters: {
                'token': tempToken,
                'provider': provider,
                'is_new_user': 'true',
              },
            );
            context.go(uri.toString(), extra: prefillData);
            return;
          }
        } else {
          // 現有用戶，使用 AuthService 正確儲存登入資訊
          debugPrint('✅ Google 登入成功，儲存用戶資料...');

          // 安全地顯示 token 預覽（避免 RangeError）
          final token = userData['token'] ?? '';
          final tokenPreview =
              token.length > 20 ? token.substring(0, 20) : token;
          debugPrint('🔑 Token preview: $tokenPreview...');

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
          // 使用 hash 路由重定向到主頁
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

  // 處理 OAuth popup 成功結果
  Future<void> _handleOAuthSuccess(Map<String, dynamic> oauthData) async {
    try {
      debugPrint('🔍 _handleOAuthSuccess 接收到的數據: $oauthData');

      final isNewUser = oauthData['is_new_user'] == true;
      final provider = oauthData['provider'] ?? 'google';

      if (isNewUser) {
        // 新用戶：重定向到註冊頁面（使用 hash 路由）
        final token = oauthData['oauth_token'] ?? oauthData['token'];
        if (token != null) {
          debugPrint('🔄 新用戶重定向到註冊頁面: token=$token, provider=$provider');
          await _saveOAuthDataForSignup(oauthData, provider);
          final prefillData =
              _buildSignupPrefillData(oauthData, provider, token);
          // 使用 hash 路由重定向
          final signupUri = Uri(
            path: '/signup',
            queryParameters: {
              'token': token,
              'provider': provider,
              'is_new_user': 'true',
            },
          );
          context.go(signupUri.toString(), extra: prefillData);
        } else {
          throw Exception('OAuth token 缺失');
        }
      } else {
        // 現有用戶：處理登入
        final rawUserData = oauthData['user_data'];
        final userData =
            rawUserData is Map ? Map<String, dynamic>.from(rawUserData) : null;
        final token = oauthData['token'];

        if (userData != null && token != null) {
          // 使用 AuthService 儲存登入資訊
          await AuthService.saveToken(token);
          await AuthService.saveUserData(userData);

          // 儲存用戶資訊到 SharedPreferences
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
                content: Text(
                    '${provider.toUpperCase()} 登入成功: ${userData['email']}')),
          );
          context.go('/home');
        } else {
          throw Exception('用戶資料或 token 缺失');
        }
      }
    } catch (e) {
      debugPrint('❌ 處理 OAuth 成功結果失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('處理登入結果失敗: $e')),
      );
    }
  }

  String? _extractOAuthTempToken(Map<String, dynamic> data) {
    final dynamic tempToken = data['temp_token'] ?? data['oauth_token'];
    if (tempToken is String && tempToken.isNotEmpty) {
      return tempToken;
    }
    return null;
  }

  Future<void> _saveOAuthDataForSignup(
      Map<String, dynamic> userData, String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await SignupDraftService.clearWithPrefs(prefs, includeOAuth: true);
    await prefs.setString('signup_full_name', userData['name'] ?? '');
    await prefs.setString('signup_nickname', userData['name'] ?? '');
    await prefs.setString('signup_email', userData['email'] ?? '');
    await prefs.setString('signup_avatar_url', userData['avatar_url'] ?? '');
    await prefs.setString('signup_provider', provider);

    final providerUserId = userData['provider_user_id'] ?? userData['id'];
    if (providerUserId != null) {
      await prefs.setString('signup_provider_user_id', '$providerUserId');
    } else {
      await prefs.remove('signup_provider_user_id');
    }

    final tempToken = _extractOAuthTempToken(userData);
    if (tempToken != null) {
      await prefs.setString('signup_oauth_token', tempToken);
    } else {
      await prefs.remove('signup_oauth_token');
    }

    final expiresAt = userData['temp_expires_at'];
    if (expiresAt is String && expiresAt.isNotEmpty) {
      await prefs.setString('signup_oauth_token_expires_at', expiresAt);
    } else {
      await prefs.remove('signup_oauth_token_expires_at');
    }
  }

  // 新增：儲存 Google 資料到註冊頁面
  Future<void> _saveGoogleDataForSignup(Map<String, dynamic> userData) async {
    await _saveOAuthDataForSignup(userData, 'google');
  }

  Future<void> _handleEmailSignupNavigation() async {
    await SignupDraftService.clear(includeOAuth: true);
    if (!mounted) return;
    context.go('/signup');
  }

  Map<String, dynamic> _buildSignupPrefillData(
    Map<String, dynamic> raw,
    String provider,
    String token,
  ) {
    final sanitized = <String, dynamic>{
      'provider': provider,
      'is_new_user': true,
      'oauth_token': token,
      'token': token,
    };

    void addString(String key, [String? alias]) {
      final value = raw[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          sanitized[alias ?? key] = trimmed;
        }
      }
    }

    void addIfPresent(String key) {
      final value = raw[key];
      if (value != null && value.toString().isNotEmpty) {
        sanitized[key] = value;
      }
    }

    addString('name');
    addString('full_name');
    addString('nickname');
    addString('email');
    addString('avatar_url');
    addString('phone');
    addString('country');
    addString('gender');
    addString('address');
    addString('primary_language');
    addString('language');
    addString('date_of_birth', 'birthday');
    addString('birthday');

    addIfPresent('provider_user_id');
    addIfPresent('existing_user_id');
    addIfPresent('email_verified');
    addIfPresent('temp_expires_at');

    return sanitized;
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

      // Web 平台特殊處理：OAuth popup 流程
      if (kIsWeb && userData != null && userData['oauth_started'] == true) {
        // Web 平台使用 OAuth popup，等待 popup 結果
        debugPrint('🌐 Web 平台：Facebook OAuth popup 已開啟，等待結果...');

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在開啟 Facebook 登入視窗...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 處理 popup 視窗返回的 OAuth 結果
      debugPrint('🔍 檢查 Facebook OAuth 結果: userData = $userData');
      debugPrint('🔍 userData 類型: ${userData.runtimeType}');
      debugPrint('🔍 userData 包含 data: ${userData?['data'] != null}');

      if (kIsWeb && userData != null && userData['data'] != null) {
        final rawOauthData = userData['data'];
        final oauthData = rawOauthData is Map
            ? Map<String, dynamic>.from(rawOauthData)
            : null;
        debugPrint('🔍 Facebook OAuth 數據: $oauthData');

        if (oauthData != null) {
          await _handleOAuthSuccess(oauthData);
        }
        return;
      }

      // 處理直接返回的登入結果（非 popup 模式）
      if (userData != null && userData['success'] == true) {
        await _handleOAuthSuccess(userData);
        return;
      }

      if (userData != null) {
        // 檢查是否為新用戶，如果是則導向註冊頁面
        if (userData['is_new_user'] == true) {
          final tempToken = _extractOAuthTempToken(userData);
          if (tempToken == null) {
            debugPrint('❌ 缺少 Facebook OAuth 暫存 token，無法導向註冊流程');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('暫存登入資料缺失，請重新嘗試 Facebook 登入'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          final provider = (userData['provider'] ?? 'facebook').toString();
          await _saveFacebookDataForSignup(userData);
          final prefillData =
              _buildSignupPrefillData(userData, provider, tempToken);
          final uri = Uri(
            path: '/signup',
            queryParameters: {
              'token': tempToken,
              'provider': provider,
              'is_new_user': 'true',
            },
          );
          context.go(uri.toString(), extra: prefillData);
          return;
        } else {
          // 現有用戶，使用 AuthService 正確儲存登入資訊
          debugPrint('✅ Facebook 登入成功，儲存用戶資料...');

          // 安全地顯示 token 預覽（避免 RangeError）
          final token = userData['token'] ?? '';
          final tokenPreview =
              token.length > 20 ? token.substring(0, 20) : token;
          debugPrint('🔑 Token preview: $tokenPreview...');

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
    await _saveOAuthDataForSignup(userData, 'facebook');
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

      // Web 平台特殊處理：OAuth popup 流程
      if (kIsWeb && userData != null && userData['oauth_started'] == true) {
        // Web 平台使用 OAuth popup，等待 popup 結果
        debugPrint('🌐 Web 平台：Apple OAuth popup 已開啟，等待結果...');

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在開啟 Apple 登入視窗...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 處理 popup 視窗返回的 OAuth 結果
      debugPrint('🔍 檢查 Apple OAuth 結果: userData = $userData');
      debugPrint('🔍 userData 類型: ${userData.runtimeType}');
      debugPrint('🔍 userData 包含 data: ${userData?['data'] != null}');

      if (kIsWeb && userData != null && userData['data'] != null) {
        final rawOauthData = userData['data'];
        final oauthData = rawOauthData is Map
            ? Map<String, dynamic>.from(rawOauthData)
            : null;
        debugPrint('🔍 Apple OAuth 數據: $oauthData');

        if (oauthData != null) {
          await _handleOAuthSuccess(oauthData);
        }
        return;
      }

      // 處理直接返回的登入結果（非 popup 模式）
      if (userData != null && userData['success'] == true) {
        await _handleOAuthSuccess(userData);
        return;
      }

      if (userData != null) {
        // 檢查是否為新用戶，如果是則導向註冊頁面
        if (userData['is_new_user'] == true) {
          final tempToken = _extractOAuthTempToken(userData);
          if (tempToken == null) {
            debugPrint('❌ 缺少 Apple OAuth 暫存 token，無法導向註冊流程');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('暫存登入資料缺失，請重新嘗試 Apple 登入'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          final provider = (userData['provider'] ?? 'apple').toString();
          await _saveAppleDataForSignup(userData);
          final prefillData =
              _buildSignupPrefillData(userData, provider, tempToken);
          final uri = Uri(
            path: '/signup',
            queryParameters: {
              'token': tempToken,
              'provider': provider,
              'is_new_user': 'true',
            },
          );
          context.go(uri.toString(), extra: prefillData);
          return;
        } else {
          // 現有用戶，使用 AuthService 正確儲存登入資訊
          debugPrint('✅ Apple 登入成功，儲存用戶資料...');

          // 安全地顯示 token 預覽（避免 RangeError）
          final token = userData['token'] ?? '';
          final tokenPreview =
              token.length > 20 ? token.substring(0, 20) : token;
          debugPrint('🔑 Token preview: $tokenPreview...');

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
    await _saveOAuthDataForSignup(userData, 'apple');
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
                            FocusScope(
                              onFocusChange: (hasFocus) {
                                if (!hasFocus) {
                                  _loginEmailKey.currentState?.validate();
                                }
                              },
                              child: TextFormField(
                                key: _loginEmailKey,
                                controller: emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'name@example.com',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(value.trim())) {
                                    return 'Please enter a valid email format (e.g. name@example.com)';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submitForm(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: !showPassword,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                hintText:
                                    'At least 6 characters, letters and numbers only',
                                border: OutlineInputBorder(),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9]')),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                if (!RegExp(r'^[a-zA-Z0-9]+$')
                                    .hasMatch(value)) {
                                  return 'Password can only contain letters and numbers';
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
                                child: const Text(
                                  'Login',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(thickness: 1),
                            const SizedBox(height: 12),
                            // 跨平台第三方登入按鈕
                            Column(
                              children: [
                                _buildGoogleButton(),
                                const SizedBox(height: 8),
                                _buildFacebookButton(),
                                const SizedBox(height: 8),
                                if (_platformAuthService.isIOS ||
                                    _platformAuthService.isWeb) ...[
                                  _buildAppleButton(),
                                  const SizedBox(height: 8),
                                ],
                                _buildEmailButton(),
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

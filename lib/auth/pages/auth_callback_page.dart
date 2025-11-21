import 'dart:async';
import 'dart:convert';
// import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/services/api/oauth_api.dart';
import 'package:here4help/auth/services/signup_draft_service.dart';
import '../services/third_party_auth_service.dart';
import '../services/auth_service.dart';
// 如需判斷 kIsWeb

class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({Key? key}) : super(key: key);

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  bool _isProcessing = true;
  String _status = 'Processing...';
  String? _errorMessage;
  Map<String, dynamic>? _userData;
  bool? _isNewUser;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // 獲取 URL 參數
      final Uri uri =
          Uri.base; // Web 等同 window.location.href；行動裝置是 app 的 base URI
      final qp = uri.queryParameters;
      final error = qp['error'];
      final success = uri.queryParameters['success'] == 'true';
      final provider = uri.queryParameters['provider'] ?? '';

      debugPrint('🔐 OAuth 回調處理開始');
      debugPrint('   Provider: $provider');
      debugPrint('   Success: $success');
      debugPrint('   Error: $error');

      if (success) {
        // 處理登入成功
        await _handleLoginSuccess(uri);
      } else {
        // 處理登入失敗
        await _handleLoginError(error ?? '');
      }
    } catch (e) {
      debugPrint('❌ 回調處理錯誤: $e');
      setState(() {
        _isProcessing = false;
        _status = '處理失敗';
        _errorMessage = '回調處理時發生錯誤: $e';
      });
    }
  }

  Future<void> _handleLoginSuccess(Uri uri) async {
    try {
      setState(() {
        _status = '登入成功，正在處理...';
      });

      // 檢查是否為新用戶（需要註冊）
      final oauthToken = uri.queryParameters['token'];
      final provider = uri.queryParameters['provider'] ?? '';
      final isNewUser = uri.queryParameters['is_new_user'] == 'true';

      if (oauthToken != null && oauthToken.isNotEmpty && isNewUser) {
        // 新用戶：重定向到註冊頁面
        debugPrint('✅ 新用戶 OAuth 流程，重定向到註冊頁面');
        debugPrint('   Provider: $provider');
        debugPrint('   OAuth Token: ${oauthToken.substring(0, 8)}...');

        setState(() {
          _isProcessing = false;
          _status = '新用戶註冊';
          _isNewUser = true;
        });

        // 延遲後重定向到註冊頁面
        Future.delayed(const Duration(seconds: 1), () {
          unawaited(_redirectToSignupPage(oauthToken, provider));
        });
      } else {
        // 現有用戶：處理直接登入
        final token = uri.queryParameters['token'];
        final userDataStr = uri.queryParameters['user_data'];

        if (token == null || userDataStr == null) {
          throw Exception('缺少必要的登入資訊');
        }

        // 解析用戶資料
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;

        debugPrint('✅ 現有用戶登入成功');
        final tokenPreview = token.length > 20 ? token.substring(0, 20) : token;
        debugPrint('   Token: $tokenPreview...');
        debugPrint('   User ID: ${userData['id']}');
        debugPrint('   Name: ${userData['name']}');

        // 儲存登入資訊
        await _saveLoginInfo(token, userData);

        setState(() {
          _isProcessing = false;
          _status = '登入成功！';
          _userData = userData;
          _isNewUser = false;
        });

        // 延遲後重定向到主頁
        Future.delayed(const Duration(seconds: 2), () {
          _redirectToMainPage();
        });
      }
    } catch (e) {
      debugPrint('❌ 登入成功處理失敗: $e');
      setState(() {
        _isProcessing = false;
        _status = '登入處理失敗';
        _errorMessage = '處理登入資訊時發生錯誤: $e';
      });
    }
  }

  Future<void> _handleLoginError(String error) async {
    debugPrint('❌ 登入失敗: $error');
    setState(() {
      _isProcessing = false;
      _status = '登入失敗';
      _errorMessage = error;
    });

    // 延遲後重定向到登入頁面
    Future.delayed(const Duration(seconds: 3), () {
      _redirectToLoginPage();
    });
  }

  Future<void> _saveLoginInfo(
      String token, Map<String, dynamic> userData) async {
    try {
      debugPrint('💾 儲存登入資訊...');

      final refreshToken = userData['refresh_token']?.toString();
      final expiresIn = _parseTokenExpiry(userData['expires_in']);
      final refreshExpiresIn =
          _parseTokenExpiry(userData['refresh_expires_in']);

      // 使用 AuthService 儲存登入資訊
      await AuthService.saveTokenPair(
        accessToken: token,
        refreshToken: refreshToken,
        accessExpiresIn: expiresIn,
        refreshExpiresIn: refreshExpiresIn,
      );
      await AuthService.saveUserData(userData);

      debugPrint('✅ 登入資訊儲存成功');
    } catch (e) {
      debugPrint('❌ 儲存登入資訊失敗: $e');
      rethrow;
    }
  }

  void _redirectToMainPage() {
    debugPrint('🔄 重定向到主頁...');
    // 重定向到主頁或儀表板
    if (mounted) {
      context.pushReplacement('/home');
    }
  }

  void _redirectToLoginPage() {
    debugPrint('🔄 重定向到登入頁面...');
    // 重定向到登入頁面
    if (mounted) {
      context.pushReplacement('/login');
    }
  }

  Future<void> _redirectToSignupPage(String oauthToken, String provider) async {
    debugPrint('🔄 重定向到註冊頁面...');
    debugPrint('   OAuth Token: ${oauthToken.substring(0, 8)}...');
    debugPrint('   Provider: $provider');

    Map<String, dynamic>? prefillData;

    try {
      final tempData = await OAuthApi.fetchTempUser(oauthToken);
      if (tempData != null) {
        prefillData = _buildSignupPrefillData(tempData, provider, oauthToken);
        await _persistSignupDraft(prefillData);
        debugPrint('✅ 成功取得 OAuth 暫存資料，準備帶入註冊表單');
      } else {
        debugPrint('⚠️ 無法取得 OAuth 暫存資料，註冊表單將保持空白');
        await SignupDraftService.clear(includeOAuth: true);
      }
    } catch (e) {
      debugPrint('❌ 取得 OAuth 暫存資料失敗: $e');
      await SignupDraftService.clear(includeOAuth: true);
    }

    if (!mounted) return;

    final signupUrl = Uri(
      path: '/signup',
      queryParameters: {
        'token': oauthToken,
        'provider': provider,
        'is_new_user': 'true',
      },
    ).toString();

    debugPrint('🔗 重定向 URL: $signupUrl');
    context.pushReplacement(signupUrl, extra: prefillData);
  }

  int? _parseTokenExpiry(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _retryLogin() {
    debugPrint('🔄 重試登入...');
    // 重新導向到 Google 登入
    final thirdPartyAuth = ThirdPartyAuthService();
    thirdPartyAuth.signInWithProvider('google');
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

    String? stringValue(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
      return null;
    }

    void addString(String key, [String? alias]) {
      final value = stringValue(raw[key]);
      if (value != null) {
        sanitized[alias ?? key] = value;
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

    final rawData = raw['raw_data'];
    if (rawData is Map) {
      void addFromRaw(String key) {
        final value = stringValue(rawData[key]);
        if (value != null && !sanitized.containsKey(key)) {
          sanitized[key] = value;
        }
      }

      addFromRaw('name');
      addFromRaw('email');
      addFromRaw('birthday');
      addFromRaw('phone');

      final picture = rawData['picture'];
      if (picture is Map) {
        final data = picture['data'];
        if (data is Map) {
          final url = stringValue(data['url']);
          if (url != null) {
            sanitized['avatar_url'] = url;
          }
        }
      }
    }

    return sanitized;
  }

  Future<void> _persistSignupDraft(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await SignupDraftService.clearWithPrefs(prefs, includeOAuth: true);

    Future<void> setString(String key, String? value) async {
      if (value != null && value.isNotEmpty) {
        await prefs.setString(key, value);
      }
    }

    Future<void> setStringList(String key, List<String>? values) async {
      if (values != null && values.isNotEmpty) {
        await prefs.setStringList(key, values);
      }
    }

    final name = data['name'] as String?;
    final nickname = (data['nickname'] ?? name) as String?;
    final email = data['email'] as String?;
    final phone = data['phone'] as String?;
    final country = data['country'] as String?;
    final address = data['address'] as String?;
    final birthday = data['birthday'] as String?;
    final avatarUrl = data['avatar_url'] as String?;
    final gender = data['gender'] as String?;
    final primaryLanguage = data['primary_language'] as String?;
    final language = data['language'] as String?;
    final provider = data['provider'] as String?;
    final providerUserId = data['provider_user_id'];
    final oauthToken =
        data['oauth_token'] as String? ?? data['token'] as String?;
    final expiresAt = data['temp_expires_at'] as String?;

    await setString('signup_full_name', name);
    await setString('signup_nickname', nickname);
    await setString('signup_email', email);
    await setString('signup_phone', phone);
    await setString('signup_country', country);
    await setString('signup_address', address);
    await setString('signup_date_of_birth', birthday);
    await setString('signup_avatar_url', avatarUrl);

    if (gender != null && gender.isNotEmpty) {
      await prefs.setString('signup_gender', gender);
    }

    final preferredLanguage =
        primaryLanguage != null && primaryLanguage.isNotEmpty
            ? primaryLanguage
            : (language != null && language.isNotEmpty ? language : null);
    await setStringList('signup_languages',
        preferredLanguage != null ? [preferredLanguage] : null);

    if (provider != null && provider.isNotEmpty) {
      await prefs.setString('signup_provider', provider);
    }

    if (providerUserId != null) {
      await prefs.setString('signup_provider_user_id', '$providerUserId');
    }

    if (oauthToken != null && oauthToken.isNotEmpty) {
      await prefs.setString('signup_oauth_token', oauthToken);
    }

    if (expiresAt != null && expiresAt.isNotEmpty) {
      await prefs.setString('signup_oauth_token_expires_at', expiresAt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Processing'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  '請稍候，正在處理您的登入請求...',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // 成功狀態
                if (_userData != null) ...[
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.green,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_isNewUser == true) ...[
                    const Text(
                      '歡迎使用 Here4Help！',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '正在為您準備註冊頁面...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(
                      '歡迎回來，${_userData!['name']}！',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_isNewUser != true) ...[
                    ElevatedButton(
                      onPressed: _redirectToMainPage,
                      child: const Text('前往主頁'),
                    ),
                  ],
                ] else ...[
                  // 錯誤狀態
                  const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.red,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _retryLogin,
                        child: const Text('重試登入'),
                      ),
                      OutlinedButton(
                        onPressed: _redirectToLoginPage,
                        child: const Text('返回登入頁面'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

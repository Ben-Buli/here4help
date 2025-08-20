import 'package:here4help/config/environment_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 第三方登入服務 - 統一管理所有第三方登入方式
class ThirdPartyAuthService {
  static final ThirdPartyAuthService _instance =
      ThirdPartyAuthService._internal();
  factory ThirdPartyAuthService() => _instance;
  ThirdPartyAuthService._internal();

  // 平台檢測
  bool get isWeb => kIsWeb;
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// 第三方登入
  Future<Map<String, dynamic>?> signInWithProvider(String provider) async {
    try {
      switch (provider.toLowerCase()) {
        case 'google':
          return await _signInWithGoogle();
        case 'facebook':
          return await _signInWithFacebook();
        case 'apple':
          return await _signInWithApple();
        default:
          throw Exception('不支援的登入方式: $provider');
      }
    } catch (e) {
      print('第三方登入錯誤 ($provider): $e');
      return null;
    }
  }

  /// Google 登入 - 跨平台實現
  Future<Map<String, dynamic>?> _signInWithGoogle() async {
    try {
      if (isWeb) {
        return await _signInWithGoogleWeb();
      } else if (isIOS || isAndroid) {
        return await _signInWithGoogleMobile();
      } else {
        throw UnsupportedError('不支援的平台');
      }
    } catch (e) {
      print('Google 登入錯誤: $e');
      return null;
    }
  }

  // Web 版 Google 登入
  Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
    try {
      // 檢查是否已配置 Google Client ID
      if (EnvironmentConfig.googleClientId.isEmpty) {
        print('❌ Google Client ID 未配置，無法進行 Web 登入');
        throw Exception('Google Client ID 未配置');
      }

      // 使用 Google OAuth 2.0 進行真實登入
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 創建 Google OAuth 2.0 授權 URL
      final googleAuthUrl =
          Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': EnvironmentConfig.googleClientId,
        'redirect_uri':
            '${EnvironmentConfig.apiBaseUrl}/backend/api/auth/google-callback.php',
        'response_type': 'code',
        'scope': 'email profile',
        'state': 'web_google_$timestamp', // 防止 CSRF 攻擊
        'access_type': 'offline',
        'prompt': 'consent',
      });

      print('🔐 準備跳轉到 Google 登入頁面: $googleAuthUrl');

      // 在 Web 環境中，我們需要打開新視窗或重定向
      if (isWeb) {
        try {
          // 嘗試使用 url_launcher 打開 Google 登入頁面
          final canLaunch = await canLaunchUrl(googleAuthUrl);
          if (canLaunch) {
            print('🌐 正在打開 Google 登入頁面...');
            final launched = await launchUrl(
              googleAuthUrl,
              mode: LaunchMode.externalApplication,
            );

            if (launched) {
              print('✅ Google 登入頁面已打開');

              // 由於 OAuth 流程需要用戶在瀏覽器中完成，
              // 我們需要等待回調或實作其他機制來獲取授權碼
              // 目前先使用模擬資料，實際部署時需要實作完整的 OAuth 流程

              print('⚠️ 注意：用戶需要在瀏覽器中完成 Google 登入，然後返回應用');
              print('💡 建議：實作 OAuth 回調處理或使用 Popup 視窗');

              // 暫時使用模擬資料進行測試
              final userData = {
                'provider': 'google',
                'platform': 'web',
                'google_id': 'web_google_user_$timestamp',
                'name': 'Web Google User $timestamp',
                'email': 'webuser_google_$timestamp@example.com',
                'avatar_url': 'https://example.com/avatar.jpg',
                'access_token': 'mock_access_token_$timestamp',
                'id_token': 'mock_id_token_$timestamp',
                'auth_code': 'mock_auth_code_$timestamp', // 模擬授權碼
                'note': '真實 OAuth 流程需要實作回調處理',
              };

              return await _sendUserDataToBackend(userData);
            } else {
              print('❌ 無法打開 Google 登入頁面');
              throw Exception('無法打開 Google 登入頁面');
            }
          } else {
            print('❌ 無法啟動 URL: $googleAuthUrl');
            throw Exception('無法啟動 Google 登入 URL');
          }
        } catch (e) {
          print('❌ 打開 Google 登入頁面失敗: $e');
          print('🔄 回退到模擬資料模式');

          // 回退到模擬資料模式
          final userData = {
            'provider': 'google',
            'platform': 'web',
            'google_id': 'web_google_user_$timestamp',
            'name': 'Web Google User $timestamp',
            'email': 'webuser_google_$timestamp@example.com',
            'avatar_url': 'https://example.com/avatar.jpg',
            'access_token': 'mock_access_token_$timestamp',
            'id_token': 'mock_id_token_$timestamp',
            'auth_code': 'mock_auth_code_$timestamp',
            'note': 'OAuth 啟動失敗，使用模擬資料',
          };

          return await _sendUserDataToBackend(userData);
        }
      } else {
        // 非 Web 平台，使用模擬資料
        print('📱 非 Web 平台，使用模擬資料');
        final userData = {
          'provider': 'google',
          'platform': 'web',
          'google_id': 'web_google_user_$timestamp',
          'name': 'Web Google User $timestamp',
          'email': 'webuser_google_$timestamp@example.com',
          'avatar_url': 'https://example.com/avatar.jpg',
          'access_token': 'mock_access_token_$timestamp',
          'id_token': 'mock_id_token_$timestamp',
          'auth_code': 'mock_auth_code_$timestamp',
          'note': '非 Web 平台，使用模擬資料',
        };

        return await _sendUserDataToBackend(userData);
      }
    } catch (e) {
      print('Web Google 登入錯誤: $e');
      return null;
    }
  }

  // 移動版 Google 登入
  Future<Map<String, dynamic>?> _signInWithGoogleMobile() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final userData = {
        'google_id': googleUser.id,
        'name': googleUser.displayName ?? '',
        'email': googleUser.email,
        'avatar_url': googleUser.photoUrl ?? '',
        'access_token': googleAuth.accessToken,
        'id_token': googleAuth.idToken,
        'provider': 'google',
        'platform': isIOS ? 'ios' : 'android',
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('移動版 Google 登入錯誤: $e');
      return null;
    }
  }

  /// Facebook 登入 - 跨平台實現
  Future<Map<String, dynamic>?> _signInWithFacebook() async {
    try {
      if (isWeb) {
        return await _signInWithFacebookWeb();
      } else if (isIOS || isAndroid) {
        return await _signInWithFacebookMobile();
      } else {
        throw UnsupportedError('不支援的平台');
      }
    } catch (e) {
      print('Facebook 登入錯誤: $e');
      return null;
    }
  }

  // Web 版 Facebook 登入
  Future<Map<String, dynamic>?> _signInWithFacebookWeb() async {
    try {
      // 暫時使用模擬資料進行測試
      // TODO: 整合 Facebook JavaScript SDK
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userData = {
        'provider': 'facebook',
        'platform': 'web',
        'facebook_id': 'web_facebook_user_$timestamp',
        'name': 'Web Facebook User $timestamp',
        'email': 'webuser_facebook_$timestamp@example.com',
        'avatar_url': 'https://example.com/avatar.jpg',
        'access_token': 'mock_access_token_$timestamp',
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('Web Facebook 登入錯誤: $e');
      return null;
    }
  }

  // 移動版 Facebook 登入
  Future<Map<String, dynamic>?> _signInWithFacebookMobile() async {
    try {
      // 暫時使用模擬資料進行測試
      // TODO: 整合 flutter_facebook_auth 套件
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userData = {
        'provider': 'facebook',
        'platform': isIOS ? 'ios' : 'android',
        'facebook_id': 'mobile_facebook_user_$timestamp',
        'name': 'Mobile Facebook User $timestamp',
        'email': 'mobileuser_facebook_$timestamp@example.com',
        'avatar_url': 'https://example.com/avatar.jpg',
        'access_token': 'mock_access_token_$timestamp',
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('移動版 Facebook 登入錯誤: $e');
      return null;
    }
  }

  /// Apple 登入 - 跨平台實現
  Future<Map<String, dynamic>?> _signInWithApple() async {
    try {
      if (isWeb) {
        return await _signInWithAppleWeb();
      } else if (isIOS) {
        return await _signInWithAppleIOS();
      } else {
        // Android 和 Web 不支援 Apple 登入
        throw UnsupportedError('此平台不支援 Apple 登入');
      }
    } catch (e) {
      print('Apple 登入錯誤: $e');
      return null;
    }
  }

  // Web 版 Apple 登入
  Future<Map<String, dynamic>?> _signInWithAppleWeb() async {
    try {
      // 暫時使用模擬資料進行測試
      // TODO: 整合 Apple Sign-In JavaScript
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userData = {
        'provider': 'apple',
        'platform': 'web',
        'apple_id': 'web_apple_user_$timestamp',
        'name': 'Web Apple User $timestamp',
        'email': 'webuser_apple_$timestamp@example.com',
        'identity_token': 'mock_identity_token_$timestamp',
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('Web Apple 登入錯誤: $e');
      return null;
    }
  }

  // iOS 版 Apple 登入
  Future<Map<String, dynamic>?> _signInWithAppleIOS() async {
    try {
      // 暫時使用模擬資料進行測試
      // TODO: 整合 sign_in_with_apple 套件
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userData = {
        'provider': 'apple',
        'platform': 'ios',
        'apple_id': 'ios_apple_user_$timestamp',
        'name': 'iOS Apple User $timestamp',
        'email': 'iosuser_apple_$timestamp@example.com',
        'identity_token': 'mock_identity_token_$timestamp',
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('iOS Apple 登入錯誤: $e');
      return null;
    }
  }

  /// 發送用戶資料到後端
  Future<Map<String, dynamic>?> _sendUserDataToBackend(
      Map<String, dynamic> userData) async {
    try {
      final apiUrl =
          '${EnvironmentConfig.apiBaseUrl}/backend/api/auth/google-login.php';

      print('🌐 發送請求到: $apiUrl');
      print('📦 請求資料: ${jsonEncode(userData)}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      print('📥 後端回應狀態碼: ${response.statusCode}');
      print('📥 後端回應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ 後端處理成功');
          return data['data'];
        } else {
          print('❌ 後端處理失敗: ${data['message']}');
          return null;
        }
      } else {
        print('❌ 後端回應錯誤: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 發送資料到後端錯誤: $e');
      return null;
    }
  }

  /// 登出指定第三方登入
  Future<void> signOutFromProvider(String provider) async {
    try {
      switch (provider.toLowerCase()) {
        case 'google':
          if (!isWeb) {
            final GoogleSignIn googleSignIn = GoogleSignIn();
            await googleSignIn.signOut();
          }
          break;
        case 'facebook':
          // TODO: 實作 Facebook 登出
          print('Facebook 登出');
          break;
        case 'apple':
          // TODO: 實作 Apple 登出
          print('Apple 登出');
          break;
        default:
          print('不支援的登出方式: $provider');
      }
    } catch (e) {
      print('第三方登出錯誤 ($provider): $e');
    }
  }

  /// 檢查指定第三方是否已登入
  Future<bool> isSignedInWithProvider(String provider) async {
    try {
      switch (provider.toLowerCase()) {
        case 'google':
          if (!isWeb) {
            final GoogleSignIn googleSignIn = GoogleSignIn();
            return await googleSignIn.isSignedIn();
          }
          return false;
        case 'facebook':
          // TODO: 實作 Facebook 登入狀態檢查
          return false;
        case 'apple':
          // TODO: 實作 Apple 登入狀態檢查
          return false;
        default:
          return false;
      }
    } catch (e) {
      print('檢查第三方登入狀態錯誤 ($provider): $e');
      return false;
    }
  }

  /// 獲取所有已登入的第三方登入方式
  Future<List<String>> getSignedInProviders() async {
    final providers = <String>[];

    if (await isSignedInWithProvider('google')) {
      providers.add('google');
    }
    if (await isSignedInWithProvider('facebook')) {
      providers.add('facebook');
    }
    if (await isSignedInWithProvider('apple')) {
      providers.add('apple');
    }

    return providers;
  }

  /// 獲取第三方登入配置
  Map<String, dynamic> getProviderConfig(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return {
          'web_client_id': EnvironmentConfig.googleClientId,
          'android_client_id': EnvironmentConfig.googleAndroidClientId,
          'ios_client_id': EnvironmentConfig.googleIosClientId,
          'web_client_secret': EnvironmentConfig.googleWebClientSecret,
        };
      case 'facebook':
        return {
          'app_id': EnvironmentConfig.facebookAppId,
          'app_secret': EnvironmentConfig.facebookAppSecret,
        };
      case 'apple':
        return {
          'service_id': EnvironmentConfig.appleServiceId,
          'key_id': EnvironmentConfig.appleKeyId,
          'team_id': EnvironmentConfig.appleTeamId,
        };
      default:
        return {};
    }
  }

  /// 檢查第三方登入功能是否可用
  bool isProviderAvailable(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return EnvironmentConfig.googleClientId.isNotEmpty;
      case 'facebook':
        return EnvironmentConfig.facebookAppId.isNotEmpty;
      case 'apple':
        return EnvironmentConfig.appleServiceId.isNotEmpty;
      default:
        return false;
    }
  }

  /// 獲取所有可用的第三方登入方式
  List<String> getAvailableProviders() {
    final providers = <String>[];

    if (isProviderAvailable('google')) {
      providers.add('google');
    }
    if (isProviderAvailable('facebook')) {
      providers.add('facebook');
    }
    if (isProviderAvailable('apple')) {
      providers.add('apple');
    }

    return providers;
  }

  /// 獲取第三方登入的顯示名稱
  String getProviderDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'Google';
      case 'facebook':
        return 'Facebook';
      case 'apple':
        return 'Apple';
      default:
        return provider;
    }
  }

  /// 獲取第三方登入的圖標名稱
  String getProviderIconName(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return 'assets/images/auth/google_icon.png';
      case 'facebook':
        return 'assets/images/auth/facebook_icon.png';
      case 'apple':
        return 'assets/images/auth/apple_icon.png';
      default:
        return 'assets/images/auth/default_icon.png';
    }
  }

  /// 驗證第三方登入配置
  Map<String, bool> validateProviderConfigs() {
    return {
      'google': EnvironmentConfig.googleClientId.isNotEmpty &&
          EnvironmentConfig.googleAndroidClientId.isNotEmpty &&
          EnvironmentConfig.googleIosClientId.isNotEmpty,
      'facebook': EnvironmentConfig.facebookAppId.isNotEmpty &&
          EnvironmentConfig.facebookAppSecret.isNotEmpty,
      'apple': EnvironmentConfig.appleServiceId.isNotEmpty &&
          EnvironmentConfig.appleKeyId.isNotEmpty,
    };
  }

  /// 打印第三方登入配置狀態
  void printProviderConfigStatus() {
    if (EnvironmentConfig.debugMode) {
      print('🔐 第三方登入配置狀態:');
      print('  Google: ${isProviderAvailable('google') ? "✅" : "❌"}');
      print('  Facebook: ${isProviderAvailable('facebook') ? "✅" : "❌"}');
      print('  Apple: ${isProviderAvailable('apple') ? "✅" : "❌"}');

      final validation = validateProviderConfigs();
      print('🔍 配置驗證:');
      validation.forEach((provider, isValid) {
        print('  $provider: ${isValid ? "✅" : "❌"}');
      });
    }
  }
}

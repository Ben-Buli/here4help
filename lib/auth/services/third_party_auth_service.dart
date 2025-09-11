import 'package:here4help/config/environment_config.dart';
import 'package:here4help/config/app_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  // Web 版 Google 登入 - 使用 google_sign_in（統一三端）
  Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
    try {
      if (EnvironmentConfig.googleClientId.isEmpty) {
        debugPrint('❌ Google Client ID 未配置，無法進行 Web 登入');
        throw Exception('Google Client ID 未配置');
      }

      // google_sign_in 7.1.1 推薦先 initialize + authenticate 流程
      final GoogleSignIn signIn = GoogleSignIn.instance;
      await signIn.initialize(clientId: EnvironmentConfig.googleClientId);

      // 嘗試輕量驗證（非阻斷）
      await signIn.attemptLightweightAuthentication();

      // 用戶互動觸發登入
      await signIn.authenticate();

      // 透過事件取得使用者
      final signInEvent = await signIn.authenticationEvents.firstWhere(
        (e) => e is GoogleSignInAuthenticationEventSignIn,
      ) as GoogleSignInAuthenticationEventSignIn;
      final user = signInEvent.user;

      // 7.1.1 仍可透過 authentication 取得 access/id token（平台差異化處理由套件處理）
      final auth = user.authentication;

      // 嘗試取得 server auth code（可選）
      String? serverAuthCode;
      try {
        final serverAuth =
            await user.authorizationClient.authorizeServer(const []);
        serverAuthCode = serverAuth?.serverAuthCode;
      } catch (_) {}

      final userData = {
        'provider': 'google',
        'platform': 'web',
        'google_id': user.id,
        'name': user.displayName ?? '',
        'email': user.email,
        'avatar_url': user.photoUrl ?? '',
        'id_token': auth.idToken,
        if (serverAuthCode != null) 'server_auth_code': serverAuthCode,
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      debugPrint('Web Google 登入錯誤: $e');
      return null;
    }
  }

  // 移動版 Google 登入
  Future<Map<String, dynamic>?> _signInWithGoogleMobile() async {
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;
      // 可選：若有 server client id，可在此傳入
      await signIn.initialize();

      // 使用 authenticate 流程
      await signIn.authenticate();

      final signInEvent = await signIn.authenticationEvents.firstWhere(
        (e) => e is GoogleSignInAuthenticationEventSignIn,
      ) as GoogleSignInAuthenticationEventSignIn;
      final user = signInEvent.user;

      final auth = user.authentication;

      // 可選：取得 server auth code
      String? serverAuthCode;
      try {
        final serverAuth =
            await user.authorizationClient.authorizeServer(const []);
        serverAuthCode = serverAuth?.serverAuthCode;
      } catch (_) {}

      final userData = {
        'google_id': user.id,
        'name': user.displayName ?? '',
        'email': user.email,
        'avatar_url': user.photoUrl ?? '',
        'id_token': auth.idToken,
        if (serverAuthCode != null) 'server_auth_code': serverAuthCode,
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

  // Web 版 Facebook 登入 - 使用新的 OAuth 流程
  Future<Map<String, dynamic>?> _signInWithFacebookWeb() async {
    try {
      // 檢查是否已配置 Facebook App ID
      if (EnvironmentConfig.facebookAppId.isEmpty) {
        debugPrint('❌ Facebook App ID 未配置，無法進行 Web 登入');
        throw Exception('Facebook App ID 未配置');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 創建 Facebook OAuth 2.0 授權 URL
      final facebookAuthUrl =
          Uri.https('www.facebook.com', '/v18.0/dialog/oauth', {
        'client_id': EnvironmentConfig.facebookAppId,
        // 使用環境配置中的統一 redirect_uri
        'redirect_uri': EnvironmentConfig.facebookRedirectUri,
        'response_type': 'code',
        'scope': 'email,public_profile',
        'state': 'web_facebook_$timestamp',
      });

      debugPrint('🔐 準備跳轉到 Facebook 登入頁面: $facebookAuthUrl');

      if (isWeb) {
        try {
          final canLaunch = await canLaunchUrl(facebookAuthUrl);
          if (canLaunch) {
            debugPrint('🌐 正在重定向到 Facebook 登入頁面...');
            final launched = await launchUrl(
              facebookAuthUrl,
              mode: LaunchMode.externalApplication,
            );

            if (launched) {
              debugPrint('✅ Facebook OAuth 流程已啟動');
              return {
                'success': true,
                'provider': 'facebook',
                'platform': 'web',
                'oauth_started': true,
                'message': 'Facebook OAuth flow started successfully',
                'timestamp': timestamp,
              };
            } else {
              throw Exception('無法啟動 Facebook OAuth 流程');
            }
          } else {
            throw Exception('無法啟動 Facebook 登入 URL');
          }
        } catch (e) {
          debugPrint('❌ Facebook OAuth 流程啟動失敗: $e');
          throw Exception('Facebook OAuth 流程啟動失敗: $e');
        }
      } else {
        throw UnsupportedError('Web OAuth 流程僅支援 Web 平台');
      }
    } catch (e) {
      debugPrint('Web Facebook 登入錯誤: $e');
      return null;
    }
  }

  // 移動版 Facebook 登入
  Future<Map<String, dynamic>?> _signInWithFacebookMobile() async {
    try {
      // 整合 flutter_facebook_auth 套件
      final FacebookAuth facebookAuth = FacebookAuth.instance;

      // 執行 Facebook 登入
      final LoginResult result = await facebookAuth.login();

      if (result.status == LoginStatus.success) {
        // 獲取用戶資料
        final userData = await facebookAuth.getUserData();

        final facebookData = {
          'provider': 'facebook',
          'platform': isIOS ? 'ios' : 'android',
          'facebook_id': userData['id'],
          'name': userData['name'] ?? '',
          'email': userData['email'] ?? '',
          'avatar_url': userData['picture']?['data']?['url'] ?? '',
          'access_token': result.accessToken?.token ?? '',
        };

        return await _sendUserDataToBackend(facebookData);
      } else {
        print('Facebook 登入失敗: ${result.status}');
        return null;
      }
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

  // Web 版 Apple 登入 - 使用新的 OAuth 流程
  Future<Map<String, dynamic>?> _signInWithAppleWeb() async {
    try {
      // 檢查是否已配置 Apple Service ID
      if (EnvironmentConfig.appleServiceId.isEmpty) {
        debugPrint('❌ Apple Service ID 未配置，無法進行 Web 登入');
        throw Exception('Apple Service ID 未配置');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 創建 Apple Sign In 授權 URL
      final appleAuthUrl = Uri.https('appleid.apple.com', '/auth/authorize', {
        'client_id': EnvironmentConfig.appleServiceId,
        // 使用環境配置中的統一 redirect_uri
        'redirect_uri': EnvironmentConfig.appleRedirectUri,
        'response_type': 'code',
        'scope': 'name email',
        'response_mode': 'form_post',
        'state': 'web_apple_$timestamp',
      });

      debugPrint('🔐 準備跳轉到 Apple 登入頁面: $appleAuthUrl');

      if (isWeb) {
        try {
          final canLaunch = await canLaunchUrl(appleAuthUrl);
          if (canLaunch) {
            debugPrint('🌐 正在重定向到 Apple 登入頁面...');
            final launched = await launchUrl(
              appleAuthUrl,
              mode: LaunchMode.externalApplication,
            );

            if (launched) {
              debugPrint('✅ Apple OAuth 流程已啟動');
              return {
                'success': true,
                'provider': 'apple',
                'platform': 'web',
                'oauth_started': true,
                'message': 'Apple OAuth flow started successfully',
                'timestamp': timestamp,
              };
            } else {
              throw Exception('無法啟動 Apple OAuth 流程');
            }
          } else {
            throw Exception('無法啟動 Apple 登入 URL');
          }
        } catch (e) {
          debugPrint('❌ Apple OAuth 流程啟動失敗: $e');
          throw Exception('Apple OAuth 流程啟動失敗: $e');
        }
      } else {
        throw UnsupportedError('Web OAuth 流程僅支援 Web 平台');
      }
    } catch (e) {
      debugPrint('Web Apple 登入錯誤: $e');
      return null;
    }
  }

  // iOS 版 Apple 登入
  Future<Map<String, dynamic>?> _signInWithAppleIOS() async {
    try {
      // 整合 sign_in_with_apple 套件
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 組合用戶姓名
      String fullName = '';
      if (credential.givenName != null || credential.familyName != null) {
        fullName =
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim();
      }

      final appleData = {
        'provider': 'apple',
        'platform': 'ios',
        'apple_id': credential.userIdentifier,
        'name': fullName.isNotEmpty ? fullName : 'Apple User',
        'email': credential.email ?? '',
        'identity_token': credential.identityToken,
        'authorization_code': credential.authorizationCode,
      };

      return await _sendUserDataToBackend(appleData);
    } catch (e) {
      print('iOS Apple 登入錯誤: $e');
      return null;
    }
  }

  /// 發送用戶資料到後端 - 使用新的 OAuth 流程
  Future<Map<String, dynamic>?> _sendUserDataToBackend(
      Map<String, dynamic> userData) async {
    try {
      // 統一使用後端 login 端點（web/ios/android 共用）
      final provider = (userData['provider'] ?? 'google').toString();
      final apiUrl = AppConfig.api('/auth/$provider-login.php');

      debugPrint('🌐 發送請求到: $apiUrl');
      debugPrint('📦 請求資料: ${userData.keys.toList()}'); // 不記錄敏感資料

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      debugPrint('📥 後端回應狀態碼: ${response.statusCode}');

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
          // 7.1.1 使用單例
          final signIn = GoogleSignIn.instance;
          await signIn.initialize();
          await signIn.disconnect();
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
          final signIn = GoogleSignIn.instance;
          // 7.1.1 使用事件或嘗試輕量驗證判斷當前使用者
          await signIn.initialize();
          await signIn.attemptLightweightAuthentication();
          try {
            final event = await signIn.authenticationEvents.first.timeout(
              const Duration(milliseconds: 100),
            );
            return event is GoogleSignInAuthenticationEventSignIn;
          } catch (_) {
            return false;
          }
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

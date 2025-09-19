import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/environment_config.dart';

// 條件導入 - 只在 Web 平台導入 dart:html
import 'dart:html' as html show window if (dart.library.html) 'dart:html';

/// 第三方登入服務 - 統一管理所有第三方登入方式
class ThirdPartyAuthService {
  static final ThirdPartyAuthService _instance =
      ThirdPartyAuthService._internal();
  factory ThirdPartyAuthService() => _instance;
  ThirdPartyAuthService._internal();

  // Facebook 登入實例
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  /// 檢查是否為 iOS 平台
  bool get isIOS => !kIsWeb && Platform.isIOS;

  /// 檢查是否為 Web 平台
  bool get isWeb => kIsWeb;

  /// 安全地檢查是否可以使用 Web API
  bool get canUseWebAPI {
    try {
      return kIsWeb;
    } catch (e) {
      return false;
    }
  }

  /// 初始化服務
  Future<void> initialize() async {
    debugPrint('🔧 初始化第三方登入服務...');

    // 檢查環境配置
    try {
      debugPrint('🔍 第三方登入服務初始化完成');
    } catch (e) {
      debugPrint('⚠️ 環境配置初始化失敗: $e');
    }
  }

  /// Google 登入
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      debugPrint('🔍 開始 Google 登入...');

      if (kIsWeb) {
        // Web 平台使用 OAuth popup 流程
        return await _signInWithGoogleWeb();
      } else {
        // 移動平台使用原生流程
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      debugPrint('❌ Google 登入失敗: $e');
      return null;
    }
  }

  /// Google 登入 - Web 平台
  Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
    try {
      debugPrint('🌐 使用 Google Web 登入流程...');

      // 創建 Google 登入 URL
      final googleClientId = EnvironmentConfig.googleClientId;
      final redirectUri = EnvironmentConfig.googleRedirectUri;

      // 檢查必要的環境變數
      if (googleClientId.isEmpty) {
        debugPrint('❌ Google Client ID 未配置');
        return null;
      }
      if (redirectUri.isEmpty) {
        debugPrint('❌ Google Redirect URI 未配置');
        return null;
      }

      final googleAuthUrl = 'https://accounts.google.com/o/oauth2/v2/auth?'
          'client_id=$googleClientId&'
          'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
          'response_type=code&'
          'scope=email%20profile&'
          'access_type=offline';

      debugPrint('🔍 Google 登入 URL: $googleAuthUrl');

      // 使用 popup 進行登入
      if (canUseWebAPI) {
        // 使用 dart:html 打開 popup
        html.window.open(googleAuthUrl, 'google_auth_popup',
            'width=500,height=600,scrollbars=yes,resizable=yes');

        debugPrint('✅ Google 登入 popup 已打開');

        // 監聽 popup 關閉事件
        final completer = Completer<Map<String, dynamic>?>();

        late dynamic messageHandler;
        messageHandler = (event) {
          if (canUseWebAPI) {
            debugPrint('🔍 收到 Google 登入消息: ${event.data}');

            html.window.removeEventListener('message', messageHandler);

            try {
              final data = jsonDecode(event.data);
              completer.complete(data);
            } catch (e) {
              debugPrint('❌ 解析 Google 登入數據失敗: $e');
              completer.complete(null);
            }
          }
        };

        if (canUseWebAPI) {
          html.window.addEventListener('message', messageHandler);
        }

        // 等待 popup 結果
        return await completer.future;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Google Web 登入失敗: $e');
      return null;
    }
  }

  /// Google 登入 - 移動平台
  Future<Map<String, dynamic>?> _signInWithGoogleMobile() async {
    try {
      debugPrint('📱 使用 Google 移動登入流程...');

      // 移動平台暫時返回 null，等待後續實現
      debugPrint('⚠️ Google 移動登入功能暫未實現');
      return null;
    } catch (e) {
      debugPrint('❌ Google 移動登入失敗: $e');
      return null;
    }
  }

  /// Facebook 登入
  Future<Map<String, dynamic>?> signInWithFacebook() async {
    try {
      debugPrint('🔍 開始 Facebook 登入...');

      final LoginResult result = await _facebookAuth.login();

      if (result.status == LoginStatus.success) {
        debugPrint('✅ Facebook 登入成功');

        // 獲取用戶信息
        final userData = await _facebookAuth.getUserData();

        return {
          'provider': 'facebook',
          'provider_id': userData['id'],
          'email': userData['email'],
          'name': userData['name'],
          'avatar_url': userData['picture']?['data']?['url'],
          'access_token': result.accessToken?.tokenString ?? '',
        };
      }

      debugPrint('❌ Facebook 登入失敗: ${result.status}');
      return null;
    } catch (e) {
      debugPrint('❌ Facebook 登入失敗: $e');
      return null;
    }
  }

  /// Apple 登入
  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      debugPrint('🔍 開始 Apple 登入...');

      if (kIsWeb) {
        // Web 平台使用 OAuth popup 流程
        return await _signInWithAppleWeb();
      } else {
        // 移動平台使用原生流程
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        debugPrint('✅ Apple 登入成功: ${credential.userIdentifier}');

        return {
          'provider': 'apple',
          'provider_id': credential.userIdentifier,
          'email': credential.email,
          'name': '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
              .trim(),
          'access_token': credential.identityToken,
          'authorization_code': credential.authorizationCode,
        };
      }
    } catch (e) {
      debugPrint('❌ Apple 登入失敗: $e');
      return null;
    }
  }

  /// Apple 登入 - Web 平台
  Future<Map<String, dynamic>?> _signInWithAppleWeb() async {
    try {
      debugPrint('🌐 使用 Apple Web 登入流程...');

      // 創建 Apple 登入 URL
      final appleClientId = EnvironmentConfig.appleServiceId;
      final redirectUri = EnvironmentConfig.appleRedirectUri;

      // 檢查必要的環境變數
      if (appleClientId.isEmpty) {
        debugPrint('❌ Apple Service ID 未配置');
        return null;
      }
      if (redirectUri.isEmpty) {
        debugPrint('❌ Apple Redirect URI 未配置');
        return null;
      }

      final appleAuthUrl = 'https://appleid.apple.com/auth/authorize?'
          'client_id=$appleClientId&'
          'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
          'response_type=code&'
          'scope=name%20email&'
          'response_mode=form_post';

      debugPrint('🔍 Apple 登入 URL: $appleAuthUrl');

      // 使用 popup 進行登入
      if (canUseWebAPI) {
        // 使用 dart:html 打開 popup
        html.window.open(appleAuthUrl, 'apple_auth_popup',
            'width=500,height=600,scrollbars=yes,resizable=yes');

        debugPrint('✅ Apple 登入 popup 已打開');

        // 監聽 popup 關閉事件
        final completer = Completer<Map<String, dynamic>?>();

        late dynamic messageHandler;
        messageHandler = (event) {
          if (canUseWebAPI) {
            debugPrint('🔍 收到 Apple 登入消息: ${event.data}');

            html.window.removeEventListener('message', messageHandler);

            try {
              final data = jsonDecode(event.data);
              completer.complete(data);
            } catch (e) {
              debugPrint('❌ 解析 Apple 登入數據失敗: $e');
              completer.complete(null);
            }
          }
        };

        if (canUseWebAPI) {
          html.window.addEventListener('message', messageHandler);
        }

        // 等待 popup 結果
        return await completer.future;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Apple Web 登入失敗: $e');
      return null;
    }
  }

  /// 登出所有服務
  Future<void> signOut() async {
    try {
      debugPrint('🔍 開始登出所有服務...');

      // Facebook 登出
      await _facebookAuth.logOut();

      debugPrint('✅ 所有服務登出完成');
    } catch (e) {
      debugPrint('❌ 登出失敗: $e');
    }
  }

  /// 檢查登入狀態
  Future<bool> isSignedIn() async {
    try {
      // 暫時返回 false
      return false;
    } catch (e) {
      debugPrint('❌ 檢查登入狀態失敗: $e');
      return false;
    }
  }

  /// 獲取當前用戶信息
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // 暫時返回 null
      return null;
    } catch (e) {
      debugPrint('❌ 獲取用戶信息失敗: $e');
      return null;
    }
  }

  /// 統一登入方法 - 根據提供者選擇對應的登入方式
  Future<Map<String, dynamic>?> signInWithProvider(String provider) async {
    switch (provider.toLowerCase()) {
      case 'google':
        return await signInWithGoogle();
      case 'facebook':
        return await signInWithFacebook();
      case 'apple':
        return await signInWithApple();
      default:
        debugPrint('❌ 不支援的登入提供者: $provider');
        return null;
    }
  }
}

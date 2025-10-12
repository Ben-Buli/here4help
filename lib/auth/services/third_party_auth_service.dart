import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/config/environment_config_legacy.dart' as legacy;

// 條件導入 - 使用更安全的方式
import 'third_party_auth_web.dart'
    if (dart.library.io) 'third_party_auth_mobile.dart' as platform;

/// 第三方登入服務 - 統一管理所有第三方登入方式
class ThirdPartyAuthService {
  static final ThirdPartyAuthService _instance =
      ThirdPartyAuthService._internal();
  factory ThirdPartyAuthService() => _instance;
  ThirdPartyAuthService._internal();

  static Future<void>? _googleInitFuture;
  static const List<String> _googleScopes = <String>['email', 'profile'];

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
      rethrow;
    }
  }

  /// Google 登入 - Web 平台
  Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
    try {
      debugPrint('🌐 使用 Google Web 登入流程...');

      // 創建 Google 登入 URL
      final googleClientId = legacy.EnvironmentConfig.googleClientId;
      final redirectUri = legacy.EnvironmentConfig.googleRedirectUri;

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
        // 使用平台特定的實現打開 popup
        platform.PlatformAuth.openAuthPopup(googleAuthUrl, 'google_auth_popup');

        debugPrint('✅ Google 登入 popup 已打開');

        // 監聽 popup 關閉事件
        final completer = Completer<Map<String, dynamic>?>();

        late dynamic messageHandler;
        messageHandler = (String data) {
          if (canUseWebAPI) {
            debugPrint('🔍 收到 Google 登入消息: $data');

            platform.PlatformAuth.removeMessageListener();

            try {
              final dataMap = jsonDecode(data);
              completer.complete(dataMap);
            } catch (e) {
              debugPrint('❌ 解析 Google 登入數據失敗: $e');
              completer.complete(null);
            }
          }
        };

        if (canUseWebAPI) {
          platform.PlatformAuth.addMessageListener(messageHandler);
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

      final iosClientId = legacy.EnvironmentConfig.googleIosClientId;
      final androidClientId = legacy.EnvironmentConfig.googleAndroidClientId;
      final serverClientId = legacy.EnvironmentConfig.googleClientId;
      final GoogleSignIn googleSignIn = await _prepareGoogleSignIn(
        iosClientId: iosClientId,
        androidClientId: androidClientId,
        serverClientId: serverClientId,
      );

      if (!googleSignIn.supportsAuthenticate()) {
        debugPrint('⚠️ 當前平台不支援 Google authenticate() 流程');
        return null;
      }

      final GoogleSignInAccount account =
          await googleSignIn.authenticate(scopeHint: _googleScopes);

      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google 登入缺少 idToken');
      }

      GoogleSignInClientAuthorization? clientAuthorization;
      try {
        clientAuthorization =
            await account.authorizationClient.authorizationForScopes(
          _googleScopes,
        );
      } catch (e) {
        debugPrint('⚠️ 取得 Google accessToken 失敗: $e');
      }

      final payload = <String, dynamic>{
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'unknown',
        'id_token': idToken,
        if (clientAuthorization != null)
          'access_token': clientAuthorization.accessToken,
        if (account.email.isNotEmpty) 'email': account.email,
        if (account.displayName != null && account.displayName!.isNotEmpty)
          'name': account.displayName,
        if (account.photoUrl != null && account.photoUrl!.isNotEmpty)
          'avatar_url': account.photoUrl,
      };

      final backendResponse = await _sendGoogleLoginRequest(payload);
      if (backendResponse == null) {
        debugPrint('❌ 後端 Google 登入回應為空');
        return null;
      }

      backendResponse['provider'] ??= 'google';
      return backendResponse;
    } catch (e) {
      if (e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('⚠️ 使用者取消 Google 登入');
        return null;
      }
      debugPrint('❌ Google 移動登入失敗: $e');
      rethrow;
    }
  }

  /// 呼叫後端 Google 登入 API，交換 token 並取得使用者資料
  Future<Map<String, dynamic>?> _sendGoogleLoginRequest(
      Map<String, dynamic> payload) async {
    final url = AppConfig.googleLoginUrl;
    debugPrint('🌐 呼叫後端 Google 登入 API: $url');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final body = response.body;
      debugPrint('📥 Google 登入回應狀態碼: ${response.statusCode}');
      final preview = body.length > 200 ? '${body.substring(0, 200)}...' : body;
      debugPrint('📥 Google 登入回應內容: $preview');

      final decoded = jsonDecode(body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        debugPrint('⚠️ 後端回傳資料格式不正確: $data');
        return null;
      }

      final message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Google login failed';
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ 呼叫後端 Google 登入 API 失敗: $e');
      rethrow;
    }
  }

  Future<GoogleSignIn> _prepareGoogleSignIn({
    required String iosClientId,
    required String androidClientId,
    required String serverClientId,
  }) async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    _googleInitFuture ??= googleSignIn.initialize(
      clientId: _resolvePlatformClientId(
        iosClientId: iosClientId,
        androidClientId: androidClientId,
      ),
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
    );

    try {
      await _googleInitFuture;
    } catch (e) {
      _googleInitFuture = null;
      rethrow;
    }
    return googleSignIn;
  }

  String? _resolvePlatformClientId({
    required String iosClientId,
    required String androidClientId,
  }) {
    if (kIsWeb) {
      return null;
    }
    if (Platform.isIOS && iosClientId.isNotEmpty) {
      return iosClientId;
    }
    if (Platform.isAndroid && androidClientId.isNotEmpty) {
      return androidClientId;
    }
    return null;
  }

  /// Facebook 登入
  Future<Map<String, dynamic>?> signInWithFacebook() async {
    try {
      debugPrint('🔍 開始 Facebook 登入...');

      final LoginResult result = await _facebookAuth.login();

      switch (result.status) {
        case LoginStatus.success:
          debugPrint('✅ Facebook 登入成功');
          final userData = await _facebookAuth.getUserData();
          final payload = <String, dynamic>{
            'facebook_id': userData['id'],
            if (userData['email'] != null) 'email': userData['email'],
            if (userData['name'] != null) 'name': userData['name'],
            if (userData['picture']?['data']?['url'] != null)
              'avatar_url': userData['picture']['data']['url'],
            if (result.accessToken?.tokenString != null)
              'access_token': result.accessToken!.tokenString,
          };

          final backendResponse = await _sendFacebookLoginRequest(payload);
          if (backendResponse == null) {
            debugPrint('❌ 後端 Facebook 登入回應為空');
            return null;
          }

          backendResponse['provider'] ??= 'facebook';
          return backendResponse;
        case LoginStatus.cancelled:
          debugPrint('⚠️ 使用者取消 Facebook 登入');
          return null;
        case LoginStatus.failed:
          debugPrint('❌ Facebook 登入失敗: ${result.message}');
          throw Exception(result.message ?? 'Facebook login failed');
        case LoginStatus.operationInProgress:
          debugPrint('⚠️ Facebook 登入尚在進行中');
          return null;
      }
    } catch (e) {
      debugPrint('❌ Facebook 登入失敗: $e');
      rethrow;
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

        final fullName =
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim();

        final payload = <String, dynamic>{
          'apple_id': credential.userIdentifier,
          if (credential.email != null && credential.email!.isNotEmpty)
            'email': credential.email,
          if (fullName.isNotEmpty) 'name': fullName,
          if (credential.identityToken != null)
            'identity_token': credential.identityToken,
          if (credential.authorizationCode != null)
            'authorization_code': credential.authorizationCode,
        };

        final backendResponse = await _sendAppleLoginRequest(payload);
        if (backendResponse == null) {
          debugPrint('❌ 後端 Apple 登入回應為空');
          return null;
        }

        backendResponse['provider'] ??= 'apple';
        return backendResponse;
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('⚠️ 使用者取消 Apple 登入');
        return null;
      }
      debugPrint('❌ Apple 登入授權錯誤: $e');
      rethrow;
    } catch (e) {
      debugPrint('❌ Apple 登入失敗: $e');
      rethrow;
    }
  }

  /// Apple 登入 - Web 平台
  Future<Map<String, dynamic>?> _signInWithAppleWeb() async {
    try {
      debugPrint('🌐 使用 Apple Web 登入流程...');

      // 創建 Apple 登入 URL
      final appleClientId = legacy.EnvironmentConfig.appleServiceId;
      final redirectUri = legacy.EnvironmentConfig.appleRedirectUri;

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
        // 使用平台特定的實現打開 popup
        platform.PlatformAuth.openAuthPopup(appleAuthUrl, 'apple_auth_popup');

        debugPrint('✅ Apple 登入 popup 已打開');

        // 監聽 popup 關閉事件
        final completer = Completer<Map<String, dynamic>?>();

        late dynamic messageHandler;
        messageHandler = (String data) {
          if (canUseWebAPI) {
            debugPrint('🔍 收到 Apple 登入消息: $data');

            platform.PlatformAuth.removeMessageListener();

            try {
              final dataMap = jsonDecode(data);
              completer.complete(dataMap);
            } catch (e) {
              debugPrint('❌ 解析 Apple 登入數據失敗: $e');
              completer.complete(null);
            }
          }
        };

        if (canUseWebAPI) {
          platform.PlatformAuth.addMessageListener(messageHandler);
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

  Future<Map<String, dynamic>?> _sendAppleLoginRequest(
      Map<String, dynamic> payload) async {
    final url = AppConfig.appleLoginUrl;
    debugPrint('🌐 呼叫後端 Apple 登入 API: $url');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final body = response.body;
      debugPrint('📥 Apple 登入回應狀態碼: ${response.statusCode}');
      final preview = body.length > 200 ? '${body.substring(0, 200)}...' : body;
      debugPrint('📥 Apple 登入回應內容: $preview');

      final decoded = jsonDecode(body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) {
          if (data['user'] is Map && data['token'] != null) {
            final combined = Map<String, dynamic>.from(data['user'] as Map);
            combined['token'] = data['token'];
            combined['provider'] = combined['provider'] ?? 'apple';
            return combined;
          }

          final result = Map<String, dynamic>.from(data);
          result['provider'] = (result['provider'] ?? 'apple').toString();
          return result;
        }
        debugPrint('⚠️ 後端 Apple 回傳資料格式不正確: $data');
        return null;
      }

      final message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Apple login failed';
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ 呼叫後端 Apple 登入 API 失敗: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _sendFacebookLoginRequest(
      Map<String, dynamic> payload) async {
    final url = AppConfig.facebookLoginUrl;
    debugPrint('🌐 呼叫後端 Facebook 登入 API: $url');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final body = response.body;
      debugPrint('📥 Facebook 登入回應狀態碼: ${response.statusCode}');
      final preview = body.length > 200 ? '${body.substring(0, 200)}...' : body;
      debugPrint('📥 Facebook 登入回應內容: $preview');

      final decoded = jsonDecode(body);
      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map) {
          if (data['user'] is Map && data['token'] != null) {
            // 向後相容舊版回傳格式
            final combined = Map<String, dynamic>.from(data['user'] as Map);
            combined['token'] = data['token'];
            combined['provider'] = combined['provider'] ?? 'facebook';
            return combined;
          }

          final result = Map<String, dynamic>.from(data);
          result['provider'] = (result['provider'] ?? 'facebook').toString();
          return result;
        }
        debugPrint('⚠️ 後端 Facebook 回傳資料格式不正確: $data');
        return null;
      }

      final message = decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Facebook login failed';
      throw Exception(message);
    } catch (e) {
      debugPrint('❌ 呼叫後端 Facebook 登入 API 失敗: $e');
      rethrow;
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

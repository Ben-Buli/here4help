import 'package:here4help/config/environment_config_legacy.dart';
import 'package:here4help/config/app_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

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

  // Web 版 Google 登入 - 使用 OAuth 回調流程（google_sign_in 7.1.1 Web 平台限制）
  Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
    try {
      if (EnvironmentConfig.googleClientId.isEmpty) {
        debugPrint('❌ Google Client ID 未配置，無法進行 Web 登入');
        throw Exception('Google Client ID 未配置');
      }

      // 使用 OAuth 回調流程，返回明確的狀態
      debugPrint('⚠️ google_sign_in 7.1.1 在 Web 平台有限制，使用 OAuth 回調流程');
      return await _signInWithGoogleWebFallback();
    } catch (e) {
      debugPrint('Web Google 登入錯誤: $e');
      return {
        'success': false,
        'provider': 'google',
        'platform': 'web',
        'error': e.toString(),
        'message': 'Google Web 登入失敗'
      };
    }
  }

  // 備用的 Web 版 Google 登入 - 使用 OAuth 回調流程
  Future<Map<String, dynamic>?> _signInWithGoogleWebFallback() async {
    try {
      // Web 平台使用 OAuth 回調流程，跳轉到 Google 授權頁面
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final state = 'web_google_$timestamp';

      // 建立 Google OAuth 授權 URL（使用帶 popup 參數的 redirect_uri）
      final popupRedirectUri =
          EnvironmentConfig.googleRedirectUri + '?popup=true';
      final googleAuthUrl =
          Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': EnvironmentConfig.googleClientId,
        'redirect_uri': popupRedirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'access_type': 'offline',
        'prompt': 'consent',
      });

      debugPrint('🔐 準備跳轉到 Google 登入頁面: $googleAuthUrl');

      // Web 平台使用 popup 視窗進行 OAuth
      if (isWeb) {
        debugPrint('🌐 正在開啟 Google OAuth popup 視窗...');

        // 使用 JavaScript 開啟 popup 視窗並等待結果
        final popupResult = await _openOAuthPopup(googleAuthUrl.toString());

        if (popupResult['success'] == true) {
          debugPrint('✅ Google OAuth popup 視窗已開啟');

          // 檢查是否有 OAuth 數據
          if (popupResult['data'] != null) {
            // 有 OAuth 數據，直接返回
            debugPrint('🔍 返回 OAuth 數據: ${popupResult['data']}');
            return popupResult;
          } else {
            // 沒有 OAuth 數據，返回 oauth_started 狀態
            return {
              'success': true,
              'provider': 'google',
              'platform': 'web',
              'oauth_started': true,
              'message': 'Google OAuth popup opened successfully',
              'timestamp': timestamp,
              'state': state,
            };
          }
        } else {
          throw Exception('無法開啟 Google OAuth popup 視窗');
        }
      } else {
        // 非 Web 平台使用 url_launcher
        if (await canLaunchUrl(googleAuthUrl)) {
          debugPrint('🌐 正在重定向到 Google 登入頁面...');
          await launchUrl(googleAuthUrl, mode: LaunchMode.externalApplication);

          debugPrint('✅ 已跳轉到 Google 授權頁面，等待用戶授權...');
          return {
            'success': true,
            'provider': 'google',
            'platform': 'mobile',
            'oauth_started': true,
            'message': 'Google OAuth flow started successfully',
            'timestamp': timestamp,
            'state': state,
          };
        } else {
          throw Exception('無法開啟 Google 登入頁面');
        }
      }
    } catch (e) {
      debugPrint('Web Google 登入備用流程錯誤: $e');
      return {
        'success': false,
        'provider': 'google',
        'platform': 'web',
        'error': e.toString(),
        'message': 'Google OAuth flow failed'
      };
    }
  }

  // Web 平台 OAuth popup 視窗處理
  Future<Map<String, dynamic>> _openOAuthPopup(String url) async {
    try {
      // 使用 JavaScript 開啟 popup 視窗
      final popup = html.window.open(url, 'oauth_popup',
          'width=500,height=600,scrollbars=yes,resizable=yes,status=yes,location=yes,toolbar=no,menubar=no');

      // 檢查 popup 是否成功開啟（跨域環境下避免 COOP 錯誤）
      try {
        // 嘗試訪問 popup 的屬性來檢查是否成功開啟
        // 注意：在跨域情況下，window.closed 可能被 COOP 阻止
        final isOpened = !popup.closed!;
        if (!isOpened) {
          return {
            'success': false,
            'error': 'Popup blocked by browser',
            'message': '瀏覽器阻擋了 popup 視窗'
          };
        }
      } catch (e) {
        // COOP 錯誤時，假設 popup 已成功開啟
        debugPrint('⚠️ 跨域 COOP 錯誤，假設 popup 已開啟: $e');
        // 不返回錯誤，繼續執行
      }

      // 監聽 popup 視窗關閉事件
      final completer = Completer<Map<String, dynamic>>();

      // 跨域環境下完全移除定時器檢查，避免 COOP 錯誤
      // 只依賴 postMessage 來獲取結果
      debugPrint('🔍 跨域環境：跳過 popup 狀態檢查，只依賴 postMessage');

      // 監聽來自 popup 的消息（一次性處理）
      late html.EventListener messageHandler;
      messageHandler = (html.Event event) {
        if (event is html.MessageEvent) {
          debugPrint('🔍 收到 postMessage: ${event.data}');

          // 立即移除事件監聽器，避免重複處理
          html.window.removeEventListener('message', messageHandler);

          if (event.data is Map) {
            // 安全地轉換 LinkedMap 為 Map<String, dynamic>
            final data = Map<String, dynamic>.from(event.data as Map);
            debugPrint('🔍 解析 postMessage 資料: $data');

            if (data['type'] == 'oauth_result') {
              // 安全地轉換 data['data'] 為 Map<String, dynamic>
              final rawOauthData = data['data'];
              if (rawOauthData is Map) {
                final oauthData = Map<String, dynamic>.from(rawOauthData);
                debugPrint('🔍 OAuth 結果: $oauthData');

                // 跨域環境下不嘗試關閉 popup，避免 COOP 錯誤
                debugPrint('🔍 跨域環境：跳過 popup 關閉嘗試，避免 COOP 錯誤');

                // 檢查 Completer 是否已經完成，避免重複完成
                if (!completer.isCompleted) {
                  completer.complete({
                    'success': oauthData['success'] == true,
                    'data': oauthData,
                    'message': oauthData['success'] == true
                        ? 'OAuth completed successfully'
                        : 'OAuth failed'
                  });
                  debugPrint('✅ Completer 已完成');
                } else {
                  debugPrint('⚠️ Completer 已經完成，跳過重複完成');
                }
              }
            }
          }
        }
      };

      // 添加事件監聽器
      html.window.addEventListener('message', messageHandler);

      // 等待 popup 關閉或完成
      return await completer.future.timeout(const Duration(minutes: 5),
          onTimeout: () {
        // 超時時也要移除事件監聽器
        html.window.removeEventListener('message', messageHandler);
        return {
          'success': false,
          'error': 'OAuth timeout',
          'message': 'OAuth 流程超時，可能是 COOP 策略阻止了 popup 檢查'
        };
      });
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to open OAuth popup'
      };
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
        'success': true,
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('移動版 Google 登入錯誤: $e');
      return {
        'success': false,
        'provider': 'google',
        'platform': isIOS ? 'ios' : 'android',
        'error': e.toString(),
        'message': 'Google Mobile 登入失敗'
      };
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

      // Web 平台使用 popup 視窗進行 OAuth
      if (isWeb) {
        debugPrint('🌐 正在開啟 Facebook OAuth popup 視窗...');

        // 使用 JavaScript 開啟 popup 視窗
        final popupResult = await _openOAuthPopup(facebookAuthUrl.toString());

        if (popupResult['success'] == true) {
          debugPrint('✅ Facebook OAuth popup 視窗已開啟');
          return {
            'success': true,
            'provider': 'facebook',
            'platform': 'web',
            'oauth_started': true,
            'message': 'Facebook OAuth popup opened successfully',
            'timestamp': timestamp,
          };
        } else {
          throw Exception('無法開啟 Facebook OAuth popup 視窗');
        }
      } else {
        throw UnsupportedError('Facebook Web 登入僅支援 Web 平台');
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
          'access_token': result.accessToken?.tokenString ?? '',
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
      debugPrint('📦 請求資料欄位: ${userData.keys.toList()}'); // 不記錄敏感資料

      // 檢查敏感資料但不記錄
      final sensitiveKeys = [
        'id_token',
        'access_token',
        'server_auth_code',
        'password'
      ];
      final hasSensitiveData =
          userData.keys.any((key) => sensitiveKeys.contains(key));
      if (hasSensitiveData) {
        debugPrint('⚠️ 請求包含敏感資料，已隱藏');
      }

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
          // Web 平台 Facebook 登出
          if (isWeb) {
            debugPrint('🌐 Facebook Web 登出 - 清除本地狀態');
            // Web 平台清除 localStorage 或 cookie
            // 實際實現需要與前端 JavaScript 配合
          } else {
            debugPrint('📱 Facebook Mobile 登出 - 使用 SDK');
            // 移動平台使用 Facebook SDK 登出
            // await FacebookLogin().logOut();
          }
          break;
        case 'apple':
          // Web 平台 Apple 登出
          if (isWeb) {
            debugPrint('🌐 Apple Web 登出 - 清除本地狀態');
            // Web 平台清除本地狀態
          } else {
            debugPrint('📱 Apple Mobile 登出 - 使用 SDK');
            // 移動平台使用 Apple Sign-In SDK 登出
            // await SignInWithApple.getAppleIDCredential().then((_) => null);
          }
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
          if (isWeb) {
            // Web 平台：檢查 localStorage 或後端 token
            debugPrint('🌐 Google Web 登入狀態檢查 - 檢查本地狀態');
            // 實際實現需要檢查 localStorage 或後端 token
            // 這裡簡化為 false，實際應該檢查有效的 JWT token
            return false;
          } else {
            // 移動平台：使用 SDK 檢查
            final signIn = GoogleSignIn.instance;
            await signIn.initialize();
            await signIn.attemptLightweightAuthentication();
            try {
              final event = await signIn.authenticationEvents.first.timeout(
                const Duration(milliseconds: 500), // 增加 timeout 時間
              );
              return event is GoogleSignInAuthenticationEventSignIn;
            } catch (_) {
              return false;
            }
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

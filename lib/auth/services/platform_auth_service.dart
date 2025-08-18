import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:here4help/config/app_config.dart';

class PlatformAuthService {
  static final PlatformAuthService _instance = PlatformAuthService._internal();
  factory PlatformAuthService() => _instance;
  PlatformAuthService._internal();

  // 平台檢測
  bool get isWeb => kIsWeb;
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  // Google 登入 - 跨平台實現
  Future<Map<String, dynamic>?> signInWithGoogle() async {
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
      // 暫時使用模擬資料進行測試
      // TODO: 整合 Google OAuth 2.0 JavaScript SDK
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userData = {
        'provider': 'google',
        'platform': 'web',
        'google_id': 'web_google_user_$timestamp', // 模擬 Google ID
        'name': 'Web Google User $timestamp', // 模擬用戶名
        'email': 'webuser_google_$timestamp@example.com', // 模擬郵箱
        'avatar_url': 'https://example.com/avatar.jpg', // 模擬頭像
        'access_token': 'mock_access_token_$timestamp', // 模擬 access token
        'id_token': 'mock_id_token_$timestamp', // 模擬 ID token
      };

      return await _sendUserDataToBackend(userData);
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

  // Facebook 登入 - 跨平台實現
  Future<Map<String, dynamic>?> signInWithFacebook() async {
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
        'facebook_id': 'web_facebook_user_$timestamp', // 模擬 Facebook ID
        'name': 'Web Facebook User $timestamp', // 模擬用戶名
        'email': 'webuser_facebook_$timestamp@example.com', // 模擬郵箱
        'avatar_url': 'https://example.com/avatar.jpg', // 模擬頭像
        'access_token': 'mock_access_token_$timestamp', // 模擬 access token
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
        'facebook_id': 'mobile_facebook_user_$timestamp', // 模擬 Facebook ID
        'name': 'Mobile Facebook User $timestamp', // 模擬用戶名
        'email': 'mobileuser_facebook_$timestamp@example.com', // 模擬郵箱
        'avatar_url': 'https://example.com/avatar.jpg', // 模擬頭像
        'access_token': 'mock_access_token_$timestamp', // 模擬 access token
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('移動版 Facebook 登入錯誤: $e');
      return null;
    }
  }

  // Apple 登入 - 跨平台實現
  Future<Map<String, dynamic>?> signInWithApple() async {
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
        'apple_id': 'web_apple_user_$timestamp', // 模擬 Apple ID
        'name': 'Web Apple User $timestamp', // 模擬用戶名
        'email': 'webuser_apple_$timestamp@example.com', // 模擬郵箱
        'identity_token': 'mock_identity_token_$timestamp', // 模擬 identity token
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
        'apple_id': 'ios_apple_user_$timestamp', // 模擬 Apple ID
        'name': 'iOS Apple User $timestamp', // 模擬用戶名
        'email': 'iosuser_apple_$timestamp@example.com', // 模擬郵箱
        'identity_token': 'mock_identity_token_$timestamp', // 模擬 identity token
      };

      return await _sendUserDataToBackend(userData);
    } catch (e) {
      print('iOS Apple 登入錯誤: $e');
      return null;
    }
  }

  // 發送用戶資料到後端
  Future<Map<String, dynamic>?> _sendUserDataToBackend(
      Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.googleLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('後端回應: $data');
        return data;
      } else {
        print('後端回應錯誤: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('發送資料到後端錯誤: $e');
      return null;
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      if (isWeb) {
        // Web 版登出邏輯
        print('Web 版登出');
      } else if (isIOS || isAndroid) {
        // 移動版登出邏輯
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      }
    } catch (e) {
      print('登出錯誤: $e');
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/utils/debug_helper.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:here4help/services/http_client_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _accessExpiryKey = 'auth_token_expiry';
  static const String _refreshExpiryKey = 'auth_refresh_expiry';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<bool>? _refreshingFuture;

  // 測試網路連線
  // static Future<bool> testConnection() async {
  //   try {
  //     print('🔍 測試網路連線...');
  //     final response = await http
  //         .post(
  //           Uri.parse('${AppConfig.apiBaseUrl}/backend/api/auth/login.php'),
  //           headers: {
  //             'Content-Type': 'application/json',
  //           },
  //           body: jsonEncode(
  //               {'email': 'test@example.com', 'password': 'test123'}),
  //         )
  //         .timeout(const Duration(seconds: 10));

  //     print('📡 連線測試狀態碼: ${response.statusCode}');
  //     // 任何回應都表示連線正常，包括認證失敗
  //     return response.statusCode >= 200 && response.statusCode < 600;
  //   } catch (e) {
  //     print('❌ 連線測試失敗: $e');
  //     return false;
  //   }
  // }

  // 登入
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      print('🔐 嘗試登入: $email');
      print('🌐 API URL: ${AppConfig.loginUrl}');

      final requestBody = {
        'email': email,
        'password': password,
      };
      print('📤 請求內容: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
        Uri.parse(AppConfig.loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📥 回應狀態碼: ${response.statusCode}');
      print('📥 回應標頭: ${response.headers}');
      print('📥 回應內容: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        print('✅ 登入成功');

        // 診斷用戶圖片信息
        final responseData = Map<String, dynamic>.from(data['data'] as Map);
        if (responseData['user'] != null) {
          DebugHelper.printUserImageInfo(responseData['user']);
        }

        final tokenPayload = _extractTokenPayload(responseData);
        await saveTokenPair(
          accessToken: tokenPayload.accessToken,
          refreshToken: tokenPayload.refreshToken,
          accessExpiresIn: tokenPayload.expiresIn,
          refreshExpiresIn: tokenPayload.refreshExpiresIn,
        );
        await _saveUserData(responseData['user']);
        return responseData;
      } else {
        print('❌ 登入失敗: ${data['message']}');
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('💥 登入錯誤: $e');
      throw Exception('Login failed: $e');
    }
  }

  // 註冊
  static Future<Map<String, dynamic>> register(
      String name, String email, String password,
      {String? phone}) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.registerUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          if (phone != null) 'phone': phone,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success']) {
        final responseData = Map<String, dynamic>.from(data['data'] as Map);
        final tokenPayload = _extractTokenPayload(responseData);
        await saveTokenPair(
          accessToken: tokenPayload.accessToken,
          refreshToken: tokenPayload.refreshToken,
          accessExpiresIn: tokenPayload.expiresIn,
          refreshExpiresIn: tokenPayload.refreshExpiresIn,
        );
        await _saveUserData(responseData['user']);
        return responseData;
      } else {
        throw Exception(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // 獲取用戶資料
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No token available');
      }

      debugPrint('🔍 調用 getProfile API...');
      debugPrint('🔍 API URL: ${AppConfig.profileUrl}');

      // 使用 HttpClientService 統一請求，非 production 會自動附上 query token 備援
      final data = await HttpClientService.getJson(
        AppConfig.profileUrl,
        useQueryParamToken: true,
      );

      if (data['success'] == true && data['data'] != null) {
        debugPrint('✅ getProfile 成功: ${data['data']['id']}');
        return Map<String, dynamic>.from(data['data']);
      } else {
        debugPrint('❌ getProfile 失敗: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      debugPrint('❌ getProfile 錯誤: $e');
      throw Exception('Failed to get profile: $e');
    }
  }

  // 取得使用者輕量狀態（permission/status）
  static Future<Map<String, dynamic>> getUserStatus() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No token available');
      }

      debugPrint('🔍 調用 userStatus API...');
      debugPrint('🔍 API URL: ${AppConfig.userStatusUrl}');

      final data = await HttpClientService.getJson(
        AppConfig.userStatusUrl,
        useQueryParamToken: true,
      );

      if (data['success'] == true && data['data'] != null) {
        return Map<String, dynamic>.from(data['data']);
      }

      throw Exception(data['message'] ?? 'Failed to get user status');
    } catch (e) {
      debugPrint('❌ getUserStatus 錯誤: $e');
      rethrow;
    }
  }

  // 登出
  static Future<void> logout() async {
    // 先斷開 Socket 連線
    try {
      final SocketService socketService = SocketService();
      socketService.disconnect();
      debugPrint('✅ Socket disconnected during logout');
    } catch (e) {
      debugPrint('⚠️ Failed to disconnect socket during logout: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_accessExpiryKey);
    await prefs.remove(_refreshExpiryKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    // 清除 Socket 相關的 SharedPreferences
    await prefs.remove('user_id');
  }

  // 檢查是否已登入
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // 獲取 token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    debugPrint(
        '🔍 getToken: ${token != null ? 'Token found' : 'No token found'}');
    if (token != null) {
      debugPrint('🔍 Token length: ${token.length}');
      debugPrint(
          '🔍 Token preview: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    }
    return token;
  }

  // 獲取用戶資料
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  // 儲存 token
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    debugPrint(
        '✅ Token saved: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
  }

  // 儲存用戶資料
  static Future<void> _saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // 公開方法：儲存 token
  static Future<void> saveToken(String token) async {
    await _saveToken(token);
  }

  // 公開方法：儲存用戶資料
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    await _saveUserData(user);
  }

  static Future<void> saveTokenPair({
    required String accessToken,
    String? refreshToken,
    int? accessExpiresIn,
    int? refreshExpiresIn,
  }) async {
    await _saveToken(accessToken);
    final prefs = await SharedPreferences.getInstance();

    if (accessExpiresIn != null && accessExpiresIn > 0) {
      final expiry =
          DateTime.now().millisecondsSinceEpoch + accessExpiresIn * 1000;
      await prefs.setInt(_accessExpiryKey, expiry);
    } else {
      await prefs.remove(_accessExpiryKey);
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      if (refreshExpiresIn != null && refreshExpiresIn > 0) {
        final expiry =
            DateTime.now().millisecondsSinceEpoch + refreshExpiresIn * 1000;
        await prefs.setInt(_refreshExpiryKey, expiry);
      }
    } else {
      await _secureStorage.delete(key: _refreshTokenKey);
      await prefs.remove(_refreshExpiryKey);
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('⚠️ Failed to read refresh token: $e');
      return null;
    }
  }

  static Future<bool> tryRefreshToken() async {
    final existingFuture = _refreshingFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshingFuture = completer.future;

    () async {
      var success = false;
      try {
        success = await _refreshAccessToken(refreshToken);
      } catch (e) {
        debugPrint('⚠️ Refresh token request failed: $e');
      } finally {
        completer.complete(success);
        _refreshingFuture = null;
      }
    }();

    return _refreshingFuture!;
  }

  static Future<bool> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.refreshTokenUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['success'] == true) {
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        final tokenPayload = _extractTokenPayload(data);
        await saveTokenPair(
          accessToken: tokenPayload.accessToken,
          refreshToken: tokenPayload.refreshToken,
          accessExpiresIn: tokenPayload.expiresIn,
          refreshExpiresIn: tokenPayload.refreshExpiresIn,
        );
        return true;
      }

      debugPrint('⚠️ Refresh token failed: ${decoded['message']}');
      return false;
    } catch (e) {
      debugPrint('⚠️ Refresh token exception: $e');
      return false;
    }
  }

  static _TokenPayload _extractTokenPayload(Map<String, dynamic> data) {
    final accessToken =
        (data['access_token'] ?? data['token'] ?? '')?.toString() ?? '';
    final refreshToken = data['refresh_token']?.toString();
    final expiresIn = _tryParseInt(data['expires_in']);
    final refreshExpiresIn = _tryParseInt(data['refresh_expires_in']);
    return _TokenPayload(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      refreshExpiresIn: refreshExpiresIn,
    );
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class _TokenPayload {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final int? refreshExpiresIn;

  const _TokenPayload({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.refreshExpiresIn,
  });
}

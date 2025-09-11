import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/utils/debug_helper.dart';
import 'package:here4help/chat/services/socket_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

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
        if (data['data']['user'] != null) {
          DebugHelper.printUserImageInfo(data['data']['user']);
        }

        // 儲存 token 和用戶資料
        await _saveToken(data['data']['token']);
        await _saveUserData(data['data']['user']);
        return data['data'];
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
        // 儲存 token 和用戶資料
        await _saveToken(data['data']['token']);
        await _saveUserData(data['data']['user']);
        return data['data'];
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
      if (token.length > 10) {
        debugPrint('🔍 Token: ${token.substring(0, 10)}...');
      } else {
        debugPrint('🔍 Token: $token');
      }
      debugPrint('🔍 API URL: ${AppConfig.profileUrl}');

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      debugPrint('🔍 Headers: $headers');

      final response = await http.get(
        Uri.parse(AppConfig.profileUrl),
        headers: headers,
      );

      debugPrint('🔍 API 回應狀態碼: ${response.statusCode}');

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        debugPrint('❌ JSON 解析錯誤: $e');
        throw Exception('Invalid JSON response');
      }

      if (response.statusCode == 200 && data['success']) {
        if (data.containsKey('data') && data['data'] != null) {
          debugPrint('✅ getProfile 成功: ${data['data']['id']}');
          return data['data'];
        } else {
          debugPrint('❌ getProfile 失敗: 回傳資料缺少 data 欄位');
          throw Exception('Response missing data field');
        }
      } else {
        debugPrint('❌ getProfile 失敗: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      debugPrint('❌ getProfile 錯誤: $e');
      throw Exception('Failed to get profile: $e');
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
}

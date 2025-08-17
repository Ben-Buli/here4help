import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:here4help/auth/services/auth_service.dart';

/// 全域 HTTP Client 服務
/// 統一管理所有 HTTP 請求，自動添加 Authorization 頭
/// 兼容 MAMP FastCGI 環境（使用查詢參數傳遞 token）
class HttpClientService {
  static final HttpClientService _instance = HttpClientService._internal();
  factory HttpClientService() => _instance;
  HttpClientService._internal();

  // 基礎 headers
  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// 獲取帶有 Authorization 的 headers
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ [HTTP] Token 為空，無法添加 Authorization 頭');
      return Map<String, String>.from(_baseHeaders);
    }

    final headers = Map<String, String>.from(_baseHeaders);
    headers['Authorization'] = 'Bearer $token';

    // 安全的 debug 輸出（不顯示完整 token）
    if (kDebugMode) {
      debugPrint('🔍 [HTTP] Headers: ${headers.keys.toList()}');
      debugPrint('🔍 [HTTP] Authorization: Bearer ***len=${token.length}***');
    }

    return headers;
  }

  /// 為 MAMP 環境添加 token 到查詢參數
  static String addTokenToUrl(String url, String token) {
    if (url.contains('?')) {
      return '$url&token=$token';
    } else {
      return '$url?token=$token';
    }
  }

  /// GET 請求
  static Future<http.Response> get(
    String url, {
    Map<String, String>? additionalHeaders,
    bool useQueryParamToken = true, // MAMP 兼容性選項
  }) async {
    try {
      final token = await AuthService.getToken();
      String finalUrl = url;

      // 如果啟用查詢參數 token（MAMP 兼容性）
      if (useQueryParamToken && token != null && token.isNotEmpty) {
        finalUrl = addTokenToUrl(url, token);
        debugPrint('🔍 [HTTP] MAMP 兼容模式：使用查詢參數傳遞 token');
      }

      final headers = await getAuthHeaders();
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] GET: $finalUrl');
        debugPrint('🔍 [HTTP] Headers: ${headers.keys.toList()}');
      }

      final response = await http.get(
        Uri.parse(finalUrl),
        headers: headers,
      );

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] Response: ${response.statusCode}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ [HTTP] GET 請求失敗: $e');
      rethrow;
    }
  }

  /// POST 請求
  static Future<http.Response> post(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項
  }) async {
    try {
      final token = await AuthService.getToken();
      String finalUrl = url;

      // 如果啟用查詢參數 token（MAMP 兼容性）
      if (useQueryParamToken && token != null && token.isNotEmpty) {
        finalUrl = addTokenToUrl(url, token);
        debugPrint('🔍 [HTTP] MAMP 兼容模式：使用查詢參數傳遞 token');
      }

      final headers = await getAuthHeaders();
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] POST: $finalUrl');
        debugPrint('🔍 [HTTP] Headers: ${headers.keys.toList()}');
        if (body != null) {
          debugPrint(
              '🔍 [HTTP] Body: ${body.toString().substring(0, body.toString().length > 100 ? 100 : body.toString().length)}...');
        }
      }

      final response = await http.post(
        Uri.parse(finalUrl),
        headers: headers,
        body: body is String ? body : jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] Response: ${response.statusCode}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ [HTTP] POST 請求失敗: $e');
      rethrow;
    }
  }

  /// PUT 請求
  static Future<http.Response> put(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項
  }) async {
    try {
      final token = await AuthService.getToken();
      String finalUrl = url;

      // 如果啟用查詢參數 token（MAMP 兼容性）
      if (useQueryParamToken && token != null && token.isNotEmpty) {
        finalUrl = addTokenToUrl(url, token);
        debugPrint('🔍 [HTTP] MAMP 兼容模式：使用查詢參數傳遞 token');
      }

      final headers = await getAuthHeaders();
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] PUT: $finalUrl');
        debugPrint('🔍 [HTTP] Headers: ${headers.keys.toList()}');
      }

      final response = await http.put(
        Uri.parse(finalUrl),
        headers: headers,
        body: body is String ? body : jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] Response: ${response.statusCode}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ [HTTP] PUT 請求失敗: $e');
      rethrow;
    }
  }

  /// DELETE 請求
  static Future<http.Response> delete(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項
  }) async {
    try {
      final token = await AuthService.getToken();
      String finalUrl = url;

      // 如果啟用查詢參數 token（MAMP 兼容性）
      if (useQueryParamToken && token != null && token.isNotEmpty) {
        finalUrl = addTokenToUrl(url, token);
        debugPrint('🔍 [HTTP] MAMP 兼容模式：使用查詢參數傳遞 token');
      }

      final headers = await getAuthHeaders();
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] DELETE: $finalUrl');
        debugPrint('🔍 [HTTP] Headers: ${headers.keys.toList()}');
      }

      final response = await http.delete(
        Uri.parse(finalUrl),
        headers: headers,
        body: body is String ? body : jsonEncode(body),
      );

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] Response: ${response.statusCode}');
      }

      return response;
    } catch (e) {
      debugPrint('❌ [HTTP] DELETE 請求失敗: $e');
      rethrow;
    }
  }

  /// 檢查響應狀態
  static bool isSuccessResponse(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// 解析 JSON 響應
  static Map<String, dynamic> parseJsonResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('❌ [HTTP] JSON 解析失敗: $e');
      debugPrint('❌ [HTTP] Response body: ${response.body}');
      rethrow;
    }
  }
}

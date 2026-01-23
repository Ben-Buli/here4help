import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/config/environment_config_legacy.dart';
import 'package:here4help/services/auth_error_handler.dart';

/// Token 過期異常
class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException(this.message);

  @override
  String toString() => 'TokenExpiredException: $message';
}

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
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
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

  static Object? _encodeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  static Never _throwByStatus(int status, {String? message}) {
    switch (status) {
      case 401:
        throw Exception(message ?? 'Unauthorized');
      case 403:
        throw Exception(message ?? 'Forbidden');
      case 404:
        throw Exception(message ?? 'Not Found');
      default:
        throw Exception(message ?? 'HTTP $status');
    }
  }

  static Future<http.Response> _send(
    String method,
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
    bool retryOnAuthFailure = true,
  }) async {
    try {
      final token = await AuthService.getToken();
      String finalUrl = url;

      // Prod 預設關閉 query token
      final effectiveQueryToken =
          EnvironmentConfig.isProduction ? false : useQueryParamToken;

      if (effectiveQueryToken && token != null && token.isNotEmpty) {
        finalUrl = addTokenToUrl(url, token);
        debugPrint('🔍 [HTTP] MAMP 兼容模式：使用查詢參數傳遞 token');
      }

      final headers = await getAuthHeaders();
      if (additionalHeaders != null) headers.addAll(additionalHeaders);

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] $method: $finalUrl');
        debugPrint('🔍 [HTTP] Headers: ${headers.keys.toList()}');
        if (body != null) {
          final s = body.toString();
          final preview = s.substring(0, s.length > 200 ? 200 : s.length);
          debugPrint('🔍 [HTTP] Body: $preview${s.length > 200 ? '...' : ''}');
        }
      }

      final uri = Uri.parse(finalUrl);
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: _encodeBody(body))
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: _encodeBody(body))
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: _encodeBody(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: _encodeBody(body))
              .timeout(timeout);
          break;
        default:
          throw ArgumentError('Unsupported method $method');
      }

      if (kDebugMode) {
        debugPrint('🔍 [HTTP] Response: ${response.statusCode}');
      }

      // 自動處理 401 錯誤（Token 過期）
      if (response.statusCode == 401) {
        if (retryOnAuthFailure) {
          final refreshed = await AuthService.tryRefreshToken();
          if (refreshed) {
            return _send(
              method,
              url,
              additionalHeaders: additionalHeaders,
              body: body,
              useQueryParamToken: useQueryParamToken,
              timeout: timeout,
              retryOnAuthFailure: false,
            );
          }
        }
        debugPrint('🚨 [HTTP] 檢測到 401 錯誤，觸發 Token 過期處理');

        // 解析錯誤訊息
        String? errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? 'Token expired';
        } catch (_) {
          errorMessage = 'Authentication failed';
        }

        // 觸發 Token 過期處理（異步執行，不阻塞當前請求）
        Future.microtask(() async {
          try {
            await AuthErrorHandler.handleTokenExpiry(
              reason: 'HTTP 401: $errorMessage (URL: $finalUrl)',
            );
          } catch (e) {
            debugPrint('⚠️ [HTTP] Token 過期處理失敗: $e');
          }
        });

        // 拋出異常，讓調用方知道請求失敗
        throw TokenExpiredException(errorMessage ?? 'Authentication failed');
      }

      return response;
    } catch (e) {
      debugPrint('❌ [HTTP] $method 請求失敗: $e');
      rethrow;
    }
  }

  /// GET 請求
  static Future<http.Response> get(
    String url, {
    Map<String, String>? additionalHeaders,
    bool useQueryParamToken = true, // MAMP 兼容性選項（在 prod 會自動關閉）
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _send(
      'GET',
      url,
      additionalHeaders: additionalHeaders,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  /// POST 請求
  static Future<http.Response> post(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項（在 prod 會自動關閉）
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _send(
      'POST',
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  /// PUT 請求
  static Future<http.Response> put(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項（在 prod 會自動關閉）
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _send(
      'PUT',
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  /// PATCH 請求
  static Future<http.Response> patch(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項（在 prod 會自動關閉）
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _send(
      'PATCH',
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  /// DELETE 請求
  static Future<http.Response> delete(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true, // MAMP 兼容性選項（在 prod 會自動關閉）
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _send(
      'DELETE',
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
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

  static Map<String, dynamic> _ensureSuccessOrThrow(http.Response response) {
    if (isSuccessResponse(response)) {
      return parseJsonResponse(response);
    }
    // 嘗試解析 message
    String? message;
    try {
      final m = jsonDecode(response.body);
      if (m is Map && m['message'] != null) {
        message = m['message'].toString();
      }
    } catch (_) {}
    _throwByStatus(response.statusCode, message: message);
  }

  static Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, String>? additionalHeaders,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await get(
      url,
      additionalHeaders: additionalHeaders,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
    return _ensureSuccessOrThrow(res);
  }

  static Future<Map<String, dynamic>> postJson(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await post(
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
    return _ensureSuccessOrThrow(res);
  }

  static Future<Map<String, dynamic>> putJson(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await put(
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
    return _ensureSuccessOrThrow(res);
  }

  static Future<Map<String, dynamic>> patchJson(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await patch(
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
    return _ensureSuccessOrThrow(res);
  }

  static Future<Map<String, dynamic>> deleteJson(
    String url, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final res = await delete(
      url,
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
    return _ensureSuccessOrThrow(res);
  }
}

/// 便捷 API 包裝：以 AppConfig.api('/path') 組裝 URL
class ApiClient {
  static Future<http.Response> get(
    String path, {
    Map<String, String>? additionalHeaders,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.get(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<http.Response> post(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.post(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<http.Response> put(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.put(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<http.Response> patch(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.patch(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<http.Response> delete(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.delete(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? additionalHeaders,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.getJson(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.postJson(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.putJson(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.patchJson(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, String>? additionalHeaders,
    Object? body,
    bool useQueryParamToken = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return HttpClientService.deleteJson(
      AppConfig.api(path),
      additionalHeaders: additionalHeaders,
      body: body,
      useQueryParamToken: useQueryParamToken,
      timeout: timeout,
    );
  }
}

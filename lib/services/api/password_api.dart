import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/app_config.dart';

class PasswordApi {
  static Exception _toUserFacingException(Object e) {
    final message = e.toString();

    // 後端若回傳 SQL / PDO 例外，避免直接顯示資料庫細節到前端
    final looksLikeSql =
        message.contains('SQLSTATE') || message.contains('Unknown column');
    if (looksLikeSql) {
      return Exception('Server error. Please try again later.');
    }

    // 去掉預設 Exception prefix，讓 UI 顯示更乾淨
    final cleaned = message.replaceFirst('Exception: ', '');
    return Exception(cleaned);
  }

  /// 變更密碼
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final body = {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': newPassword, // 後端需要此參數進行二次驗證
      };

      final response = await HttpClientService.post(
        AppConfig.api('/account/change-password.php'),
        body: jsonEncode(body),
        useQueryParamToken: true, // 使用查詢參數傳遞 token（MAMP 兼容）
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      throw _toUserFacingException('Network error: $e');
    }
  }

  /// 請求密碼重設
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final body = {
        'email': email,
      };

      final response = await HttpClientService.post(
        AppConfig.api('/account/request-password-reset.php'),
        body: jsonEncode(body),
      );
      debugPrint('RESET FILE v2 🔴');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        if (kDebugMode) {
          debugPrint(
              '[PasswordApi] requestPasswordReset failed: ${response.statusCode} body:${response.body}');
        }
        final dynamic errorBody = _safeDecodeJson(response.body);
        if (errorBody is Map && errorBody['message'] != null) {
          throw Exception(errorBody['message']);
        }
        throw Exception('Failed to request password reset');
      }
    } catch (e) {
      throw _toUserFacingException('Network error: $e');
    }
  }

  static dynamic _safeDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// 刪除帳號
  static Future<Map<String, dynamic>> deleteAccount({
    required String password, // 現在是 "DELETE" 確認文字
    String? reason, // 改為可選參數
  }) async {
    try {
      final body = <String, dynamic>{
        'confirmation': password, // 傳遞 "DELETE" 確認文字
      };

      // 只有在有原因時才添加
      if (reason != null && reason.isNotEmpty) {
        body['reason'] = reason;
      }

      final response = await HttpClientService.post(
        AppConfig.api('/account/delete.php'),
        body: jsonEncode(body),
        useQueryParamToken: true, // 使用查詢參數傳遞 token（MAMP 兼容）
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      throw _toUserFacingException('Network error: $e');
    }
  }
}

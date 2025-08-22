import 'dart:convert';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/app_config.dart';

class PasswordApi {
  /// 變更密碼
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final body = {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      };

      final response = await HttpClientService.post(
        '${AppConfig.apiBaseUrl}/backend/api/account/change-password.php',
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      throw Exception('Network error: $e');
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
        '${AppConfig.apiBaseUrl}/backend/api/account/request-password-reset.php',
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to request password reset');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 重設密碼
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final body = {
        'token': token,
        'email': email,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      };

      final response = await HttpClientService.post(
        '${AppConfig.apiBaseUrl}/backend/api/account/reset-password.php',
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to reset password');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 刪除帳號
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
    required String reason,
  }) async {
    try {
      final body = {
        'password': password,
        'reason': reason,
      };

      final response = await HttpClientService.post(
        '${AppConfig.apiBaseUrl}/backend/api/account/delete.php',
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete account');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

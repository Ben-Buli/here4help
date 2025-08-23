import 'dart:convert';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/app_config.dart';

class AccountApi {
  static Map<String, dynamic> _safeDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'message': 'Non-JSON response',
        'raw': body,
      };
    }
  }

  /// 檢查帳號風險操作
  static Future<Map<String, dynamic>> checkRiskyActions(String token) async {
    final response = await HttpClientService.get(
      '${AppConfig.apiBaseUrl}/backend/api/account/risky-actions-check.php',
      useQueryParamToken: true,
      additionalHeaders: {'Authorization': 'Bearer $token'},
    );
    final data = _safeDecode(response.body);
    data['statusCode'] = response.statusCode;
    return data;
  }

  /// 停用帳號
  static Future<Map<String, dynamic>> deactivateAccount(String token) async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/account/deactivate.php',
      useQueryParamToken: true,
      additionalHeaders: {'Authorization': 'Bearer $token'},
    );
    final data = _safeDecode(response.body);
    data['statusCode'] = response.statusCode;
    return data;
  }

  /// 重新啟用帳號
  static Future<Map<String, dynamic>> reactivateAccount(String token) async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/account/reactivate.php',
      useQueryParamToken: true,
      additionalHeaders: {'Authorization': 'Bearer $token'},
    );
    final data = _safeDecode(response.body);
    data['statusCode'] = response.statusCode;
    return data;
  }
}

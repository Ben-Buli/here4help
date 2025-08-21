
import 'dart:convert';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/app_config.dart';

class AccountApi {
  /// 檢查帳號風險操作
  static Future<Map<String, dynamic>> checkRiskyActions(String token) async {
    try {
      final response = await HttpClientService.get(
        '${AppConfig.apiBaseUrl}/backend/api/account/risky-actions-check.php?token=$token',
        useQueryParamToken: false,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to check risky actions');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// 停用帳號
  static Future<Map<String, dynamic>> deactivateAccount(String token) async {
    try {
      final response = await HttpClientService.post(
        '${AppConfig.apiBaseUrl}/backend/api/account/deactivate.php?token=$token',
        body: '{}',
        useQueryParamToken: false,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to deactivate account');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// 重新啟用帳號
  static Future<Map<String, dynamic>> reactivateAccount(String token) async {
    try {
      final response = await HttpClientService.post(
        '${AppConfig.apiBaseUrl}/backend/api/account/reactivate.php?token=$token',
        body: '{}',
        useQueryParamToken: false,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to reactivate account');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

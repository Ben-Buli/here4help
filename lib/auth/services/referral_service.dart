import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  /// 獲取用戶的推薦碼
  Future<Map<String, dynamic>> getReferralCode(String token) async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.referralCodeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to get referral code');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 使用推薦碼
  Future<Map<String, dynamic>> useReferralCode(
      String referralCode, int userId) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.useReferralCodeUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'referral_code': referralCode,
          'user_id': userId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to use referral code');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 獲取推薦碼列表（管理員功能）
  Future<Map<String, dynamic>> getReferralCodeList({
    int page = 1,
    int limit = 20,
    String status = '',
    String search = '',
    String? token,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (status.isNotEmpty) 'status': status,
        if (search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse(AppConfig.referralCodeListUrl)
          .replace(queryParameters: queryParams);

      final headers = {
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to get referral code list');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 生成推薦碼（用於測試）
  String generateReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String result = '';
    for (int i = 0; i < 6; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }
}

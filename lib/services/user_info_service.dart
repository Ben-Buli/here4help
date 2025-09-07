import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';

/// 用戶公開資訊模型
class UserPublicInfo {
  final int id;
  final String name;
  final String nickname;
  final String avatarUrl;
  final String displayName;

  UserPublicInfo({
    required this.id,
    required this.name,
    required this.nickname,
    required this.avatarUrl,
    required this.displayName,
  });

  factory UserPublicInfo.fromJson(Map<String, dynamic> json) {
    return UserPublicInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      nickname: json['nickname'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      displayName: json['display_name'] ?? 'User',
    );
  }
}

/// 用戶資訊服務
class UserInfoService {
  /// 獲取用戶公開資訊 API URL
  static String get publicInfoUrl => AppConfig.api('/users/public-info.php');

  /// 根據用戶ID獲取公開資訊
  static Future<UserPublicInfo?> getUserPublicInfo(int userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('❌ UserInfoService: No authentication token found');
        return null;
      }

      final uri = Uri.parse('$publicInfoUrl?user_id=$userId');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print(
              '✅ UserInfoService: Successfully got user public info for user $userId');
          return UserPublicInfo.fromJson(data['data']);
        } else {
          print('❌ UserInfoService: API returned error: ${data['message']}');
          throw Exception(data['message'] ?? 'Failed to get user public info');
        }
      } else {
        print(
            '❌ UserInfoService: HTTP error ${response.statusCode}: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ UserInfoService: Error getting user public info: $e');
      return null;
    }
  }

  /// 獲取用戶完整資訊（包含評分統計）
  /// 返回 (姓名, 頭像URL, 平均評分, 評論數量)
  static Future<(String, String?, double, int)> getUserCompleteInfo(
      int userId) async {
    try {
      // 並行請求用戶基本資訊和評分統計
      final futures = await Future.wait([
        getUserPublicInfo(userId),
        _getUserRatingStats(userId),
      ]);

      final userInfo = futures[0] as UserPublicInfo?;
      final ratingStats = futures[1] as Map<String, dynamic>?;

      final name = userInfo?.displayName ?? 'User';
      final avatarUrl = userInfo?.avatarUrl;

      double avgRating = 0.0;
      int reviewsCount = 0;

      if (ratingStats != null) {
        final asTasker = ratingStats['as_tasker'] as Map<String, dynamic>?;
        if (asTasker != null) {
          avgRating = (asTasker['avg_rating'] as num?)?.toDouble() ?? 0.0;
          reviewsCount = (asTasker['total_reviews'] as num?)?.toInt() ?? 0;
        }
      }

      print(
          '✅ UserInfoService: Complete info for user $userId - $name, rating: $avgRating ($reviewsCount reviews)');
      return (name, avatarUrl, avgRating, reviewsCount);
    } catch (e) {
      print('❌ UserInfoService: Error getting complete user info: $e');
      return ('User', null, 0.0, 0);
    }
  }

  /// 獲取用戶評分統計（私有方法）
  static Future<Map<String, dynamic>?> _getUserRatingStats(int userId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final uri = Uri.parse(
          '${AppConfig.api('/ratings/user-stats.php')}?user_id=$userId');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('❌ UserInfoService: Error getting rating stats: $e');
      return null;
    }
  }
}

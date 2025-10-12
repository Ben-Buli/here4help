import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/services/http_client_service.dart';

class UserAchievements {
  final UserInfo userInfo;
  final Achievements achievements;
  final AdditionalStats additionalStats;

  UserAchievements({
    required this.userInfo,
    required this.achievements,
    required this.additionalStats,
  });

  factory UserAchievements.fromJson(Map<String, dynamic> json) {
    return UserAchievements(
      userInfo: UserInfo.fromJson(json['user_info'] ?? {}),
      achievements: Achievements.fromJson(json['achievements'] ?? {}),
      additionalStats: AdditionalStats.fromJson(json['additional_stats'] ?? {}),
    );
  }
}

class UserInfo {
  final int id;
  final String name;
  final String email;
  final String? avatarUrl;

  UserInfo({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: _safeToInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class Achievements {
  final int totalCoins;
  final int tasksCompleted;
  final int fiveStarRatings;
  final double avgRating;

  Achievements({
    required this.totalCoins,
    required this.tasksCompleted,
    required this.fiveStarRatings,
    required this.avgRating,
  });

  factory Achievements.fromJson(Map<String, dynamic> json) {
    return Achievements(
      totalCoins: _safeToInt(json['total_coins']),
      tasksCompleted: _safeToInt(json['tasks_completed']),
      fiveStarRatings: _safeToInt(json['five_star_ratings']),
      avgRating: _safeToDouble(json['avg_rating']),
    );
  }
}

class AdditionalStats {
  final int totalApplications;
  final int acceptedApplications;
  final int postedTasks;
  final int totalRatings;
  final int totalComments;

  AdditionalStats({
    required this.totalApplications,
    required this.acceptedApplications,
    required this.postedTasks,
    required this.totalRatings,
    required this.totalComments,
  });

  factory AdditionalStats.fromJson(Map<String, dynamic> json) {
    return AdditionalStats(
      totalApplications: _safeToInt(json['total_applications']),
      acceptedApplications: _safeToInt(json['accepted_applications']),
      postedTasks: _safeToInt(json['posted_tasks']),
      totalRatings: _safeToInt(json['total_ratings']),
      totalComments: _safeToInt(json['total_comments']),
    );
  }
}

// 安全的類型轉換函數
int _safeToInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

double _safeToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class AchievementService {
  /// 獲取用戶成就統計 API URL
  static String get achievementsUrl =>
      AppConfig.api('/account/achievements.php');

  /// 獲取用戶成就統計
  static Future<UserAchievements?> getUserAchievements({int? userId}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('❌ AchievementService: No authentication token found');
        return null;
      }

      final path = '/account/achievements.php';
      final queryPath = userId != null ? '$path?user_id=$userId' : path;

      if (kDebugMode) {
        print('🔍 AchievementService: API PATH: $queryPath');
      }

      // 使用 ApiClient 統一請求，非 production 會自動附上 query token 備援
      final data = await HttpClientService.getJson(
        AppConfig.api(queryPath),
        useQueryParamToken: true,
      );

      if (data['success'] == true) {
        print('✅ AchievementService: Successfully got achievements');
        return UserAchievements.fromJson(data['data']);
      } else {
        print('❌ AchievementService: API returned error: ${data['message']}');
        throw Exception(data['message'] ?? 'Failed to get achievements');
      }
    } catch (e) {
      print('❌ AchievementService: Error getting achievements: $e');
      return null;
    }
  }

  /// 格式化積分顯示
  static String formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }

  /// 格式化評分顯示
  static String formatRating(double rating) {
    if (rating == 0.0) return 'N/A';
    return rating.toStringAsFixed(1);
  }
}

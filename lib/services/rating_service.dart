import 'package:flutter/material.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/services/http_client_service.dart';

class RatingStats {
  final double avgRating;
  final int totalReviews;
  final int totalComments;
  final Map<int, int> ratingDistribution;
  final int givenReviews;
  final int givenComments;
  final List<RecentRating> recentRatings;

  RatingStats({
    required this.avgRating,
    required this.totalReviews,
    required this.totalComments,
    required this.ratingDistribution,
    required this.givenReviews,
    required this.givenComments,
    required this.recentRatings,
  });

  factory RatingStats.fromJson(Map<String, dynamic> json) {
    final asTasker = json['as_tasker'] ?? {};
    final asRater = json['as_rater'] ?? {};
    final recentRatingsData = json['recent_ratings'] as List? ?? [];

    // 安全的數值轉換函數
    int safeToInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // 安全處理評分分布
    Map<int, int> safeRatingDistribution(dynamic dist) {
      if (dist == null) return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      if (dist is Map) {
        Map<int, int> result = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        dist.forEach((key, value) {
          int intKey = safeToInt(key);
          int intValue = safeToInt(value);
          if (intKey >= 1 && intKey <= 5) {
            result[intKey] = intValue;
          }
        });
        return result;
      }
      return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }

    return RatingStats(
      avgRating: safeToDouble(asTasker['avg_rating']),
      totalReviews: safeToInt(asTasker['total_reviews']),
      totalComments: safeToInt(asTasker['total_comments']),
      ratingDistribution:
          safeRatingDistribution(asTasker['rating_distribution']),
      givenReviews: safeToInt(asRater['given_reviews']),
      givenComments: safeToInt(asRater['given_comments']),
      recentRatings: recentRatingsData
          .map((rating) => RecentRating.fromJson(rating))
          .toList(),
    );
  }
}

class RecentRating {
  final int rating;
  final String comment;
  final String createdAt;
  final String raterName;
  final String? raterAvatar;
  final String? taskTitle;

  RecentRating({
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.raterName,
    this.raterAvatar,
    this.taskTitle,
  });

  factory RecentRating.fromJson(Map<String, dynamic> json) {
    final rater = json['rater'] ?? {};

    // 安全的數值轉換
    int safeToInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    return RecentRating(
      rating: safeToInt(json['rating']),
      comment: json['comment']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      raterName: rater['name']?.toString() ?? '',
      raterAvatar: rater['avatar_url']?.toString(),
      taskTitle: json['task_title']?.toString(),
    );
  }
}

class RatingService {
  /// 獲取使用者評分統計 API URL
  static String get userStatsUrl => AppConfig.api('/ratings/user-stats.php');

  /// 獲取使用者評分統計
  static Future<RatingStats?> getUserRatingStats({int? userId}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        print('❌ RatingService: No authentication token found');
        return null;
      }

      const path = '/ratings/user-stats.php';
      final queryPath = userId != null ? '$path?user_id=$userId' : path;

      final data = await HttpClientService.getJson(
        AppConfig.api(queryPath),
        useQueryParamToken: true,
      );

      if (data['success'] == true) {
        return RatingStats.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to get rating stats');
      }
    } catch (e) {
      return null;
    }
  }

  /// 生成星星評分顯示
  static List<Widget> buildStarRating(double rating, {double size = 16}) {
    List<Widget> stars = [];
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    // 添加滿星
    for (int i = 0; i < fullStars; i++) {
      stars.add(Icon(Icons.star, color: Colors.amber, size: size));
    }

    // 添加半星
    if (hasHalfStar && fullStars < 5) {
      stars.add(Icon(Icons.star_half, color: Colors.amber, size: size));
      fullStars++;
    }

    // 添加空星
    for (int i = fullStars; i < 5; i++) {
      stars.add(Icon(Icons.star_border, color: Colors.amber, size: size));
    }

    return stars;
  }

  /// 格式化評分文字
  static String formatRatingText(RatingStats stats) {
    if (stats.totalReviews == 0) {
      return 'No ratings yet';
    }

    return '${stats.avgRating.toStringAsFixed(1)} (${stats.totalComments} comments)';
  }
}

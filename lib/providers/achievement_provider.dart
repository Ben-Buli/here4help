import 'package:flutter/material.dart';
import 'package:here4help/services/achievement_service.dart';

class AchievementProvider extends ChangeNotifier {
  UserAchievements? _userAchievements;
  bool _isLoading = false;
  String? _error;

  UserAchievements? get userAchievements => _userAchievements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 獲取當前使用者的成就統計
  Future<void> loadUserAchievements({int? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final achievements =
          await AchievementService.getUserAchievements(userId: userId);
      _userAchievements = achievements;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _userAchievements = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除成就統計數據
  void clearAchievements() {
    _userAchievements = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// 刷新成就統計
  Future<void> refreshAchievements({int? userId}) async {
    await loadUserAchievements(userId: userId);
  }

  /// 獲取格式化的成就數據
  Map<String, String> getFormattedAchievements() {
    if (_userAchievements == null) {
      return {
        'total_coins': '0',
        'tasks_completed': '0',
        'five_star_ratings': '0',
        'avg_rating': 'N/A',
      };
    }

    final achievements = _userAchievements!.achievements;
    return {
      'total_coins': AchievementService.formatCoins(achievements.totalCoins),
      'tasks_completed': achievements.tasksCompleted.toString(),
      'five_star_ratings': achievements.fiveStarRatings.toString(),
      'avg_rating': AchievementService.formatRating(achievements.avgRating),
    };
  }
}

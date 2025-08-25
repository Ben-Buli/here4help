import 'package:flutter/material.dart';
import 'package:here4help/services/rating_service.dart';

class RatingProvider extends ChangeNotifier {
  RatingStats? _userRatingStats;
  bool _isLoading = false;
  String? _error;

  RatingStats? get userRatingStats => _userRatingStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 獲取當前使用者的評分統計
  Future<void> loadUserRatingStats({int? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final stats = await RatingService.getUserRatingStats(userId: userId);
      _userRatingStats = stats;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _userRatingStats = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除評分統計數據
  void clearRatingStats() {
    _userRatingStats = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// 刷新評分統計
  Future<void> refreshRatingStats({int? userId}) async {
    await loadUserRatingStats(userId: userId);
  }
}

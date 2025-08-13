import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../auth/services/auth_service.dart';

/// 任務收藏服務
class TaskFavoritesService extends ChangeNotifier {
  static final TaskFavoritesService _instance =
      TaskFavoritesService._internal();
  factory TaskFavoritesService() => _instance;
  TaskFavoritesService._internal();

  // 收藏狀態快取
  final Map<String, bool> _favoriteStatusCache = {};
  final Map<String, int> _favoriteCountCache = {};

  /// 切換任務收藏狀態
  Future<bool> toggleFavorite(String taskId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http
          .post(
            Uri.parse(AppConfig.taskFavoritesToggleUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'task_id': taskId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final result = data['data'];
          final isFavorited = result['is_favorited'] ?? false;
          final favoritesCount = result['favorites_count'] ?? 0;

          // 更新快取
          _favoriteStatusCache[taskId] = isFavorited;
          _favoriteCountCache[taskId] = favoritesCount;

          notifyListeners();
          return isFavorited;
        } else {
          throw Exception(data['message'] ?? 'Failed to toggle favorite');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: Failed to toggle favorite');
      }
    } catch (e) {
      debugPrint('TaskFavoritesService toggleFavorite error: $e');
      rethrow;
    }
  }

  /// 獲取用戶收藏的任務列表
  Future<List<Map<String, dynamic>>> getFavoriteTasks({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse(AppConfig.taskFavoritesListUrl).replace(queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final tasks =
              List<Map<String, dynamic>>.from(data['data']['tasks'] ?? []);

          // 更新收藏狀態快取
          for (final task in tasks) {
            final taskId = task['id']?.toString();
            if (taskId != null) {
              _favoriteStatusCache[taskId] = true; // 收藏列表中的都是已收藏
            }
          }

          return tasks;
        } else {
          throw Exception(data['message'] ?? 'Failed to get favorite tasks');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: Failed to get favorite tasks');
      }
    } catch (e) {
      debugPrint('TaskFavoritesService getFavoriteTasks error: $e');
      return [];
    }
  }

  /// 檢查任務是否已收藏（從快取）
  bool isFavorited(String taskId) {
    return _favoriteStatusCache[taskId] ?? false;
  }

  /// 獲取任務收藏數（從快取）
  int getFavoriteCount(String taskId) {
    return _favoriteCountCache[taskId] ?? 0;
  }

  /// 批量檢查任務收藏狀態
  Future<void> checkFavoriteStatus(List<String> taskIds) async {
    // 這裡可以實現批量檢查API，目前暫時跳過
    // 實際使用時會在任務列表載入時一併取得收藏狀態
  }

  /// 更新任務的收藏狀態（用於從任務列表API取得資料時更新快取）
  void updateFavoriteStatus(String taskId, bool isFavorited, [int? count]) {
    _favoriteStatusCache[taskId] = isFavorited;
    if (count != null) {
      _favoriteCountCache[taskId] = count;
    }
    notifyListeners();
  }

  /// 清除快取
  void clearCache() {
    _favoriteStatusCache.clear();
    _favoriteCountCache.clear();
    notifyListeners();
  }

  /// 清除特定任務的快取
  void clearTaskCache(String taskId) {
    _favoriteStatusCache.remove(taskId);
    _favoriteCountCache.remove(taskId);
    notifyListeners();
  }
}

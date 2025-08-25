import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 任務收藏 API 服務
class TaskFavoritesApi {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/backend/api/tasks';

  /// 獲取用戶收藏列表
  static Future<Map<String, dynamic>> getFavorites({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 獲取收藏列表: page=$page, perPage=$perPage');
      }

      final response = await HttpClientService.get(
        '$_baseUrl/favorites.php?page=$page&per_page=$perPage',
      );

      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 收藏列表回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'TaskFavoritesApi: 收藏列表獲取成功: ${data['data']['favorites'].length} 筆');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '獲取收藏列表失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '獲取收藏列表失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 獲取收藏列表錯誤: $e');
      }
      rethrow;
    }
  }

  /// 收藏任務
  static Future<Map<String, dynamic>> addFavorite({
    required String taskId,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 收藏任務: taskId=$taskId');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/favorites.php',
        body: {
          'task_id': taskId,
        },
      );

      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 收藏任務回應: ${response.statusCode}');
        debugPrint('TaskFavoritesApi: 回應內容: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('TaskFavoritesApi: 任務收藏成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '收藏任務失敗');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
              errorData['message'] ?? '收藏任務失敗 (HTTP ${response.statusCode})');
        } catch (jsonError) {
          throw Exception('收藏任務失敗 (HTTP ${response.statusCode})');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 收藏任務錯誤: $e');
      }
      rethrow;
    }
  }

  /// 取消收藏任務
  static Future<Map<String, dynamic>> removeFavorite({
    required String taskId,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 取消收藏任務: taskId=$taskId');
      }

      final response = await HttpClientService.delete(
        '$_baseUrl/favorites.php',
        body: {
          'task_id': taskId,
        },
      );

      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 取消收藏任務回應: ${response.statusCode}');
        debugPrint('TaskFavoritesApi: 回應內容: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('TaskFavoritesApi: 取消收藏任務成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '取消收藏任務失敗');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
              errorData['message'] ?? '取消收藏任務失敗 (HTTP ${response.statusCode})');
        } catch (jsonError) {
          throw Exception('取消收藏任務失敗 (HTTP ${response.statusCode})');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 取消收藏任務錯誤: $e');
      }
      rethrow;
    }
  }

  /// 檢查任務是否已收藏
  static Future<bool> isFavorited({
    required String taskId,
  }) async {
    try {
      // 獲取第一頁收藏列表來檢查
      final result = await getFavorites(page: 1, perPage: 100);
      final favorites = result['favorites'] as List<dynamic>;

      return favorites.any((favorite) => favorite['task_id'] == taskId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskFavoritesApi: 檢查收藏狀態錯誤: $e');
      }
      return false; // 錯誤時預設為未收藏
    }
  }
}

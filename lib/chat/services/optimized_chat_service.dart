import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

/// 優化的聊天服務 - 減少API調用次數，提升性能
class OptimizedChatService {
  static final OptimizedChatService _instance =
      OptimizedChatService._internal();
  factory OptimizedChatService() => _instance;
  OptimizedChatService._internal();

  // 快取
  final Map<int, List<Map<String, dynamic>>> _postedTasksCache = {};
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// 獲取用戶發布的任務及應徵者（聚合API）
  /// 替代原來的多次API調用
  Future<List<Map<String, dynamic>>> getPostedTasksWithApplicants({
    required int userId,
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // 檢查快取
    if (!forceRefresh && _isValidCache(userId)) {
      debugPrint('📦 使用快取的任務數據');
      return _postedTasksCache[userId] ?? [];
    }

    try {
      debugPrint('🚀 調用聚合API獲取發布任務數據...');

      final response = await http.get(
        Uri.parse(
                '${AppConfig.apiBaseUrl}/backend/api/chat/get_posted_tasks_with_applicants.php')
            .replace(queryParameters: {
          'user_id': userId.toString(),
          'limit': limit.toString(),
          'offset': offset.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final tasks = List<Map<String, dynamic>>.from(
              data['data']['tasks_with_applicants'] ?? []);

          // 更新快取
          _postedTasksCache[userId] = tasks;
          _lastCacheTime = DateTime.now();

          debugPrint('✅ 聚合API成功獲取 ${tasks.length} 個任務');
          return tasks;
        }
      }

      throw Exception('API響應錯誤: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ 聚合API調用失敗: $e');
      // 返回快取數據作為降級
      return _postedTasksCache[userId] ?? [];
    }
  }

  /// 轉換為聊天室格式（與原有邏輯兼容）
  List<Map<String, dynamic>> convertToApplierChatItems(
      List<Map<String, dynamic>> applications) {
    return applications.map((app) {
      return {
        'id': 'app_${app['application_id'] ?? app['user_id']}',
        'taskId': app['task_id'],
        'name': app['applier_name'] ?? 'Anonymous',
        'avatar': app['applier_avatar'],
        'participant_avatar': app['applier_avatar'],
        'participant_avatar_url': app['applier_avatar'],
        'rating': 4.0,
        'reviewsCount': 0,
        'questionReply': app['cover_letter'] ?? '',
        'sentMessages': [app['cover_letter'] ?? 'Applied for this task'],
        'user_id': app['user_id'],
        'participant_id': app['user_id'],
        'application_id': app['application_id'],
        'application_status': app['application_status'] ?? 'applied',
        'answers_json': app['answers_json'],
        'created_at': app['created_at'],
        'isMuted': false,
        'isHidden': false,
        // 新增：聊天室信息
        'room_id': app['room_id'],
        'room_type': app['room_type'],
      };
    }).toList();
  }

  /// 批量預載入聊天室數據
  Future<void> preloadChatRooms(List<String> taskIds) async {
    if (taskIds.isEmpty) return;

    debugPrint('🔄 預載入 ${taskIds.length} 個任務的聊天室數據...');
    // 這裡可以實現批量預載入邏輯
    // 暫時先記錄，未來可以擴展
  }

  /// 檢查快取是否有效
  bool _isValidCache(int userId) {
    if (!_postedTasksCache.containsKey(userId) || _lastCacheTime == null) {
      return false;
    }

    final now = DateTime.now();
    final diff = now.difference(_lastCacheTime!);
    return diff < _cacheValidDuration;
  }

  /// 清除快取
  void clearCache([int? userId]) {
    if (userId != null) {
      _postedTasksCache.remove(userId);
    } else {
      _postedTasksCache.clear();
    }
    _lastCacheTime = null;
    debugPrint('🗑️ 聊天快取已清除');
  }

  /// 獲取快取統計
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_users': _postedTasksCache.keys.length,
      'total_tasks': _postedTasksCache.values.expand((tasks) => tasks).length,
      'last_cache_time': _lastCacheTime?.toIso8601String(),
      'cache_valid': _lastCacheTime != null &&
          DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration,
    };
  }
}


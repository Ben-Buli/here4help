import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/config/app_config.dart';
import 'offline_aware_api.dart';

/// 離線感知的任務 API 服務
/// 提供任務相關的離線支援功能
class OfflineTaskApi extends OfflineAwareApi {
  /// 獲取任務列表（支援離線快取）
  Future<Map<String, dynamic>> getTaskList({
    int page = 1,
    int perPage = 20,
    String? status,
    String? category,
    bool forceRefresh = false,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (status != null) queryParams['status'] = status;
    if (category != null) queryParams['category'] = category;

    final endpoint = '/tasks?${Uri(queryParameters: queryParams).query}';

    return await cachedListGet(
      endpoint: endpoint,
      listType: 'tasks',
      page: page,
      perPage: perPage,
      cacheExpiry: const Duration(minutes: 30),
      forceRefresh: forceRefresh,
    );
  }

  /// 獲取我發布的任務（支援離線快取）
  Future<Map<String, dynamic>> getMyPostedTasks({
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    final endpoint = '/tasks/my-posted?page=$page&per_page=$perPage';

    return await cachedListGet(
      endpoint: endpoint,
      listType: 'posted_tasks',
      page: page,
      perPage: perPage,
      cacheExpiry: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
    );
  }

  /// 獲取我接受的任務（支援離線快取）
  Future<Map<String, dynamic>> getMyAcceptedTasks({
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    final endpoint = '/tasks/my-accepted?page=$page&per_page=$perPage';

    return await cachedListGet(
      endpoint: endpoint,
      listType: 'accepted_tasks',
      page: page,
      perPage: perPage,
      cacheExpiry: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
    );
  }

  /// 獲取收藏任務（支援離線快取）
  Future<Map<String, dynamic>> getFavoriteTasks({
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    final endpoint = '/tasks/favorites?page=$page&per_page=$perPage';

    return await cachedListGet(
      endpoint: endpoint,
      listType: 'favorite_tasks',
      page: page,
      perPage: perPage,
      cacheExpiry: const Duration(hours: 1),
      forceRefresh: forceRefresh,
    );
  }

  /// 獲取任務詳情（支援離線快取）
  Future<Map<String, dynamic>> getTaskDetail(int taskId,
      {bool forceRefresh = false}) async {
    final endpoint = '/tasks/$taskId';
    final cacheKey = 'task_detail_$taskId';

    return await cachedGet(
      endpoint: endpoint,
      cacheKey: cacheKey,
      cacheExpiry: const Duration(minutes: 15),
      forceRefresh: forceRefresh,
    );
  }

  /// 創建任務（支援離線佇列）
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    return await offlineAwarePost(
      endpoint: '/tasks',
      data: taskData,
      allowOfflineQueue: true,
      offlineActionType: 'create_task',
    );
  }

  /// 更新任務（支援離線佇列）
  Future<Map<String, dynamic>> updateTask(
      int taskId, Map<String, dynamic> taskData) async {
    final result = await offlineAwarePost(
      endpoint: '/tasks/$taskId',
      data: taskData,
      allowOfflineQueue: true,
      offlineActionType: 'update_task',
    );

    // 如果成功，使相關快取失效
    if (result['success'] == true && !result['queued']) {
      await invalidateCache('task');
    }

    return result;
  }

  /// 應徵任務（支援離線佇列）
  Future<Map<String, dynamic>> applyForTask(int taskId, String message) async {
    return await offlineAwarePost(
      endpoint: '/tasks/$taskId/apply',
      data: {'message': message},
      allowOfflineQueue: true,
      offlineActionType: 'apply_task',
    );
  }

  /// 接受應徵（支援離線佇列）
  Future<Map<String, dynamic>> acceptApplication(
      int taskId, int applicationId) async {
    final result = await offlineAwarePost(
      endpoint: '/tasks/$taskId/applications/$applicationId/accept',
      data: {},
      allowOfflineQueue: true,
      offlineActionType: 'accept_application',
    );

    // 如果成功，使相關快取失效
    if (result['success'] == true && !result['queued']) {
      await invalidateCache('task');
      await invalidateCache('chat');
    }

    return result;
  }

  /// 拒絕應徵（支援離線佇列）
  Future<Map<String, dynamic>> rejectApplication(
      int taskId, int applicationId) async {
    return await offlineAwarePost(
      endpoint: '/tasks/$taskId/applications/$applicationId/reject',
      data: {},
      allowOfflineQueue: true,
      offlineActionType: 'reject_application',
    );
  }

  /// 完成任務（支援離線佇列）
  Future<Map<String, dynamic>> completeTask(int taskId) async {
    final result = await offlineAwarePost(
      endpoint: '/tasks/$taskId/complete',
      data: {},
      allowOfflineQueue: true,
      offlineActionType: 'complete_task',
    );

    // 如果成功，使相關快取失效
    if (result['success'] == true && !result['queued']) {
      await invalidateCache('task');
    }

    return result;
  }

  /// 取消任務（支援離線佇列）
  Future<Map<String, dynamic>> cancelTask(int taskId, String reason) async {
    final result = await offlineAwarePost(
      endpoint: '/tasks/$taskId/cancel',
      data: {'reason': reason},
      allowOfflineQueue: true,
      offlineActionType: 'cancel_task',
    );

    // 如果成功，使相關快取失效
    if (result['success'] == true && !result['queued']) {
      await invalidateCache('task');
    }

    return result;
  }

  /// 收藏/取消收藏任務（支援離線佇列）
  Future<Map<String, dynamic>> toggleFavorite(
      int taskId, bool isFavorite) async {
    final endpoint =
        isFavorite ? '/tasks/$taskId/favorite' : '/tasks/$taskId/unfavorite';

    final result = await offlineAwarePost(
      endpoint: endpoint,
      data: {},
      allowOfflineQueue: true,
      offlineActionType: 'toggle_favorite',
    );

    // 如果成功，使相關快取失效
    if (result['success'] == true && !result['queued']) {
      await invalidateCache('favorite');
    }

    return result;
  }

  /// 檢舉任務（支援離線佇列）
  Future<Map<String, dynamic>> reportTask(
      int taskId, String reason, String description) async {
    return await offlineAwarePost(
      endpoint: '/tasks/$taskId/report',
      data: {
        'reason': reason,
        'description': description,
      },
      allowOfflineQueue: true,
      offlineActionType: 'report_task',
    );
  }

  /// 提交任務評價（支援離線佇列）
  Future<Map<String, dynamic>> submitReview(
      int taskId, int rating, String? comment) async {
    return await offlineAwarePost(
      endpoint: '/tasks/$taskId/review',
      data: {
        'rating': rating,
        'comment': comment,
      },
      allowOfflineQueue: true,
      offlineActionType: 'submit_review',
    );
  }

  // 實現抽象方法

  @override
  Future<Map<String, dynamic>> performGetRequest(String endpoint) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '請求失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> performPostRequest(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(data),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'data': responseData['data'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? '請求失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  @override
  Future<Map<String, dynamic>> performListRequest(
      String endpoint, int page, int perPage) async {
    return await performGetRequest(endpoint);
  }
}

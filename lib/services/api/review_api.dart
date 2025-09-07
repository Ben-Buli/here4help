import 'dart:convert';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/error_handler_service.dart';

class ReviewApi {
  /// 提交任務評價
  static Future<Map<String, dynamic>> submitReview({
    required String taskId,
    required String taskerId,
    required int rating,
    String? comment,
  }) async {
    try {
      final body = {
        'task_id': taskId,
        'tasker_id': taskerId,
        'rating': rating,
        'comment': comment,
      };

      final response = await HttpClientService.post(
        AppConfig.api('/tasks/reviews_submit.php'),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to submit review');
      }
    } catch (e) {
      ErrorHandlerService.logError('ReviewApi.submitReview', e);
      throw Exception(
          ErrorHandlerService.getOperationErrorMessage('submit_rating', e));
    }
  }

  /// 獲取任務評價
  static Future<Map<String, dynamic>> getReview(String taskId) async {
    try {
      final response = await HttpClientService.get(
        '${AppConfig.api('/tasks/reviews_get.php')}?task_id=$taskId',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to get review');
      }
    } catch (e) {
      ErrorHandlerService.logError('ReviewApi.getReview', e);
      throw Exception(
          ErrorHandlerService.getOperationErrorMessage('load_tasks', e));
    }
  }
}

class TaskHistoryApi {
  /// 獲取任務歷史列表
  static Future<Map<String, dynamic>> getTaskHistory({
    required String role, // 'poster' 或 'acceptor'
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await HttpClientService.get(
        '${AppConfig.api('/tasks/history.php')}?role=$role&page=$page&per_page=$perPage',
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to get task history');
      }
    } catch (e) {
      ErrorHandlerService.logError('TaskHistoryApi.getTaskHistory', e);
      throw Exception(
          ErrorHandlerService.getOperationErrorMessage('load_tasks', e));
    }
  }
}

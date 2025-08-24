import 'dart:convert';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/task/models/task_card.dart';

class RatingsService {
  static final String _baseUrl = AppConfig.apiBaseUrl;

  /// 獲取發布的任務列表（發布者視角）
  static Future<Paged<TaskCard>> fetchPosted(int page) async {
    try {
      final response = await HttpClientService.get(
        '$_baseUrl/backend/api/ratings/posted.php?page=$page&per_page=20',
        useQueryParamToken: true,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return Paged<TaskCard>.fromJson(
          data['data'],
          (json) => TaskCard.fromJson(json),
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to load posted tasks');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 獲取接受的任務列表（應徵者視角）
  static Future<Paged<TaskCard>> fetchAccepted(int page) async {
    try {
      final response = await HttpClientService.get(
        '$_baseUrl/backend/api/ratings/accepted.php?page=$page&per_page=20',
        useQueryParamToken: true,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return Paged<TaskCard>.fromJson(
          data['data'],
          (json) => TaskCard.fromJson(json),
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to load accepted tasks');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 獲取未被選中的申請列表
  static Future<Paged<TaskCard>> fetchNotSelected(int page) async {
    try {
      final response = await HttpClientService.get(
        '$_baseUrl/backend/api/ratings/not-selected.php?page=$page&per_page=20',
        useQueryParamToken: true,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return Paged<TaskCard>.fromJson(
          data['data'],
          (json) => _convertNotSelectedToTaskCard(json),
        );
      } else {
        throw Exception(
            data['message'] ?? 'Failed to load not selected applications');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 轉換 not-selected API 回應為 TaskCard 格式
  static TaskCard _convertNotSelectedToTaskCard(Map<String, dynamic> json) {
    return TaskCard(
      taskId: json['task_id'],
      title: json['title'],
      taskDate: DateTime.parse(json['task_date']),
      rewardPoint: json['reward_point'],
      statusId: 0, // Not Selected 沒有 status_id
      statusName: json['application_status_display'] ?? 'Unknown',
      applicationId: json['application_id'],
      applicationStatus: json['application_status'],
      canRate: false,
    );
  }

  /// 提交評分
  static Future<void> createRating(
      String taskId, int rating, String comment) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      if (comment.trim().isEmpty) {
        throw Exception('Comment is required');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/backend/api/tasks/ratings.php?task_id=$taskId',
        useQueryParamToken: true,
        body: {
          'rating': rating,
          'comment': comment.trim(),
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] != true) {
        // 處理特定錯誤碼
        if (response.statusCode == 409) {
          throw Exception('You have already rated this task');
        } else if (response.statusCode == 403) {
          throw Exception('You do not have permission to rate this task');
        } else {
          throw Exception(data['message'] ?? 'Failed to submit rating');
        }
      }
    } catch (e) {
      if (e.toString().contains('409') ||
          e.toString().contains('already rated')) {
        throw Exception('You have already rated this task');
      } else if (e.toString().contains('403') ||
          e.toString().contains('permission')) {
        throw Exception('You do not have permission to rate this task');
      } else {
        throw Exception('網路錯誤: $e');
      }
    }
  }
}

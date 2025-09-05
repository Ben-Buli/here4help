import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 任務爭議 API 服務
class DisputeApi {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/task-disputes';

  /// 檢查是否已存在爭議
  ///
  /// [chatRoomId] 聊天室ID
  ///
  /// 返回檢查結果，包含現有爭議資訊
  static Future<Map<String, dynamic>> checkExistingDispute({
    required String chatRoomId,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('DisputeApi: 檢查現有爭議: chatRoomId=$chatRoomId');
      }

      final response = await HttpClientService.get(
        '$_baseUrl/check.php?chat_room_id=$chatRoomId',
      );

      if (kDebugMode) debugPrint('DisputeApi: 檢查回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) debugPrint('DisputeApi: 檢查成功: ${data['data']}');
          return {
            'exists': data['data']['exists'] ?? false,
            'dispute': data['data']['dispute'], // 包含 id, status, created_at 等資訊
          };
        } else {
          throw Exception(data['message'] ?? '檢查爭議失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '檢查爭議失敗');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeApi: 檢查爭議錯誤: $e');
      rethrow;
    }
  }

  /// 提交任務爭議
  ///
  /// [taskId] 任務ID
  /// [chatRoomId] 聊天室ID
  /// [title] 爭議標題
  /// [description] 爭議描述
  ///
  /// 返回爭議結果
  static Future<Map<String, dynamic>> submitDispute({
    required String taskId,
    required String chatRoomId,
    required String title,
    required String description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('DisputeApi: 提交爭議: taskId=$taskId, title=$title');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/create.php',
        body: {
          'task_id': taskId,
          'task_dispute_chat_room_id': chatRoomId,
          'title': title,
          'description': description,
        },
      );

      if (kDebugMode) debugPrint('DisputeApi: 爭議提交回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) debugPrint('DisputeApi: 爭議提交成功: ${data['data']}');
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '爭議提交失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '爭議提交失敗');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeApi: 爭議提交錯誤: $e');
      rethrow;
    }
  }

  /// 獲取爭議列表 (用於 /issue-status 頁面)
  ///
  /// 返回用戶的爭議列表
  static Future<List<Map<String, dynamic>>> getDisputeList() async {
    try {
      if (kDebugMode) debugPrint('DisputeApi: 獲取爭議列表');

      final response = await HttpClientService.get('$_baseUrl/list.php');

      if (kDebugMode) debugPrint('DisputeApi: 爭議列表回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('DisputeApi: 爭議列表獲取成功: ${data['data'].length} 筆');
          }
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '獲取爭議列表失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '獲取爭議列表失敗');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeApi: 獲取爭議列表錯誤: $e');
      rethrow;
    }
  }

  /// 獲取申訴詳情
  ///
  /// [disputeId] 申訴ID
  ///
  /// 返回申訴詳情
  static Future<Map<String, dynamic>> getDisputeDetail(String disputeId) async {
    try {
      if (kDebugMode) debugPrint('DisputeApi: 獲取申訴詳情: disputeId=$disputeId');

      final response = await HttpClientService.get(
          '$_baseUrl/disputes.php?dispute_id=$disputeId');

      if (kDebugMode) debugPrint('DisputeApi: 申訴詳情回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) debugPrint('DisputeApi: 申訴詳情獲取成功');
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '獲取申訴詳情失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '獲取申訴詳情失敗');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeApi: 獲取申訴詳情錯誤: $e');
      rethrow;
    }
  }
}

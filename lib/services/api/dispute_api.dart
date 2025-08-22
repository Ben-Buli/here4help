import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 申訴 API 服務
class DisputeApi {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/tasks';

  /// 提交任務申訴
  ///
  /// [taskId] 任務ID
  /// [reason] 申訴原因
  /// [description] 申訴描述
  ///
  /// 返回申訴結果
  static Future<Map<String, dynamic>> submitDispute({
    required String taskId,
    required String reason,
    required String description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('DisputeApi: 提交申訴: taskId=$taskId, reason=$reason');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/dispute.php',
        body: {
          'task_id': taskId,
          'reason': reason,
          'description': description,
        },
      );

      if (kDebugMode) debugPrint('DisputeApi: 申訴提交回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) debugPrint('DisputeApi: 申訴提交成功: ${data['data']}');
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '申訴提交失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '申訴提交失敗');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeApi: 申訴提交錯誤: $e');
      rethrow;
    }
  }

  /// 獲取申訴歷史
  ///
  /// [userId] 用戶ID（可選，不提供則獲取當前用戶的申訴）
  ///
  /// 返回申訴列表
  static Future<List<Map<String, dynamic>>> getDisputeHistory({
    String? userId,
  }) async {
    try {
      if (kDebugMode) debugPrint('DisputeApi: 獲取申訴歷史: userId=$userId');

      String url = '$_baseUrl/disputes.php';
      if (userId != null) {
        url += '?user_id=$userId';
      }

      final response = await HttpClientService.get(url);

      if (kDebugMode) debugPrint('DisputeApi: 申訴歷史回應: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('DisputeApi: 申訴歷史獲取成功: ${data['data'].length} 筆');
          }
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? '獲取申訴歷史失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '獲取申訴歷史失敗');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DisputeApi: 獲取申訴歷史錯誤: $e');
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

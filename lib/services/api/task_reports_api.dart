import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 任務檢舉 API 服務
class TaskReportsApi {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/tasks';

  /// 檢舉原因選項
  static const List<Map<String, String>> reportReasons = [
    {'value': 'inappropriate', 'label': '不當內容'},
    {'value': 'spam', 'label': '垃圾訊息'},
    {'value': 'fake', 'label': '虛假任務'},
    {'value': 'dangerous', 'label': '危險活動'},
    {'value': 'other', 'label': '其他原因'},
  ];

  /// 獲取檢舉歷史
  static Future<Map<String, dynamic>> getReports({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint(
            'TaskReportsApi: 獲取檢舉歷史: page=$page, perPage=$perPage, status=$status');
      }

      String url = '$_baseUrl/reports.php?page=$page&per_page=$perPage';
      if (status != null && status.isNotEmpty) {
        url += '&status=$status';
      }

      final response = await HttpClientService.get(url);

      if (kDebugMode) {
        debugPrint('TaskReportsApi: 檢舉歷史回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint(
                'TaskReportsApi: 檢舉歷史獲取成功: ${data['data']['reports'].length} 筆');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '獲取檢舉歷史失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '獲取檢舉歷史失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskReportsApi: 獲取檢舉歷史錯誤: $e');
      }
      rethrow;
    }
  }

  /// 提交任務檢舉
  static Future<Map<String, dynamic>> submitReport({
    required String taskId,
    required String reason,
    required String description,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('TaskReportsApi: 提交檢舉: taskId=$taskId, reason=$reason');
      }

      final response = await HttpClientService.post(
        '$_baseUrl/reports.php',
        body: {
          'task_id': taskId,
          'reason': reason,
          'description': description,
        },
      );

      if (kDebugMode) {
        debugPrint('TaskReportsApi: 檢舉提交回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('TaskReportsApi: 檢舉提交成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '檢舉提交失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '檢舉提交失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskReportsApi: 檢舉提交錯誤: $e');
      }
      rethrow;
    }
  }

  /// 獲取檢舉原因的顯示名稱
  static String getReasonLabel(String reason) {
    for (final reasonMap in reportReasons) {
      if (reasonMap['value'] == reason) {
        return reasonMap['label'] ?? reason;
      }
    }
    return reason;
  }

  /// 獲取檢舉狀態的顯示名稱
  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待審核';
      case 'reviewed':
        return '審核中';
      case 'resolved':
        return '已處理';
      case 'dismissed':
        return '已駁回';
      default:
        return status;
    }
  }

  /// 獲取檢舉狀態的顏色
  static String getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return 'orange';
      case 'reviewed':
        return 'blue';
      case 'resolved':
        return 'green';
      case 'dismissed':
        return 'red';
      default:
        return 'grey';
    }
  }
}


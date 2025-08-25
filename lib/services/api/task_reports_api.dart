import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

/// 任務檢舉相關的資料模型
class TaskReport {
  final int id;
  final String reason;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskReport({
    required this.id,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskReport.fromJson(Map<String, dynamic> json) {
    return TaskReport(
      id: json['id'] ?? 0,
      reason: json['reason'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// 獲取檢舉原因的顯示文字
  String get reasonDisplayText {
    switch (reason) {
      case 'spam_advertising':
        return 'Spam / Advertising';
      case 'fraud_scam':
        return 'Fraud / Scam';
      case 'misleading_false_info':
        return 'Misleading or False Information';
      case 'illegal_activity':
        return 'Illegal Activity';
      case 'abusive_offensive_content':
        return 'Abusive or Offensive Content';
      case 'duplicate_repeated_posting':
        return 'Duplicate or Repeated Posting';
      case 'unreasonable_reward_conditions':
        return 'Unreasonable Reward or Conditions';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }

  /// 獲取狀態的顯示文字
  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'reviewed':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'dismissed':
        return 'Dismissed';
      default:
        return status;
    }
  }
}

/// 任務檢舉 API 服務
class TaskReportsApi {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/backend/api/tasks';

  /// 檢查用戶是否已檢舉過指定任務
  static Future<Map<String, dynamic>> checkReportStatus({
    required String taskId,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('TaskReportsApi: 檢查檢舉狀態: taskId=$taskId');
      }

      final response = await HttpClientService.get(
        '$_baseUrl/reports.php?task_id=$taskId&check_status=1',
      );

      if (kDebugMode) {
        debugPrint('TaskReportsApi: 檢查檢舉狀態回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final result = data['data'];
          return {
            'has_reported': result['has_reported'] ?? false,
            'report': result['report'] != null
                ? TaskReport.fromJson(result['report'])
                : null,
          };
        } else {
          throw Exception(data['message'] ?? '檢查檢舉狀態失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '檢查檢舉狀態失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskReportsApi: 檢查檢舉狀態錯誤: $e');
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
        debugPrint('TaskReportsApi: 提交檢舉回應: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (kDebugMode) {
            debugPrint('TaskReportsApi: 檢舉提交成功: ${data['data']}');
          }
          return data['data'];
        } else {
          throw Exception(data['message'] ?? '提交檢舉失敗');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '提交檢舉失敗');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TaskReportsApi: 提交檢舉錯誤: $e');
      }
      rethrow;
    }
  }

  /// 獲取檢舉原因選項
  static List<Map<String, String>> getReportReasons() {
    return [
      {'value': 'spam_advertising', 'label': 'Spam / Advertising'},
      {'value': 'fraud_scam', 'label': 'Fraud / Scam'},
      {
        'value': 'misleading_false_info',
        'label': 'Misleading or False Information'
      },
      {'value': 'illegal_activity', 'label': 'Illegal Activity'},
      {
        'value': 'abusive_offensive_content',
        'label': 'Abusive or Offensive Content'
      },
      {
        'value': 'duplicate_repeated_posting',
        'label': 'Duplicate or Repeated Posting'
      },
      {
        'value': 'unreasonable_reward_conditions',
        'label': 'Unreasonable Reward or Conditions'
      },
      {'value': 'other', 'label': 'Other (please specify)'},
    ];
  }
}

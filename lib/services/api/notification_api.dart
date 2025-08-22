import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/config/app_config.dart';

class NotificationApi {
  /// 獲取使用者通知偏好
  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/preferences.php'),
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
          'message': data['message'] ?? '獲取通知偏好失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  /// 更新使用者通知偏好
  Future<Map<String, dynamic>> updatePreferences(
      Map<String, dynamic> preferences) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/preferences.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(preferences),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? '設定已儲存',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '更新通知偏好失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  /// 獲取站內通知列表
  Future<Map<String, dynamic>> getInAppNotifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
    bool pinnedOnly = false,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final queryParams = {
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (unreadOnly) 'unread_only': 'true',
        if (pinnedOnly) 'pinned_only': 'true',
      };

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/in_app.php')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
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
          'message': data['message'] ?? '獲取通知失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  /// 標記通知為已讀
  Future<Map<String, dynamic>> markAsRead(int notificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/in_app.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': notificationId,
          'is_read': true,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? '已標記為已讀',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '標記失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  /// 切換通知置頂狀態
  Future<Map<String, dynamic>> togglePin(
      int notificationId, bool isPinned) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/in_app.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': notificationId,
          'is_pinned': isPinned,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? (isPinned ? '已置頂' : '已取消置頂'),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '操作失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  /// 刪除通知
  Future<Map<String, dynamic>> deleteNotification(int notificationId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.delete(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/notifications/in_app.php?id=$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? '通知已刪除',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? '刪除失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }

  /// 觸發通知事件（測試用）
  Future<Map<String, dynamic>> triggerEvent({
    required String eventType,
    required String eventAction,
    required List<int> targetUsers,
    Map<String, dynamic>? eventData,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': '未登入',
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/trigger.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'event_type': eventType,
          'event_action': eventAction,
          'target_users': targetUsers,
          'event_data': eventData ?? {},
        }),
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
          'message': data['message'] ?? '觸發通知失敗',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '網路錯誤: $e',
      };
    }
  }
}

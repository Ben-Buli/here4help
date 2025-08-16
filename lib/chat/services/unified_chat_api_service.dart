import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';

/// 統一聊天 API 服務 - 遵循聊天系統規格文件標準
/// 
/// 實現統一的 API 端點：
/// - GET /api/chat/unreads?scope=posted|myworks|all
/// - POST /api/chat/rooms/{roomId}/read
/// - GET /api/chat/rooms?scope=posted|myworks&with_unread=1
/// - GET /api/chat/unreads/total
class UnifiedChatApiService {
  static const String _tag = '[UnifiedChatApiService]';

  /// 獲取未讀計數 - 規格文件標準
  /// 
  /// [scope] posted|myworks|all
  /// 返回: {total: int, by_room: Map<String, int>, scope: String}
  static Future<Map<String, dynamic>> getUnreadCounts({
    required String scope,
  }) async {
    try {
      debugPrint('$_tag 獲取未讀計數: scope=$scope');

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final url = '${AppConfig.apiBaseUrl}/backend/api/chat/unreads.php?scope=$scope';
      debugPrint('$_tag 請求 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('$_tag 響應狀態: ${response.statusCode}');
      debugPrint('$_tag 響應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to get unread counts');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ $_tag 獲取未讀計數失敗: $e');
      rethrow;
    }
  }

  /// 標記聊天室為已讀 - 規格文件標準
  /// 
  /// [roomId] 聊天室 ID
  /// [upToMessageId] 可選，標記到指定訊息 ID，預設為最新
  /// 返回: {room_id: String, last_read_message_id: int, unread_count: int}
  static Future<Map<String, dynamic>> markRoomAsRead({
    required String roomId,
    int? upToMessageId,
  }) async {
    try {
      debugPrint('$_tag 標記聊天室已讀: roomId=$roomId, upToMessageId=$upToMessageId');

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final url = '${AppConfig.apiBaseUrl}/backend/api/chat/mark_read.php';
      final body = {
        'room_id': roomId,
        if (upToMessageId != null) 'up_to_message_id': upToMessageId,
      };

      debugPrint('$_tag 請求 URL: $url');
      debugPrint('$_tag 請求 body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      debugPrint('$_tag 響應狀態: ${response.statusCode}');
      debugPrint('$_tag 響應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to mark room as read');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ $_tag 標記已讀失敗: $e');
      rethrow;
    }
  }

  /// 獲取聊天室列表 - 規格文件標準
  /// 
  /// [scope] posted|myworks|all
  /// [withUnread] 是否包含未讀計數
  /// [limit] 分頁限制
  /// [offset] 分頁偏移
  /// 返回: {rooms: List, scope: String, with_unread: bool}
  static Future<Map<String, dynamic>> getChatRooms({
    required String scope,
    bool withUnread = true,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('$_tag 獲取聊天室列表: scope=$scope, withUnread=$withUnread');

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final queryParams = {
        'scope': scope,
        if (withUnread) 'with_unread': '1',
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final url = '${AppConfig.apiBaseUrl}/backend/api/chat/rooms.php?$query';
      debugPrint('$_tag 請求 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('$_tag 響應狀態: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to get chat rooms');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ $_tag 獲取聊天室列表失敗: $e');
      rethrow;
    }
  }

  /// 獲取全域未讀總計 - 規格文件標準
  /// 
  /// 返回: {total_unread: int}
  static Future<int> getTotalUnreadCount() async {
    try {
      debugPrint('$_tag 獲取全域未讀總計');

      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final url = '${AppConfig.apiBaseUrl}/backend/api/chat/total_unread.php';
      debugPrint('$_tag 請求 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('$_tag 響應狀態: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['total_unread'] ?? 0;
        } else {
          throw Exception(data['message'] ?? 'Failed to get total unread count');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ $_tag 獲取全域未讀總計失敗: $e');
      rethrow;
    }
  }

  /// 便捷方法：獲取 Posted Tasks 未讀計數
  static Future<Map<String, dynamic>> getPostedTasksUnread() async {
    return getUnreadCounts(scope: 'posted');
  }

  /// 便捷方法：獲取 My Works 未讀計數
  static Future<Map<String, dynamic>> getMyWorksUnread() async {
    return getUnreadCounts(scope: 'myworks');
  }

  /// 便捷方法：獲取所有未讀計數
  static Future<Map<String, dynamic>> getAllUnread() async {
    return getUnreadCounts(scope: 'all');
  }

  /// 批量獲取所有未讀數據 - 一次性獲取完整數據
  static Future<Map<String, dynamic>> getAllUnreadData() async {
    try {
      debugPrint('$_tag 批量獲取所有未讀數據');

      final futures = await Future.wait([
        getUnreadCounts(scope: 'posted'),
        getUnreadCounts(scope: 'myworks'),
        getUnreadCounts(scope: 'all'),
        getTotalUnreadCount(),
      ]);

      final posted = futures[0] as Map<String, dynamic>;
      final myworks = futures[1] as Map<String, dynamic>;
      final all = futures[2] as Map<String, dynamic>;
      final total = futures[3] as int;

      return {
        'posted': posted,
        'myworks': myworks,
        'all': all,
        'total_unread': total,
        'by_room': all['by_room'] ?? {},
        'consistency_check': {
          'posted_total': posted['total'] ?? 0,
          'myworks_total': myworks['total'] ?? 0,
          'all_total': all['total'] ?? 0,
          'total_unread_api': total,
        }
      };
    } catch (e) {
      debugPrint('❌ $_tag 批量獲取未讀數據失敗: $e');
      rethrow;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';

/// 基於角色的未讀訊息服務 (V2)
/// 實作用戶建議的 creator/participant 分頁計算策略
class UnreadServiceV2 {
  static String get _baseUrl => '${AppConfig.apiBaseUrl}/chat';

  /// 獲取分頁未讀數
  /// scope: 'posted', 'myworks', 'all'
  static Future<Map<String, dynamic>> getUnreadByScope({
    String scope = 'all',
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/unread_by_tasks.php?scope=$scope'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('🔴 UnreadServiceV2.getUnreadByScope error: $e');
      rethrow;
    }
  }

  /// 標記聊天室為已讀 (增強版)
  static Future<Map<String, dynamic>> markRoomAsRead(String roomId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token available');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/read_room_v2.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'room_id': roomId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('🔴 UnreadServiceV2.markRoomAsRead error: $e');
      rethrow;
    }
  }

  /// 獲取 Posted Tasks 分頁未讀數據
  static Future<Map<String, int>> getPostedTasksUnread() async {
    final data = await getUnreadByScope(scope: 'posted');
    final byRoom = data['by_room'] as Map<String, dynamic>? ?? {};
    return byRoom.map((k, v) => MapEntry(k, v as int));
  }

  /// 獲取 My Works 分頁未讀數據
  static Future<Map<String, int>> getMyWorksUnread() async {
    final data = await getUnreadByScope(scope: 'myworks');
    final byRoom = data['by_room'] as Map<String, dynamic>? ?? {};
    return byRoom.map((k, v) => MapEntry(k, v as int));
  }

  /// 獲取總未讀數
  static Future<int> getTotalUnread() async {
    final data = await getUnreadByScope(scope: 'all');
    return data['total'] as int? ?? 0;
  }

  /// 批量獲取所有未讀數據（一次 API 調用）
  static Future<
      ({
        int total,
        Map<String, int> postedRooms,
        Map<String, int> myWorksRooms,
        Map<String, int> allRooms,
      })> getAllUnreadData() async {
    final data = await getUnreadByScope(scope: 'all');
    final byRoom = data['by_room'] as Map<String, dynamic>? ?? {};
    final total = data['total'] as int? ?? 0;

    // 獲取分頁數據用於分類
    final postedData = await getUnreadByScope(scope: 'posted');
    final myWorksData = await getUnreadByScope(scope: 'myworks');

    final allRooms = byRoom.map((k, v) => MapEntry(k, v as int));
    final postedRooms = (postedData['by_room'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v as int));
    final myWorksRooms = (myWorksData['by_room'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v as int));

    return (
      total: total,
      postedRooms: postedRooms,
      myWorksRooms: myWorksRooms,
      allRooms: allRooms,
    );
  }
}

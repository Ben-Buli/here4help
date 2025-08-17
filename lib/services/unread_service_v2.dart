import 'package:flutter/foundation.dart';
import 'package:here4help/chat/services/unified_chat_api_service.dart';

/// 基於角色的未讀訊息服務 (V2)
/// 實作統一聊天系統規格文件標準
/// 使用 UnifiedChatApiService 作為底層 API
class UnreadServiceV2 {
  static const String _tag = '[UnreadServiceV2]';

  /// 獲取分頁未讀數 - 使用統一 API
  /// scope: 'posted', 'myworks', 'all'
  static Future<Map<String, dynamic>> getUnreadByScope({
    String scope = 'all',
  }) async {
    try {
      debugPrint('$_tag 獲取分頁未讀數: scope=$scope');
      return await UnifiedChatApiService.getUnreadCounts(scope: scope);
    } catch (e) {
      debugPrint('❌ $_tag 獲取分頁未讀數失敗: $e');
      rethrow;
    }
  }

  /// 標記聊天室為已讀 - 使用統一 API
  static Future<Map<String, dynamic>> markRoomAsRead(String roomId) async {
    try {
      debugPrint('$_tag 標記聊天室已讀: roomId=$roomId');
      return await UnifiedChatApiService.markRoomAsRead(roomId: roomId);
    } catch (e) {
      debugPrint('❌ $_tag 標記聊天室已讀失敗: $e');
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

  /// 獲取總未讀數 - 使用統一 API
  static Future<int> getTotalUnread() async {
    try {
      debugPrint('$_tag 獲取總未讀數');
      return await UnifiedChatApiService.getTotalUnreadCount();
    } catch (e) {
      debugPrint('❌ $_tag 獲取總未讀數失敗: $e');
      rethrow;
    }
  }

  /// 批量獲取所有未讀數據 - 使用統一 API
  static Future<
      ({
        int total,
        Map<String, int> postedRooms,
        Map<String, int> myWorksRooms,
        Map<String, int> allRooms,
        Map<String, dynamic> consistencyCheck,
      })> getAllUnreadData() async {
    try {
      debugPrint('$_tag 批量獲取所有未讀數據');
      final data = await UnifiedChatApiService.getAllUnreadData();

      final allRooms = (data['by_room'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int));
      final postedData = data['posted'] as Map<String, dynamic>? ?? {};
      final myWorksData = data['myworks'] as Map<String, dynamic>? ?? {};

      final postedRooms = (postedData['by_room'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int));
      final myWorksRooms =
          (myWorksData['by_room'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, v as int));

      return (
        total: data['total_unread'] as int? ?? 0,
        postedRooms: postedRooms,
        myWorksRooms: myWorksRooms,
        allRooms: allRooms,
        consistencyCheck:
            data['consistency_check'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      debugPrint('❌ $_tag 批量獲取未讀數據失敗: $e');
      rethrow;
    }
  }
}

// 此檔案包含 My Works Widget 的實時訊息更新增強邏輯
// 參考 Posted Tasks 的做法實現即時訊息預覽

import 'package:flutter/material.dart';
import 'package:here4help/chat/services/socket_service.dart';

/// My Works 實時訊息更新增強邏輯
class MyWorksRealtimeMessage {
  static const String _tag = '[MyWorksRealtimeMessage]';

  /// 建構實時訊息副標題 Widget
  /// 參考 Posted Tasks 的 _buildRealTimeMessageSubtitle 實現
  static Widget buildRealtimeMessageSubtitle(Map<String, dynamic> task) {
    final roomId = task['chat_room_id']?.toString();
    final initialText = task['latest_message_snippet'] ?? 'No conversation yet';

    if (roomId == null || roomId.isEmpty) {
      return Text(
        initialText,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: SocketService().messagesForRoom(roomId),
      builder: (context, snapshot) {
        String messageText = initialText;

        // 🔧 修復：檢查訊息是否屬於當前房間
        if (snapshot.hasData && snapshot.data != null) {
          final messageData = snapshot.data!;
          final messageRoomId = messageData['roomId']?.toString() ??
              messageData['room_id']?.toString();

          // 只有當訊息確實屬於當前房間時才更新顯示
          if (messageRoomId == roomId) {
            final text = messageData['text']?.toString() ??
                messageData['content']?.toString() ??
                messageData['message']?.toString() ??
                '';
            if (text.isNotEmpty) {
              messageText = text;
              debugPrint('$_tag 更新房間 $roomId 的最新訊息: ${_truncateMessage(text)}');
            }
          }
        }

        return Text(
          messageText,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  /// 截斷長訊息用於調試日誌
  static String _truncateMessage(String message, {int maxLength = 20}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  /// 驗證房間ID的有效性
  static bool isValidRoomId(String? roomId) {
    return roomId != null && roomId.isNotEmpty;
  }

  /// 獲取初始訊息文本
  static String getInitialMessageText(Map<String, dynamic> task) {
    return task['latest_message_snippet']?.toString() ?? 'No conversation yet';
  }
}

/// My Works Widget 的實時訊息 Mixin
/// 使用方法：在 MyWorksWidget 的 State 類中添加 `with MyWorksRealtimeMessageMixin`
mixin MyWorksRealtimeMessageMixin<T extends StatefulWidget> on State<T> {
  /// 建構增強版的聊天對象區塊
  /// 替換原有的 _buildChatPartnerSection 方法
  Widget buildEnhancedChatPartnerSection(Map<String, dynamic> task) {
    final creatorName = task['creator_name'] ?? 'Unknown';
    final creatorAvatar = task['creator_avatar'];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 創建者頭像
          buildAvatarWithFallback(
            creatorAvatar?.toString(),
            creatorName,
            radius: 16,
            fontSize: 12,
          ),
          const SizedBox(width: 8),

          // 對象名稱與實時最新訊息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatorName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // 🆕 使用實時訊息更新
                MyWorksRealtimeMessage.buildRealtimeMessageSubtitle(task),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 建構帶有錯誤回退的頭像（抽象方法，需要子類實現）
  /// 這個方法應該在使用此 Mixin 的類中實現
  Widget buildAvatarWithFallback(
    String? avatarPath,
    String? name, {
    double radius = 16,
    double fontSize = 12,
  });

  /// 檢查任務是否支持實時訊息更新
  bool supportsRealtimeMessages(Map<String, dynamic> task) {
    return MyWorksRealtimeMessage.isValidRoomId(
        task['chat_room_id']?.toString());
  }

  /// 預載入實時訊息連接
  /// 可以在 initState 中調用以提前建立連接
  void preloadRealtimeConnections(List<Map<String, dynamic>> tasks) {
    final roomIds = tasks
        .map((task) => task['chat_room_id']?.toString())
        .where((roomId) => MyWorksRealtimeMessage.isValidRoomId(roomId))
        .toSet();

    for (final roomId in roomIds) {
      // 預先建立連接但不監聽，讓後續的 StreamBuilder 能更快連接
      SocketService().messagesForRoom(roomId!);
    }

    debugPrint('[MyWorksRealtimeMessage] 預載入 ${roomIds.length} 個聊天室連接');
  }
}

/// My Works 訊息更新統計工具
class MyWorksMessageStats {
  static const String _tag = '[MyWorksMessageStats]';

  /// 統計支持實時更新的任務數量
  static int countRealtimeEnabledTasks(List<Map<String, dynamic>> tasks) {
    return tasks
        .where((task) => MyWorksRealtimeMessage.isValidRoomId(
            task['chat_room_id']?.toString()))
        .length;
  }

  /// 打印 My Works 訊息統計信息
  static void printMessageStats(List<Map<String, dynamic>> tasks) {
    final totalTasks = tasks.length;
    final realtimeEnabled = countRealtimeEnabledTasks(tasks);
    final staticOnly = totalTasks - realtimeEnabled;

    debugPrint('$_tag My Works 訊息統計:');
    debugPrint('  - 總任務數: $totalTasks');
    debugPrint('  - 支持實時更新: $realtimeEnabled');
    debugPrint('  - 僅靜態訊息: $staticOnly');
    debugPrint(
        '  - 實時更新覆蓋率: ${totalTasks > 0 ? (realtimeEnabled / totalTasks * 100).toStringAsFixed(1) : 0}%');
  }

  /// 驗證訊息數據的完整性
  static Map<String, dynamic> validateMessageData(
      List<Map<String, dynamic>> tasks) {
    int tasksWithoutRoomId = 0;
    int tasksWithoutMessage = 0;
    final List<String> problematicTasks = [];

    for (final task in tasks) {
      final taskId = task['id']?.toString() ?? 'unknown';
      final roomId = task['chat_room_id']?.toString();
      final messageSnippet = task['latest_message_snippet']?.toString();

      if (roomId == null || roomId.isEmpty) {
        tasksWithoutRoomId++;
        problematicTasks.add('$taskId (無房間ID)');
      }

      if (messageSnippet == null || messageSnippet.isEmpty) {
        tasksWithoutMessage++;
      }
    }

    final result = {
      'total_tasks': tasks.length,
      'tasks_without_room_id': tasksWithoutRoomId,
      'tasks_without_message': tasksWithoutMessage,
      'problematic_tasks': problematicTasks,
      'health_score': tasks.isEmpty
          ? 1.0
          : (tasks.length - tasksWithoutRoomId) / tasks.length,
    };

    debugPrint('$_tag 數據完整性檢查: $result');
    return result;
  }
}

/// Socket 連接狀態監控器
/// 用於監控和優化 My Works 的實時訊息連接
class MyWorksSocketMonitor {
  static const String _tag = '[MyWorksSocketMonitor]';
  static final Set<String> _monitoredRooms = <String>{};
  static int _activeConnections = 0;

  /// 註冊房間監控
  static void registerRoom(String roomId) {
    if (_monitoredRooms.add(roomId)) {
      _activeConnections++;
      debugPrint('$_tag 註冊房間監控: $roomId (活躍連接: $_activeConnections)');
    }
  }

  /// 取消房間監控
  static void unregisterRoom(String roomId) {
    if (_monitoredRooms.remove(roomId)) {
      _activeConnections--;
      debugPrint('$_tag 取消房間監控: $roomId (活躍連接: $_activeConnections)');
    }
  }

  /// 清除所有監控
  static void clearAll() {
    final count = _monitoredRooms.length;
    _monitoredRooms.clear();
    _activeConnections = 0;
    debugPrint('$_tag 清除所有房間監控 ($count 個)');
  }

  /// 獲取監控統計
  static Map<String, dynamic> getStats() {
    return {
      'monitored_rooms': _monitoredRooms.length,
      'active_connections': _activeConnections,
      'room_ids': _monitoredRooms.toList(),
    };
  }

  /// 檢查連接健康狀態
  static bool isHealthy() {
    // 檢查連接數是否合理（不應該過多）
    const maxConnections = 50;
    return _activeConnections <= maxConnections;
  }
}

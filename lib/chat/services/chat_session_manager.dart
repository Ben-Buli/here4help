import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 聊天室會話管理器 - 管理當前聊天室狀態
class ChatSessionManager {
  static const String _currentChatKey = 'current_chat_room_session';

  /// 保存當前聊天室會話信息
  static Future<void> setCurrentChatSession({
    required String roomId,
    required Map<String, dynamic> room,
    required Map<String, dynamic> task,
    required String userRole,
    required Map<String, dynamic> chatPartnerInfo,
    String? sourceTab, // 來源分頁 ('posted-tasks' 或 'my-works')
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionData = {
        'roomId': roomId,
        'room': room,
        'task': task,
        'userRole': userRole,
        'chatPartnerInfo': chatPartnerInfo,
        'sourceTab': sourceTab, // 記錄來源分頁
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final jsonString = jsonEncode(sessionData);
      await prefs.setString(_currentChatKey, jsonString);

      debugPrint('🔄 ChatSessionManager: 已保存當前聊天室會話');
      debugPrint('🔄 roomId: $roomId');
      debugPrint('🔄 userRole: $userRole');
    } catch (e) {
      debugPrint('❌ ChatSessionManager: 保存會話失敗: $e');
    }
  }

  /// 獲取當前聊天室會話信息
  static Future<Map<String, dynamic>?> getCurrentChatSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_currentChatKey);

      if (jsonString == null) {
        debugPrint('🔄 ChatSessionManager: 無當前聊天室會話');
        return null;
      }

      final sessionData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 檢查會話是否過期（1小時）
      final timestamp = sessionData['timestamp'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneHour = 60 * 60 * 1000; // 1小時的毫秒數

      if (now - timestamp > oneHour) {
        debugPrint('🔄 ChatSessionManager: 會話已過期，清除');
        await clearCurrentChatSession();
        return null;
      }

      debugPrint('🔄 ChatSessionManager: 找到有效的聊天室會話');
      debugPrint('🔄 roomId: ${sessionData['roomId']}');
      debugPrint('🔄 userRole: ${sessionData['userRole']}');

      return sessionData;
    } catch (e) {
      debugPrint('❌ ChatSessionManager: 獲取會話失敗: $e');
      return null;
    }
  }

  /// 清除當前聊天室會話
  static Future<void> clearCurrentChatSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentChatKey);
      debugPrint('🔄 ChatSessionManager: 已清除當前聊天室會話');
    } catch (e) {
      debugPrint('❌ ChatSessionManager: 清除會話失敗: $e');
    }
  }

  /// 檢查是否為當前聊天室
  static Future<bool> isCurrentChatRoom(String roomId) async {
    final session = await getCurrentChatSession();
    return session?['roomId'] == roomId;
  }

  /// 檢查當前是否在聊天室中
  static Future<bool> isInChatRoom() async {
    final session = await getCurrentChatSession();
    return session != null;
  }

  /// 獲取返回路徑
  static Future<String> getReturnPath() async {
    final session = await getCurrentChatSession();
    final sourceTab = session?['sourceTab'] as String?;

    switch (sourceTab) {
      case 'posted-tasks':
        return '/chat/posted-tasks';
      case 'my-works':
        return '/chat/my-works';
      default:
        return '/chat';
    }
  }
}

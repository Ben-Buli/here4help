import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 聊天室會話管理器 - 管理當前聊天室狀態
class ChatSessionManager {
  static const String _currentChatKey = 'current_chat_room_session';

  /// 保存當前聊天室會話
  static Future<void> saveCurrentChatSession(
      Map<String, dynamic> chatData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomId = chatData['room']?['id']?.toString() ??
          chatData['room']?['roomId']?.toString();
      final userRole = chatData['userRole']?.toString() ?? '';

      if (kDebugMode) {
        debugPrint('🔄 ChatSessionManager: 已保存當前聊天室會話');
        debugPrint('🔄 roomId: $roomId');
        debugPrint('🔄 userRole: $userRole');
      }

      // 保存會話數據
      await prefs.setString('current_chat_session', jsonEncode(chatData));
      await prefs.setString('current_chat_session_timestamp',
          DateTime.now().millisecondsSinceEpoch.toString());
    } catch (e) {
      debugPrint('❌ 保存聊天室會話失敗: $e');
    }
  }

  /// 獲取當前聊天室會話
  static Future<Map<String, dynamic>?> getCurrentChatSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionDataStr = prefs.getString('current_chat_session');
      final timestampStr = prefs.getString('current_chat_session_timestamp');

      if (sessionDataStr == null || timestampStr == null) {
        if (kDebugMode) {
          debugPrint('🔄 ChatSessionManager: 無當前聊天室會話');
        }
        return null;
      }

      final timestamp = int.tryParse(timestampStr) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionAge = now - timestamp;

      // 會話過期時間：30 分鐘
      if (sessionAge > 30 * 60 * 1000) {
        await clearCurrentChatSession();
        if (kDebugMode) {
          debugPrint('🔄 ChatSessionManager: 會話已過期，清除');
        }
        return null;
      }

      final sessionData = jsonDecode(sessionDataStr) as Map<String, dynamic>;
      if (kDebugMode) {
        debugPrint('🔄 ChatSessionManager: 找到有效的聊天室會話');
        debugPrint('🔄 roomId: ${sessionData['roomId']}');
        debugPrint('🔄 userRole: ${sessionData['userRole']}');
      }
      return sessionData;
    } catch (e) {
      debugPrint('❌ 獲取聊天室會話失敗: $e');
      return null;
    }
  }

  /// 清除當前聊天室會話
  static Future<void> clearCurrentChatSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_chat_session');
      await prefs.remove('current_chat_session_timestamp');
      if (kDebugMode) {
        debugPrint('🔄 ChatSessionManager: 已清除當前聊天室會話');
      }
    } catch (e) {
      debugPrint('❌ 清除聊天室會話失敗: $e');
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

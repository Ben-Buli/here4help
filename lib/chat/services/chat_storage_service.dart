import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatStorageService {
  static String _key(String roomId) => 'chat_room_$roomId';

  static Future<void> savechatRoomData({
    required String roomId,
    required Map<String, dynamic> room,
    required Map<String, dynamic> task,
    String? userRole,
    Map<String, dynamic>? chatPartnerInfo,
    String? sourceTab,
    String? returnPath,
  }) async {
    debugPrint('🔍 保存聊天室數據: roomId=$roomId');
    debugPrint('🔍 room: $room');
    debugPrint('🔍 task: $task');
    debugPrint('🔍 userRole: $userRole');
    debugPrint('🔍 chatPartnerInfo: $chatPartnerInfo');

    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'room': room,
      'task': task,
      if (userRole != null) 'userRole': userRole,
      if (chatPartnerInfo != null) 'chatPartnerInfo': chatPartnerInfo,
      if (sourceTab != null) 'sourceTab': sourceTab,
      if (returnPath != null) 'returnPath': returnPath,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    debugPrint('🔍 保存的完整數據: $payload');
    await prefs.setString(_key(roomId), jsonEncode(payload));
    debugPrint('✅ 聊天室數據保存完成');
  }

  static Future<Map<String, dynamic>?> getChatRoomData(String roomId) async {
    debugPrint('🔍 嘗試讀取聊天室數據: roomId=$roomId');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(roomId));

    if (raw == null) {
      debugPrint('❌ 本地儲存中沒有找到數據');
      return null;
    }

    debugPrint('🔍 找到原始數據: $raw');

    try {
      final decoded = jsonDecode(raw);
      debugPrint('🔍 解碼後的數據: $decoded');
      if (decoded is Map<String, dynamic>) {
        debugPrint('✅ 成功讀取聊天室數據');
        return decoded;
      }
    } catch (e) {
      debugPrint('❌ 解碼數據失敗: $e');
    }
    return null;
  }

  static Future<void> clearChatRoomData(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(roomId));
  }

  static String generateChatUrl({required String roomId, String? taskId}) {
    final params = {'roomId': roomId, if (taskId != null) 'taskId': taskId};
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '/chat/detail?$query';
  }

  static String? extractRoomIdFromUrl(String url) {
    debugPrint('🔍 從 URL 提取 roomId: $url');

    try {
      final uri = Uri.parse(url);
      debugPrint('🔍 解析後的 URI: $uri');
      debugPrint('🔍 URI path: ${uri.path}');
      debugPrint('🔍 URI query: ${uri.query}');
      debugPrint('🔍 URI fragment: ${uri.fragment}');

      // 1) 普通情況（非 hash 路由）- 優先檢查 room_id（新格式）
      String? roomId = uri.queryParameters['room_id'];
      debugPrint('🔍 從 queryParameters 提取的 room_id: $roomId');
      if (roomId != null) {
        debugPrint('✅ 成功提取 room_id (新格式): $roomId');
        return roomId;
      }

      // 2) 檢查舊格式 roomId（向後相容）
      roomId = uri.queryParameters['roomId'];
      debugPrint('🔍 從 queryParameters 提取的 roomId (舊格式): $roomId');
      if (roomId != null) {
        debugPrint('✅ 成功提取 roomId (舊格式): $roomId');
        return roomId;
      }

      // 3) Flutter Web 預設 hash 路由：參數在 fragment 裡
      final frag = uri.fragment; // 例如: "/chat/detail?room_id=123&taskId=..."
      debugPrint('🔍 fragment: $frag');

      if (frag.isNotEmpty) {
        final fragUri = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
        debugPrint('🔍 解析後的 fragment URI: $fragUri');
        debugPrint(
            '🔍 fragment URI queryParameters: ${fragUri.queryParameters}');

        // 優先檢查 room_id（新格式）
        roomId = fragUri.queryParameters['room_id'];
        debugPrint('🔍 從 fragment 提取的 room_id (新格式): $roomId');
        if (roomId != null) {
          debugPrint('✅ 成功提取 room_id (hash 路由): $roomId');
          return roomId;
        }

        // 檢查舊格式 roomId（向後相容）
        roomId = fragUri.queryParameters['roomId'];
        debugPrint('🔍 從 fragment 提取的 roomId (舊格式): $roomId');
        if (roomId != null) {
          debugPrint('✅ 成功提取 roomId (hash 路由): $roomId');
          return roomId;
        }
      }
    } catch (e) {
      debugPrint('❌ 解析 URL 失敗: $e');
    }

    debugPrint('❌ 無法從 URL 提取 roomId');
    return null;
  }
}

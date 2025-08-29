import 'package:flutter/material.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';

/// 聊天數據預載入服務
/// 在用戶點擊聊天項目前就開始載入數據，提升用戶體驗
class ChatPreloadService {
  static final ChatPreloadService _instance = ChatPreloadService._internal();
  factory ChatPreloadService() => _instance;
  ChatPreloadService._internal();

  // 預載入的數據快取
  final Map<String, Map<String, dynamic>> _preloadedData = {};

  // 正在載入的房間ID集合
  final Set<String> _loadingRooms = {};

  /// 預載入聊天室數據
  static Future<void> preloadChatData(String roomId) async {
    if (_instance._loadingRooms.contains(roomId)) {
      debugPrint('⏳ [ChatPreloadService] 房間 $roomId 正在載入中，跳過重複載入');
      return;
    }

    if (_instance._preloadedData.containsKey(roomId)) {
      debugPrint('✅ [ChatPreloadService] 房間 $roomId 數據已預載入');
      return;
    }

    try {
      debugPrint('🚀 [ChatPreloadService] 開始預載入房間 $roomId 的數據');
      _instance._loadingRooms.add(roomId);

      final chatService = ChatService();
      final chatData = await chatService.getChatDetailData(roomId: roomId);

      if (chatData.isNotEmpty) {
        _instance._preloadedData[roomId] = chatData;
        debugPrint('✅ [ChatPreloadService] 房間 $roomId 數據預載入成功');
      } else {
        debugPrint('❌ [ChatPreloadService] 房間 $roomId 數據預載入失敗');
      }
    } catch (e) {
      debugPrint('❌ [ChatPreloadService] 房間 $roomId 數據預載入錯誤: $e');
    } finally {
      _instance._loadingRooms.remove(roomId);
    }
  }

  /// 批量預載入聊天室數據
  static Future<void> preloadMultipleChatData(List<String> roomIds) async {
    debugPrint('🚀 [ChatPreloadService] 開始批量預載入 ${roomIds.length} 個房間的數據');

    // 並行載入，但限制並發數
    const maxConcurrent = 3;
    final chunks = <List<String>>[];

    for (int i = 0; i < roomIds.length; i += maxConcurrent) {
      chunks.add(roomIds.skip(i).take(maxConcurrent).toList());
    }

    for (final chunk in chunks) {
      await Future.wait(
        chunk.map((roomId) => preloadChatData(roomId)),
      );
    }

    debugPrint('✅ [ChatPreloadService] 批量預載入完成');
  }

  /// 獲取預載入的數據
  static Map<String, dynamic>? getPreloadedData(String roomId) {
    final data = _instance._preloadedData[roomId];
    if (data != null) {
      debugPrint('✅ [ChatPreloadService] 使用預載入數據: $roomId');
      // 使用後移除，避免記憶體洩漏
      _instance._preloadedData.remove(roomId);
    }
    return data;
  }

  /// 檢查是否有預載入的數據
  static bool hasPreloadedData(String roomId) {
    return _instance._preloadedData.containsKey(roomId);
  }

  /// 檢查是否正在載入
  static bool isLoading(String roomId) {
    return _instance._loadingRooms.contains(roomId);
  }

  /// 清除預載入的數據
  static void clearPreloadedData([String? roomId]) {
    if (roomId != null) {
      _instance._preloadedData.remove(roomId);
      debugPrint('🗑️ [ChatPreloadService] 清除房間 $roomId 的預載入數據');
    } else {
      _instance._preloadedData.clear();
      debugPrint('🗑️ [ChatPreloadService] 清除所有預載入數據');
    }
  }

  /// 獲取預載入統計信息
  static Map<String, dynamic> getStats() {
    return {
      'preloadedCount': _instance._preloadedData.length,
      'loadingCount': _instance._loadingRooms.length,
      'preloadedRooms': _instance._preloadedData.keys.toList(),
      'loadingRooms': _instance._loadingRooms.toList(),
    };
  }
}

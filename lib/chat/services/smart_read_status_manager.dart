import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/services/unified_unread_manager.dart';

/// 智能已讀狀態管理器
/// 解決從聊天室返回時全局更新的問題，實現精確的單房間已讀狀態控制
class SmartReadStatusManager {
  static SmartReadStatusManager? _instance;
  static SmartReadStatusManager get instance =>
      _instance ??= SmartReadStatusManager._();

  SmartReadStatusManager._();

  // 記錄當前處於活躍狀態的聊天室
  String? _activeRoomId;

  // 待處理的已讀標記隊列（避免頻繁 API 調用）
  final Map<String, int> _pendingReadMarks = {};

  // 已讀標記的防抖計時器
  Timer? _markReadDebounceTimer;
  static const Duration _markReadDelay = Duration(milliseconds: 1500);

  // 記錄最近標記為已讀的房間，避免重複處理
  final Set<String> _recentlyMarkedRooms = {};
  Timer? _recentlyMarkedCleanupTimer;

  /// 設置當前活躍的聊天室
  void setActiveRoom(String? roomId) {
    if (_activeRoomId == roomId) return;

    final previous = _activeRoomId;
    _activeRoomId = roomId;

    debugPrint('🎯 [SmartReadStatusManager] 活躍聊天室變化: $previous -> $roomId');

    // 如果離開了聊天室，處理待處理的已讀標記
    if (previous != null && roomId != previous) {
      _processPendingReadMark(previous);
    }
  }

  /// 標記房間中的訊息為已讀（智能版本）
  /// [roomId] 聊天室 ID
  /// [upToMessageId] 已讀到的訊息 ID
  /// [immediate] 是否立即執行（預設為 false，使用防抖）
  void markRoomRead({
    required String roomId,
    int? upToMessageId,
    bool immediate = false,
  }) {
    // 防重複處理
    if (_recentlyMarkedRooms.contains(roomId)) {
      debugPrint('⏭️ [SmartReadStatusManager] 房間 $roomId 最近已標記，跳過重複操作');
      return;
    }

    debugPrint(
        '📖 [SmartReadStatusManager] 準備標記房間 $roomId 為已讀 (immediate: $immediate)');

    if (immediate) {
      _executeMarkRoomRead(roomId, upToMessageId);
    } else {
      // 加入待處理隊列
      _pendingReadMarks[roomId] = upToMessageId ?? 0;
      _scheduleMarkRead();
    }
  }

  /// 調度已讀標記處理
  void _scheduleMarkRead() {
    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = Timer(_markReadDelay, () {
      _processPendingReadMarks();
    });
  }

  /// 處理所有待處理的已讀標記
  void _processPendingReadMarks() {
    if (_pendingReadMarks.isEmpty) return;

    debugPrint(
        '⚡ [SmartReadStatusManager] 處理 ${_pendingReadMarks.length} 個待處理的已讀標記');

    final roomsToProcess = Map<String, int>.from(_pendingReadMarks);
    _pendingReadMarks.clear();

    for (final entry in roomsToProcess.entries) {
      _executeMarkRoomRead(entry.key, entry.value > 0 ? entry.value : null);
    }
  }

  /// 處理特定房間的待處理已讀標記
  void _processPendingReadMark(String roomId) {
    final messageId = _pendingReadMarks.remove(roomId);
    if (messageId != null) {
      debugPrint('📤 [SmartReadStatusManager] 處理房間 $roomId 的待處理已讀標記');
      _executeMarkRoomRead(roomId, messageId > 0 ? messageId : null);
    }
  }

  /// 執行已讀標記（實際 API 調用）
  void _executeMarkRoomRead(String roomId, int? upToMessageId) async {
    try {
      debugPrint('🚀 [SmartReadStatusManager] 執行房間 $roomId 已讀標記 API 調用');

      // 添加到最近標記列表，防止重複處理
      _recentlyMarkedRooms.add(roomId);
      _scheduleRecentlyMarkedCleanup();

      // 調用 API
      await NotificationCenter().service.markRoomRead(
            roomId: roomId,
            upToMessageId: upToMessageId?.toString() ?? '',
          );

      // 局部更新未讀狀態（只影響此房間）
      UnifiedUnreadManager.instance.updateRoomUnread(roomId, 0);

      debugPrint('✅ [SmartReadStatusManager] 房間 $roomId 已讀標記完成');

      // 注意：不調用全局 refreshSnapshot()，避免影響其他房間
    } catch (e) {
      debugPrint('❌ [SmartReadStatusManager] 房間 $roomId 已讀標記失敗: $e');

      // 失敗時從最近標記列表中移除，允許重試
      _recentlyMarkedRooms.remove(roomId);
    }
  }

  /// 清理最近標記的房間記錄
  void _scheduleRecentlyMarkedCleanup() {
    _recentlyMarkedCleanupTimer?.cancel();
    _recentlyMarkedCleanupTimer = Timer(const Duration(seconds: 30), () {
      _recentlyMarkedRooms.clear();
      debugPrint('🧹 [SmartReadStatusManager] 已清理最近標記房間記錄');
    });
  }

  /// 檢查房間是否為當前活躍房間
  bool isActiveRoom(String roomId) => _activeRoomId == roomId;

  /// 獲取當前活躍房間
  String? get activeRoomId => _activeRoomId;

  /// 強制處理所有待處理的已讀標記（用於應用退出時）
  void flushPendingReadMarks() {
    _markReadDebounceTimer?.cancel();
    _processPendingReadMarks();
  }

  /// 清理資源
  void dispose() {
    _markReadDebounceTimer?.cancel();
    _recentlyMarkedCleanupTimer?.cancel();
    _pendingReadMarks.clear();
    _recentlyMarkedRooms.clear();
  }
}

/// 智能已讀狀態管理 Mixin
/// 用於聊天相關頁面的智能已讀處理
mixin SmartReadStatusMixin<T extends StatefulWidget> on State<T> {
  SmartReadStatusManager get _readStatusManager =>
      SmartReadStatusManager.instance;

  /// 進入聊天室時調用
  void onEnterChatRoom(String roomId) {
    _readStatusManager.setActiveRoom(roomId);
    debugPrint('🚪 [SmartReadStatusMixin] 進入聊天室: $roomId');
  }

  /// 離開聊天室時調用
  void onLeaveChatRoom() {
    final currentRoom = _readStatusManager.activeRoomId;
    _readStatusManager.setActiveRoom(null);
    debugPrint('🚪 [SmartReadStatusMixin] 離開聊天室: $currentRoom');
  }

  /// 標記當前房間訊息為已讀
  void markCurrentRoomRead({int? upToMessageId}) {
    final activeRoom = _readStatusManager.activeRoomId;
    if (activeRoom != null) {
      _readStatusManager.markRoomRead(
        roomId: activeRoom,
        upToMessageId: upToMessageId,
      );
    }
  }

  /// 檢查是否為當前活躍房間
  bool isCurrentActiveRoom(String roomId) {
    return _readStatusManager.isActiveRoom(roomId);
  }
}

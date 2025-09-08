import 'dart:async';
import 'package:flutter/foundation.dart';

/// 統一未讀狀態管理器 - 作為所有未讀狀態的單一真實來源
class UnifiedUnreadManager extends ChangeNotifier {
  static UnifiedUnreadManager? _instance;
  static UnifiedUnreadManager get instance =>
      _instance ??= UnifiedUnreadManager._();

  UnifiedUnreadManager._();

  // 原始未讀數據（來自後端）
  final Map<String, int> _rawUnreadByRoom = {};

  // 分頁級別的未讀狀態
  final Map<String, bool> _tabUnreadStatus = {};

  // 防抖計時器（統一管理）
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  // 房間到分頁的映射關係
  final Map<String, Set<String>> _roomToTabs = {};

  /// 註冊房間到分頁的映射關係
  void registerRoomToTab(String roomId, String tabKey) {
    _roomToTabs.putIfAbsent(roomId, () => <String>{}).add(tabKey);
  }

  /// 批量更新未讀數據（來自 NotificationCenter）
  void updateUnreadSnapshot(Map<String, int> snapshot) {
    debugPrint('📊 [UnifiedUnreadManager] 收到未讀數據快照: ${snapshot.length} 個房間');

    // 檢查是否有實際變化
    bool hasChanges = false;
    for (final entry in snapshot.entries) {
      if (_rawUnreadByRoom[entry.key] != entry.value) {
        hasChanges = true;
        break;
      }
    }

    if (!hasChanges) {
      debugPrint('⏭️ [UnifiedUnreadManager] 快照無變化，跳過更新');
      return;
    }

    // 更新原始數據
    _rawUnreadByRoom.clear();
    _rawUnreadByRoom.addAll(
        Map.fromEntries(snapshot.entries.where((entry) => entry.value > 0)));

    // 使用統一防抖機制
    _scheduleUpdate();
  }

  /// 更新單個房間的未讀數
  void updateRoomUnread(String roomId, int count) {
    final safeCount = count.clamp(0, 999);
    final previous = _rawUnreadByRoom[roomId] ?? 0;

    if (previous == safeCount) return;

    if (safeCount == 0) {
      _rawUnreadByRoom.remove(roomId);
    } else {
      _rawUnreadByRoom[roomId] = safeCount;
    }

    debugPrint(
        '🔄 [UnifiedUnreadManager] 房間 $roomId 未讀數: $previous -> $safeCount');
    _scheduleUpdate();
  }

  /// 統一的防抖更新調度
  void _scheduleUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _calculateTabUnreadStatus();
      notifyListeners();
    });
  }

  /// 計算各分頁的未讀狀態
  void _calculateTabUnreadStatus() {
    // Posted Tasks 分頁未讀狀態
    final postedTasksUnread = _calculateTabUnread('posted_tasks');
    _updateTabStatus('posted_tasks', postedTasksUnread);

    // My Works 分頁未讀狀態
    final myWorksUnread = _calculateTabUnread('my_works');
    _updateTabStatus('my_works', myWorksUnread);

    debugPrint('📊 [UnifiedUnreadManager] 分頁未讀狀態更新完成');
    debugPrint('  - Posted Tasks: $postedTasksUnread');
    debugPrint('  - My Works: $myWorksUnread');
  }

  /// 計算特定分頁的未讀狀態
  bool _calculateTabUnread(String tabKey) {
    // 這裡需要根據實際的房間歸屬邏輯來計算
    // 暫時返回是否有任何未讀房間
    return _rawUnreadByRoom.values.any((count) => count > 0);
  }

  /// 更新分頁狀態
  void _updateTabStatus(String tabKey, bool hasUnread) {
    final previous = _tabUnreadStatus[tabKey] ?? false;
    if (previous != hasUnread) {
      _tabUnreadStatus[tabKey] = hasUnread;
      debugPrint(
          '✅ [UnifiedUnreadManager] 分頁 $tabKey 未讀狀態: $previous -> $hasUnread');
    }
  }

  // === 對外 API ===

  /// 獲取房間的未讀數
  int getUnreadForRoom(String roomId) => _rawUnreadByRoom[roomId] ?? 0;

  /// 獲取所有未讀數據
  Map<String, int> get allUnreadByRoom => Map.unmodifiable(_rawUnreadByRoom);

  /// 獲取總未讀數（底部導航使用）
  int get totalUnreadCount =>
      _rawUnreadByRoom.values.fold(0, (sum, count) => sum + count);

  /// 獲取分頁未讀狀態
  bool getTabUnreadStatus(String tabKey) => _tabUnreadStatus[tabKey] ?? false;

  /// 底部導航是否顯示紅點
  bool get shouldShowNavigationBadge => totalUnreadCount > 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

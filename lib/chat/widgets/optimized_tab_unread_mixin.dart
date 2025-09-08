import 'package:flutter/material.dart';
import 'package:here4help/chat/services/unified_unread_manager.dart';

/// 優化的分頁未讀狀態管理 Mixin
/// 替換現有各分頁中複雜的未讀狀態管理邏輯
mixin OptimizedTabUnreadMixin<T extends StatefulWidget> on State<T> {
  late final String _tabKey;
  late final UnifiedUnreadManager _unreadManager;

  bool _hasRegisteredListener = false;

  /// 初始化分頁未讀管理器
  /// [tabKey] 分頁標識符，如 'posted_tasks' 或 'my_works'
  void initializeTabUnreadManager(String tabKey) {
    _tabKey = tabKey;
    _unreadManager = UnifiedUnreadManager.instance;

    // 註冊監聽器（避免重複註冊）
    if (!_hasRegisteredListener) {
      _unreadManager.addListener(_handleUnreadUpdate);
      _hasRegisteredListener = true;

      debugPrint('✅ [OptimizedTabUnreadMixin] 已為分頁 $_tabKey 註冊未讀監聽器');
    }
  }

  /// 處理未讀狀態更新
  void _handleUnreadUpdate() {
    if (!mounted) return;

    final hasUnread = _unreadManager.getTabUnreadStatus(_tabKey);
    debugPrint('🔄 [OptimizedTabUnreadMixin] 分頁 $_tabKey 未讀狀態更新: $hasUnread');

    // 子類可以重寫此方法來處理特定邏輯
    onTabUnreadChanged(hasUnread);
  }

  /// 子類重寫此方法來處理未讀狀態變化
  void onTabUnreadChanged(bool hasUnread) {
    // 預設實作：觸發 setState 重建 UI
    if (mounted) {
      setState(() {
        // UI 會自動通過 Consumer 或直接讀取 UnifiedUnreadManager 來更新
      });
    }
  }

  /// 註冊房間到分頁的映射關係
  void registerRoomToTab(String roomId) {
    _unreadManager.registerRoomToTab(roomId, _tabKey);
    debugPrint('🔗 [OptimizedTabUnreadMixin] 註冊房間 $roomId 到分頁 $_tabKey');
  }

  /// 批量註冊房間
  void registerRoomsToTab(List<String> roomIds) {
    for (final roomId in roomIds) {
      if (roomId.isNotEmpty) {
        registerRoomToTab(roomId);
      }
    }
  }

  /// 獲取指定房間的未讀數
  int getUnreadForRoom(String roomId) {
    return _unreadManager.getUnreadForRoom(roomId);
  }

  /// 獲取當前分頁是否有未讀
  bool get hasTabUnread => _unreadManager.getTabUnreadStatus(_tabKey);

  /// 清理資源
  void disposeTabUnreadManager() {
    if (_hasRegisteredListener) {
      _unreadManager.removeListener(_handleUnreadUpdate);
      _hasRegisteredListener = false;

      debugPrint('✅ [OptimizedTabUnreadMixin] 已為分頁 $_tabKey 移除未讀監聽器');
    }
  }

  @override
  void dispose() {
    disposeTabUnreadManager();
    super.dispose();
  }
}

/// 用於分頁未讀狀態的便利 Widget
class TabUnreadConsumer extends StatelessWidget {
  const TabUnreadConsumer({
    super.key,
    required this.tabKey,
    required this.builder,
  });

  final String tabKey;
  final Widget Function(BuildContext context, bool hasUnread) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UnifiedUnreadManager.instance,
      builder: (context, child) {
        final hasUnread =
            UnifiedUnreadManager.instance.getTabUnreadStatus(tabKey);
        return builder(context, hasUnread);
      },
    );
  }
}

/// 用於房間級未讀數的便利 Widget
class RoomUnreadConsumer extends StatelessWidget {
  const RoomUnreadConsumer({
    super.key,
    required this.roomId,
    required this.builder,
  });

  final String roomId;
  final Widget Function(BuildContext context, int unreadCount) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UnifiedUnreadManager.instance,
      builder: (context, child) {
        final unreadCount =
            UnifiedUnreadManager.instance.getUnreadForRoom(roomId);
        return builder(context, unreadCount);
      },
    );
  }
}

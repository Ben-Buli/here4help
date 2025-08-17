import 'package:flutter/widgets.dart';

/// 智能刷新策略 - 遵循聊天系統規格文件標準
///
/// 實現規格文件的更新策略：
/// - condition_based: 只有搜尋/篩選/排序變化時刷新
/// - delayed: addPostFrameCallback 避免 build 重刷
/// - state_check: 更新前檢查 Provider 狀態是否變動
class SmartRefreshStrategy {
  static const String _tag = '[SmartRefreshStrategy]';

  /// 刷新條件檢查器
  static bool shouldRefresh({
    required bool hasActiveFilters,
    required String searchQuery,
    required bool isUnreadUpdate,
    bool forceRefresh = false,
  }) {
    debugPrint('$_tag 檢查刷新條件:');
    debugPrint('  - hasActiveFilters: $hasActiveFilters');
    debugPrint('  - searchQuery: "$searchQuery"');
    debugPrint('  - isUnreadUpdate: $isUnreadUpdate');
    debugPrint('  - forceRefresh: $forceRefresh');

    // 強制刷新
    if (forceRefresh) {
      debugPrint('✅ $_tag 強制刷新');
      return true;
    }

    // 未讀狀態更新不觸發列表刷新
    if (isUnreadUpdate) {
      debugPrint('🔄 $_tag 僅未讀狀態更新，跳過列表刷新');
      return false;
    }

    // 任何篩選條件變化都需要刷新（包括清除篩選）
    if (hasActiveFilters || searchQuery.isNotEmpty) {
      debugPrint('✅ $_tag 有 active filters 或搜尋條件，需要刷新');
      return true;
    }

    // 即使沒有篩選條件，也需要刷新來顯示所有數據
    debugPrint('✅ $_tag 無篩選條件，刷新顯示所有數據');
    return true;
  }

  /// 延遲刷新執行器 - 避免 build 期間刷新
  static void executeDelayedRefresh(VoidCallback refreshCallback) {
    debugPrint('$_tag 延遲執行刷新');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('$_tag 執行延遲刷新回調');
      refreshCallback();
    });
  }

  /// 狀態變化檢查器 - 防止重複更新
  static bool hasStateChanged({
    required dynamic oldValue,
    required dynamic newValue,
    String? description,
  }) {
    final hasChanged = oldValue != newValue;

    if (description != null) {
      debugPrint('$_tag 狀態變化檢查 [$description]:');
      debugPrint('  - oldValue: $oldValue');
      debugPrint('  - newValue: $newValue');
      debugPrint('  - hasChanged: $hasChanged');
    }

    return hasChanged;
  }

  /// 防抖刷新執行器 - 防止快速連續刷新
  static final Map<String, DateTime> _lastRefreshTimes = {};
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  static bool shouldAllowRefresh(String key) {
    final now = DateTime.now();
    final lastRefresh = _lastRefreshTimes[key];

    if (lastRefresh == null) {
      _lastRefreshTimes[key] = now;
      debugPrint('$_tag 首次刷新，允許執行: $key');
      return true;
    }

    final timeDiff = now.difference(lastRefresh);
    if (timeDiff >= _debounceDelay) {
      _lastRefreshTimes[key] = now;
      debugPrint('$_tag 防抖檢查通過，允許刷新: $key (延遲: ${timeDiff.inMilliseconds}ms)');
      return true;
    }

    debugPrint(
        '$_tag 防抖檢查未通過，跳過刷新: $key (延遲: ${timeDiff.inMilliseconds}ms < ${_debounceDelay.inMilliseconds}ms)');
    return false;
  }

  /// 清理防抖記錄
  static void clearDebounceHistory([String? key]) {
    if (key != null) {
      _lastRefreshTimes.remove(key);
      debugPrint('$_tag 清理防抖記錄: $key');
    } else {
      _lastRefreshTimes.clear();
      debugPrint('$_tag 清理所有防抖記錄');
    }
  }

  /// 綜合刷新決策器 - 整合所有策略
  static void executeSmartRefresh({
    required String refreshKey,
    required VoidCallback refreshCallback,
    required bool hasActiveFilters,
    required String searchQuery,
    bool isUnreadUpdate = false,
    bool forceRefresh = false,
    bool enableDebounce = true,
  }) {
    debugPrint('$_tag 執行智能刷新決策: $refreshKey');

    // 1. 檢查刷新條件
    if (!shouldRefresh(
      hasActiveFilters: hasActiveFilters,
      searchQuery: searchQuery,
      isUnreadUpdate: isUnreadUpdate,
      forceRefresh: forceRefresh,
    )) {
      return;
    }

    // 2. 防抖檢查
    if (enableDebounce && !shouldAllowRefresh(refreshKey)) {
      return;
    }

    // 3. 延遲執行
    executeDelayedRefresh(refreshCallback);
  }

  /// 智能未讀狀態更新器 - 防止無限循環
  static void updateUnreadState({
    required String componentKey,
    required bool oldState,
    required bool newState,
    required VoidCallback updateCallback,
    String? description,
  }) {
    debugPrint('$_tag 智能未讀狀態更新: $componentKey');

    if (!hasStateChanged(
      oldValue: oldState,
      newValue: newState,
      description: description ?? componentKey,
    )) {
      debugPrint('$_tag 未讀狀態未變化，跳過更新');
      return;
    }

    debugPrint('$_tag 執行未讀狀態更新');
    updateCallback();
  }
}

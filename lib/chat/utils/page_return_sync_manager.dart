import 'package:flutter/widgets.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';

/// 頁面返回同步管理器
/// 監聽從 ChatDetailPage 返回到 ChatListPage 的事件，確保數據同步
class PageReturnSyncManager {
  static const String _tag = '[PageReturnSyncManager]';
  static PageReturnSyncManager? _instance;
  static PageReturnSyncManager get instance =>
      _instance ??= PageReturnSyncManager._();

  PageReturnSyncManager._();

  // 記錄待同步的任務信息
  final Map<String, Map<String, dynamic>> _pendingSyncTasks = {};

  // 頁面返回回調
  final List<VoidCallback> _onPageReturnCallbacks = [];

  /// 註冊待同步的任務
  /// 在 ChatDetailPage 中任務操作後調用
  void registerPendingSync({
    required String taskId,
    required Map<String, dynamic> updatedData,
    required String userRole,
  }) {
    debugPrint('$_tag 註冊待同步任務: $taskId');

    _pendingSyncTasks[taskId] = {
      'updated_data': updatedData,
      'user_role': userRole,
      'registered_at': DateTime.now().millisecondsSinceEpoch,
    };

    debugPrint('$_tag 待同步任務列表: ${_pendingSyncTasks.keys}');
  }

  /// 處理頁面返回事件
  /// 在 ChatListPage 的 resume 生命週期中調用
  Future<void> handlePageReturn(ChatListProvider provider) async {
    if (_pendingSyncTasks.isEmpty) {
      debugPrint('$_tag 無待同步任務，跳過處理');
      return;
    }

    debugPrint('$_tag 處理頁面返回同步，待處理任務: ${_pendingSyncTasks.length}');

    try {
      // 1. 處理所有待同步的任務
      for (final entry in _pendingSyncTasks.entries) {
        final taskId = entry.key;
        final syncData = entry.value;

        await _processPendingTaskSync(
          taskId: taskId,
          syncData: syncData,
          provider: provider,
        );
      }

      // 2. 觸發頁面回調
      for (final callback in _onPageReturnCallbacks) {
        try {
          callback();
        } catch (e) {
          debugPrint('$_tag 頁面返回回調執行失敗: $e');
        }
      }

      // 3. 清除待同步列表
      _pendingSyncTasks.clear();

      debugPrint('✅ $_tag 頁面返回同步處理完成');
    } catch (e) {
      debugPrint('❌ $_tag 頁面返回同步處理失敗: $e');
    }
  }

  /// 處理單個待同步任務
  Future<void> _processPendingTaskSync({
    required String taskId,
    required Map<String, dynamic> syncData,
    required ChatListProvider provider,
  }) async {
    debugPrint('$_tag 處理待同步任務: $taskId');

    try {
      final updatedData = syncData['updated_data'] as Map<String, dynamic>;
      final userRole = syncData['user_role'] as String;

      // 1. 立即更新任務狀態
      provider.updateTaskStatus(taskId, updatedData);

      // 2. 根據用戶角色觸發相應分頁刷新
      if (userRole == 'creator') {
        await provider.refreshTab(ChatListProvider.tabPostedTasks);
      } else {
        await provider.refreshTab(ChatListProvider.tabMyWorks);
      }

      debugPrint('✅ $_tag 任務同步完成: $taskId');
    } catch (e) {
      debugPrint('❌ $_tag 任務同步失敗: $taskId, error: $e');
    }
  }

  /// 註冊頁面返回回調
  void addPageReturnCallback(VoidCallback callback) {
    _onPageReturnCallbacks.add(callback);
    debugPrint('$_tag 已註冊頁面返回回調，總數: ${_onPageReturnCallbacks.length}');
  }

  /// 移除頁面返回回調
  void removePageReturnCallback(VoidCallback callback) {
    _onPageReturnCallbacks.remove(callback);
    debugPrint('$_tag 已移除頁面返回回調，剩餘: ${_onPageReturnCallbacks.length}');
  }

  /// 清除所有待同步數據（在應用重啟時調用）
  void clearAll() {
    _pendingSyncTasks.clear();
    _onPageReturnCallbacks.clear();
    debugPrint('$_tag 已清除所有待同步數據');
  }

  /// 獲取待同步任務數量（用於調試）
  int get pendingTasksCount => _pendingSyncTasks.length;

  /// 檢查特定任務是否在待同步列表中
  bool hasPendingSync(String taskId) {
    return _pendingSyncTasks.containsKey(taskId);
  }

  /// 獲取待同步任務的詳細信息（用於調試）
  Map<String, dynamic>? getPendingSyncInfo(String taskId) {
    return _pendingSyncTasks[taskId];
  }
}

/// 頁面返回監聽 Mixin
/// 用於 ChatListPage 監聽返回事件
mixin PageReturnSyncMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 添加生命週期監聽
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 移除生命週期監聽
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 當應用從背景回到前景時，處理頁面返回同步
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangeMetrics() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  Future<bool> didPushRouteInformation(
          RouteInformation routeInformation) async =>
      false;

  @override
  Future<bool> didPushRoute(String route) async => false;

  // Note: 以下方法在較新版本的 Flutter 中可能需要，可以根據實際 Flutter 版本調整
  // @override
  // void didChangeViewFocus(ViewFocusEvent event) {}

  @override
  Future<bool> didPopRoute() async => false;

  // @override
  // Future<AppExitResponse> didRequestAppExit() async => AppExitResponse.exit;

  // @override
  // void handleCancelBackGesture() {}

  // @override
  // void handleCommitBackGesture() {}

  // @override
  // bool handleStartBackGesture(PredictiveBackEvent backEvent) => false;

  // @override
  // void handleUpdateBackGestureProgress(BackGestureEvent event) {}

  /// 處理應用回到前景的事件
  void _handleAppResume() {
    debugPrint('[PageReturnSyncMixin] 應用回到前景，檢查頁面返回同步');

    // 延遲一小段時間確保頁面完全載入
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        onPageReturned();
      }
    });
  }

  /// 子類需要實現此方法來處理頁面返回事件
  void onPageReturned();
}

/// 智能同步策略
class SmartSyncStrategy {
  static const String _tag = '[SmartSyncStrategy]';

  /// 決定是否需要執行同步
  static bool shouldSync({
    required int pendingTasksCount,
    required bool cacheIsUpdating,
    required DateTime? lastUpdate,
  }) {
    // 1. 有待同步任務時必須同步
    if (pendingTasksCount > 0) {
      debugPrint('$_tag 有 $pendingTasksCount 個待同步任務，需要同步');
      return true;
    }

    // 2. 緩存正在更新中時不需要額外同步
    if (cacheIsUpdating) {
      debugPrint('$_tag 緩存正在更新中，跳過同步');
      return false;
    }

    // 3. 最近5分鐘內沒有更新過，建議同步
    if (lastUpdate == null) {
      debugPrint('$_tag 從未更新過，需要同步');
      return true;
    }

    final timeDiff = DateTime.now().difference(lastUpdate);
    if (timeDiff.inMinutes >= 5) {
      debugPrint('$_tag 超過5分鐘未更新，需要同步');
      return true;
    }

    debugPrint('$_tag 無需同步');
    return false;
  }

  /// 執行智能同步
  static Future<void> executeSmartSync({
    required ChatListProvider provider,
    bool forceSync = false,
  }) async {
    final syncManager = PageReturnSyncManager.instance;

    // 檢查是否需要同步
    final shouldExecuteSync = forceSync ||
        shouldSync(
          pendingTasksCount: syncManager.pendingTasksCount,
          cacheIsUpdating: provider.cacheManager.isUpdating,
          lastUpdate: provider.cacheManager.lastUpdate,
        );

    if (!shouldExecuteSync) {
      debugPrint('$_tag 智能同步判斷：無需同步');
      return;
    }

    debugPrint('$_tag 執行智能同步');

    try {
      // 執行頁面返回同步
      await syncManager.handlePageReturn(provider);

      // 如果沒有待同步任務，執行輕量檢查更新
      if (syncManager.pendingTasksCount == 0) {
        await provider.cacheManager.checkForUpdates();
      }

      debugPrint('✅ $_tag 智能同步完成');
    } catch (e) {
      debugPrint('❌ $_tag 智能同步失敗: $e');
    }
  }
}

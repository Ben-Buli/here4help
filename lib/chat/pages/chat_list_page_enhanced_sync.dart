import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/utils/page_return_sync_manager.dart';

/// 增強同步版本的 ChatListPage
/// 集成了智能頁面返回同步機制
class ChatListPageEnhancedSync extends StatefulWidget {
  const ChatListPageEnhancedSync({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ChatListPageEnhancedSync> createState() =>
      _ChatListPageEnhancedSyncState();
}

class _ChatListPageEnhancedSyncState extends State<ChatListPageEnhancedSync>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  // 🆕 直接實現 WidgetsBindingObserver

  @override
  bool get wantKeepAlive => true;

  late final ChatListProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
    // 添加生命週期監聽
    WidgetsBinding.instance.addObserver(this);
  }

  /// 初始化 Provider
  void _initializeProvider() {
    _chatProvider = context.read<ChatListProvider>();

    // 註冊頁面返回回調
    PageReturnSyncManager.instance.addPageReturnCallback(_onPageReturnDetected);

    debugPrint('✅ [ChatListPageEnhanced] Provider 初始化完成');
  }

  /// 🆕 實現應用生命週期變化處理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 當應用從背景回到前景時，處理頁面返回同步
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [ChatListPageEnhanced] 應用回到前景，檢測到頁面返回事件');

      if (!mounted) {
        debugPrint('⚠️ [ChatListPageEnhanced] Widget 未掛載，跳過同步');
        return;
      }

      // 執行智能同步策略
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _executeSmartSync();
        }
      });
    }
  }

  /// 頁面返回回調
  void _onPageReturnDetected() {
    debugPrint('📱 [ChatListPageEnhanced] 頁面返回回調觸發');

    if (mounted) {
      _executeSmartSync();
    }
  }

  /// 執行智能同步
  Future<void> _executeSmartSync() async {
    try {
      debugPrint('🚀 [ChatListPageEnhanced] 開始執行智能同步');

      // 使用智能同步策略
      await SmartSyncStrategy.executeSmartSync(
        provider: _chatProvider,
      );

      // 更新 UI 狀態
      if (mounted) {
        setState(() {
          // 觸發 UI 重建以反映最新狀態
        });
      }

      debugPrint('✅ [ChatListPageEnhanced] 智能同步完成');
    } catch (e) {
      debugPrint('❌ [ChatListPageEnhanced] 智能同步失敗: $e');
    }
  }

  /// 手動刷新（下拉刷新時調用）
  Future<void> _onRefresh() async {
    debugPrint('🔄 [ChatListPageEnhanced] 手動刷新觸發');

    try {
      // 強制執行同步
      await SmartSyncStrategy.executeSmartSync(
        provider: _chatProvider,
        forceSync: true,
      );

      debugPrint('✅ [ChatListPageEnhanced] 手動刷新完成');
    } catch (e) {
      debugPrint('❌ [ChatListPageEnhanced] 手動刷新失敗: $e');
    }
  }

  /// 分頁切換時的處理
  void _onTabChanged(int index) {
    debugPrint('📋 [ChatListPageEnhanced] 分頁切換到: $index');

    // 切換分頁時檢查是否需要同步
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkTabDataFreshness(index);
      }
    });
  }

  /// 檢查分頁數據新鮮度
  void _checkTabDataFreshness(int tabIndex) {
    final isLoaded = _chatProvider.isTabLoaded(tabIndex);
    final isLoading = _chatProvider.isTabLoading(tabIndex);
    final hasError = _chatProvider.getTabError(tabIndex) != null;

    debugPrint('🔍 [ChatListPageEnhanced] 檢查分頁 $tabIndex 數據狀態:');
    debugPrint('  - 已載入: $isLoaded');
    debugPrint('  - 載入中: $isLoading');
    debugPrint('  - 有錯誤: $hasError');

    // 如果數據未載入且未在載入中，或者有錯誤，觸發載入
    if ((!isLoaded && !isLoading) || hasError) {
      debugPrint('🔄 [ChatListPageEnhanced] 觸發分頁 $tabIndex 數據載入');
      _chatProvider.checkAndTriggerTabLoad(tabIndex);
    }

    // 檢查是否有待同步的任務影響當前分頁
    _checkPendingSyncForTab(tabIndex);
  }

  /// 檢查待同步任務是否影響當前分頁
  void _checkPendingSyncForTab(int tabIndex) {
    final syncManager = PageReturnSyncManager.instance;
    final pendingCount = syncManager.pendingTasksCount;

    if (pendingCount > 0) {
      debugPrint(
          '⚠️ [ChatListPageEnhanced] 分頁 $tabIndex 有 $pendingCount 個待同步任務');

      // 立即執行同步
      _executeSmartSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<ChatListProvider>(
      builder: (context, chatProvider, child) {
        return _buildTabViewWithSync(chatProvider);
      },
    );
  }

  /// 構建帶同步功能的 TabView
  Widget _buildTabViewWithSync(ChatListProvider provider) {
    return Column(
      children: [
        // 同步狀態指示器
        _buildSyncStatusIndicator(provider),

        // Tab 標籤欄
        _buildTabBar(provider),

        // Tab 內容
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: TabBarView(
              controller: provider.tabController,
              children: [
                _buildPostedTasksTab(provider),
                _buildMyWorksTab(provider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 構建同步狀態指示器
  Widget _buildSyncStatusIndicator(ChatListProvider provider) {
    final syncManager = PageReturnSyncManager.instance;
    final pendingCount = syncManager.pendingTasksCount;
    final isUpdating = provider.cacheManager.isUpdating;
    final updateMessage = provider.cacheManager.updateMessage;

    // 如果沒有待同步任務且不在更新中，不顯示指示器
    if (pendingCount == 0 && !isUpdating && updateMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          if (isUpdating) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              _getSyncStatusText(pendingCount, isUpdating, updateMessage),
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          if (pendingCount > 0)
            TextButton(
              onPressed: _executeSmartSync,
              child: const Text('立即同步', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// 獲取同步狀態文本
  String _getSyncStatusText(
      int pendingCount, bool isUpdating, String? updateMessage) {
    if (isUpdating) {
      return updateMessage ?? '正在同步數據...';
    }

    if (pendingCount > 0) {
      return '有 $pendingCount 個任務待同步，下拉刷新或點擊同步';
    }

    if (updateMessage != null) {
      return updateMessage;
    }

    return '';
  }

  /// 構建 Tab 標籤欄
  Widget _buildTabBar(ChatListProvider provider) {
    return TabBar(
      controller: provider.tabController,
      onTap: _onTabChanged,
      tabs: const [
        Tab(text: 'Posted Tasks'),
        Tab(text: 'My Works'),
      ],
    );
  }

  /// 構建 Posted Tasks 分頁
  Widget _buildPostedTasksTab(ChatListProvider provider) {
    // 這裡使用現有的 PostedTasksWidget，但可以添加同步增強
    return const Center(
      child: Text('Posted Tasks 內容 - 已增強同步'),
    );
  }

  /// 構建 My Works 分頁
  Widget _buildMyWorksTab(ChatListProvider provider) {
    // 這裡使用現有的 MyWorksWidget，但可以添加同步增強
    return const Center(
      child: Text('My Works 內容 - 已增強同步'),
    );
  }

  @override
  void dispose() {
    // 移除頁面返回回調
    PageReturnSyncManager.instance
        .removePageReturnCallback(_onPageReturnDetected);

    // 移除生命週期監聽
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }
}

/// 同步增強工具類
class ChatListSyncEnhancer {
  /// 為現有的 PostedTasksWidget 添加同步功能
  static Widget enhancePostedTasksWidget(Widget originalWidget) {
    return _SyncEnhancedWrapper(
      tabIndex: ChatListProvider.tabPostedTasks,
      child: originalWidget,
    );
  }

  /// 為現有的 MyWorksWidget 添加同步功能
  static Widget enhanceMyWorksWidget(Widget originalWidget) {
    return _SyncEnhancedWrapper(
      tabIndex: ChatListProvider.tabMyWorks,
      child: originalWidget,
    );
  }
}

/// 同步增強包裝器
class _SyncEnhancedWrapper extends StatefulWidget {
  const _SyncEnhancedWrapper({
    required this.tabIndex,
    required this.child,
  });

  final int tabIndex;
  final Widget child;

  @override
  State<_SyncEnhancedWrapper> createState() => _SyncEnhancedWrapperState();
}

class _SyncEnhancedWrapperState extends State<_SyncEnhancedWrapper> {
  @override
  void initState() {
    super.initState();

    // 註冊分頁特定的同步回調
    PageReturnSyncManager.instance.addPageReturnCallback(_onPageReturn);
  }

  void _onPageReturn() {
    if (!mounted) return;

    final provider = context.read<ChatListProvider>();
    if (provider.currentTabIndex == widget.tabIndex) {
      // 當前分頁需要檢查同步
      _checkTabSync(provider);
    }
  }

  Future<void> _checkTabSync(ChatListProvider provider) async {
    final syncManager = PageReturnSyncManager.instance;

    // 檢查是否有影響當前分頁的待同步任務
    if (syncManager.pendingTasksCount > 0) {
      debugPrint('🔄 [SyncWrapper] 分頁 ${widget.tabIndex} 執行同步');
      await syncManager.handlePageReturn(provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    PageReturnSyncManager.instance.removePageReturnCallback(_onPageReturn);
    super.dispose();
  }
}

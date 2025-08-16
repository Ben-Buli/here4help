import 'package:flutter/material.dart';
import 'package:here4help/chat/services/chat_cache_manager.dart';
import 'package:here4help/task/services/task_service.dart';

/// ChatList 狀態管理 Provider
/// 替代原本的 GlobalKey 機制，提供統一的狀態管理
class ChatListProvider extends ChangeNotifier {
  // Tab 控制
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isInitialized = false;

  // 靜態實例，用於外部訪問
  static ChatListProvider? _instance;

  // 外部 TabController（如 AppBar 中的）
  TabController? _externalTabController;

  // 搜索和篩選狀態 - 分頁獨立
  final Map<int, String> _searchQueries = {0: '', 1: ''};
  final Map<int, Set<String>> _selectedLocations = {
    0: <String>{},
    1: <String>{}
  };
  final Map<int, Set<String>> _selectedStatuses = {
    0: <String>{},
    1: <String>{}
  };

  // 排序狀態 - 分頁獨立
  final Map<int, String> _currentSortBy = {
    0: 'updated_time', // 改為 updated_time 作為預設
    1: 'updated_time'
  };
  final Map<int, bool> _sortAscending = {0: false, 1: false};

  // 相關性搜尋狀態
  final Map<int, bool> _crossLocationSearch = {0: false, 1: false};

  // 追蹤用戶是否手動選擇過排序
  final Map<int, bool> _hasManualSortOverride = {0: false, 1: false};

  // 分頁未讀提示（小圓點）
  final Map<int, bool> _tabHasUnread = {0: false, 1: false};

  // 載入狀態
  bool _isLoading = true;
  String? _errorMessage;

  // 快取管理
  late ChatCacheManager _cacheManager;

  // Posted Tasks 應徵者資料快取
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // Getters
  TabController get tabController => _tabController;
  int get currentTabIndex => _currentTabIndex;
  bool get isInitialized => _isInitialized;
  String get searchQuery => _searchQueries[_currentTabIndex] ?? '';
  Set<String> get selectedLocations =>
      _selectedLocations[_currentTabIndex] ?? <String>{};
  Set<String> get selectedStatuses =>
      _selectedStatuses[_currentTabIndex] ?? <String>{};
  String get currentSortBy =>
      _currentSortBy[_currentTabIndex] ?? 'updated_time';
  bool get sortAscending => _sortAscending[_currentTabIndex] ?? false;
  bool get crossLocationSearch =>
      _crossLocationSearch[_currentTabIndex] ?? false;
  bool hasUnreadForTab(int tabIndex) => _tabHasUnread[tabIndex] ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ChatCacheManager get cacheManager => _cacheManager;
  Map<String, List<Map<String, dynamic>>> get applicationsByTask =>
      _applicationsByTask;

  bool get hasActiveFilters =>
      selectedLocations.isNotEmpty ||
      selectedStatuses.isNotEmpty ||
      searchQuery.isNotEmpty;

  bool get taskerFilterEnabled => _currentTabIndex == 1;

  // 最近一次狀態事件（用於避免無限刷新迴圈）
  String _lastEvent = '';
  String get lastEvent => _lastEvent;

  void _emit(String event) {
    _lastEvent = event;
    debugPrint('📡 [ChatListProvider] 發出事件: $event');
    notifyListeners();
  }

  /// 初始化 TabController
  void initializeTabController(TickerProvider vsync, {int initialTab = 0}) {
    if (_isInitialized) return;

    _tabController = TabController(
      length: 2,
      vsync: vsync,
      initialIndex: initialTab,
    );

    _currentTabIndex = initialTab;
    _cacheManager = ChatCacheManager();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // TabBarView 滑動時，更新當前索引並同步外部 TabController
        _currentTabIndex = _tabController.index;

        // 同步外部 TabController（AppBar 中的）
        if (_externalTabController != null &&
            _externalTabController!.index != _currentTabIndex) {
          _externalTabController!.animateTo(_currentTabIndex);
        }

        notifyListeners(); // 通知其他監聽者
      }
    });

    // 設置靜態實例，供外部訪問
    _instance = this;

    _isInitialized = true;
    _emit('init');
  }

  /// 獲取當前實例（用於外部訪問）
  static ChatListProvider? get instance => _instance;

  /// 註冊外部 TabController（如 AppBar 中的）
  void registerExternalTabController(TabController externalController) {
    _externalTabController = externalController;
  }

  /// 切換 Tab
  void switchTab(int index) {
    if (_currentTabIndex == index) return;

    _currentTabIndex = index;

    // 同步內部 TabController（ChatListPage 中的 TabBarView）
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }

    // 同步外部 TabController
    if (_externalTabController != null &&
        _externalTabController!.index != index) {
      _externalTabController!.animateTo(index);
    }

    // 不重置篩選條件，每個分頁保持獨立狀態
    _emit('tab');
  }

  /// 設置搜尋查詢
  void setSearchQuery(String query) {
    final currentQuery = _searchQueries[_currentTabIndex] ?? '';
    if (currentQuery != query) {
      _searchQueries[_currentTabIndex] = query;

      // 智能排序：有搜尋時建議設為 relevance，但尊重用戶的手動選擇
      if (query.trim().isNotEmpty && currentSortBy != 'relevance') {
        // 只有在用戶沒有手動覆蓋過排序時，才自動切換
        if (!(_hasManualSortOverride[_currentTabIndex] ?? false)) {
          _currentSortBy[_currentTabIndex] = 'relevance';
          _sortAscending[_currentTabIndex] = false;
          debugPrint('🔍 [ChatListProvider] 建議切換到相關性排序');
        } else {
          debugPrint('🔍 [ChatListProvider] 用戶已手動選擇排序，保持當前選擇');
        }
      } else if (query.trim().isEmpty && currentSortBy == 'relevance') {
        // 搜尋清空時，如果當前是 relevance，則切換回 updated_time
        _currentSortBy[_currentTabIndex] = 'updated_time';
        _sortAscending[_currentTabIndex] = false;
        // 重置手動覆蓋標記
        _hasManualSortOverride[_currentTabIndex] = false;
        debugPrint('🔍 [ChatListProvider] 搜尋清空，切換到時間排序');
      }

      _emit('search_changed');
    }
  }

  /// 更新搜尋查詢（別名方法，保持向後兼容）
  void updateSearchQuery(String query) {
    setSearchQuery(query);
  }

  /// 更新位置篩選
  void updateLocationFilter(Set<String> locations) {
    _selectedLocations[_currentTabIndex] = locations;
    _emit('criteria');
  }

  /// 更新狀態篩選
  void updateStatusFilter(Set<String> statuses) {
    _selectedStatuses[_currentTabIndex] = statuses;
    _emit('criteria');
  }

  /// 設置排序方式
  void setSortOrder(String sortBy, {bool ascending = false}) {
    if (_currentSortBy[_currentTabIndex] != sortBy ||
        _sortAscending[_currentTabIndex] != ascending) {
      _currentSortBy[_currentTabIndex] = sortBy;
      _sortAscending[_currentTabIndex] = ascending;

      // 追蹤用戶手動選擇的排序
      if (sortBy != 'relevance' ||
          _searchQueries[_currentTabIndex]?.isNotEmpty == true) {
        _hasManualSortOverride[_currentTabIndex] = true;
        debugPrint('🔍 [ChatListProvider] 用戶手動選擇排序: $sortBy');
      }

      _emit('sort_changed');
    }
  }

  /// 設置跨位置搜尋
  void setCrossLocationSearch(bool enabled) {
    if (_crossLocationSearch[_currentTabIndex] != enabled) {
      _crossLocationSearch[_currentTabIndex] = enabled;
      _emit('cross_location_search_changed');
    }
  }

  /// 智能設置排序（有搜尋時自動設為 relevance）
  void setSmartSortOrder(String sortBy, {bool ascending = false}) {
    // 如果有搜尋查詢且選擇了 relevance，則自動設置
    if (searchQuery.isNotEmpty && sortBy == 'relevance') {
      setSortOrder('relevance', ascending: false);
    } else {
      setSortOrder(sortBy, ascending: ascending);
    }
  }

  /// 重置當前分頁的所有篩選條件
  void resetFilters() {
    _searchQueries[_currentTabIndex] = '';
    _selectedLocations[_currentTabIndex]?.clear();
    _selectedStatuses[_currentTabIndex]?.clear();
    _currentSortBy[_currentTabIndex] = 'updated_time';
    _sortAscending[_currentTabIndex] = false;
    _hasManualSortOverride[_currentTabIndex] = false; // 重置手動覆蓋標記
    _emit('criteria');
  }

  /// 更新某個分頁是否有未讀（供 Posted/MyWorks widget 設定）
  /// 添加防循環機制，避免無限刷新
  void setTabHasUnread(int tabIndex, bool value) {
    // 只有當狀態真正改變時才更新，避免無限循環
    if (_tabHasUnread[tabIndex] == value) {
      debugPrint(
          '🔄 [ChatListProvider] 未讀狀態未改變，跳過通知: tab=$tabIndex, value=$value');
      return;
    }

    debugPrint('✅ [ChatListProvider] 更新未讀狀態: tab=$tabIndex, $value');
    _tabHasUnread[tabIndex] = value;

    // 使用特定事件類型，避免觸發不必要的刷新
    _emit('unread_update');
  }

  /// 更新載入狀態
  void setLoadingState(bool isLoading, [String? errorMessage]) {
    _isLoading = isLoading;
    _errorMessage = errorMessage;
    _emit('loading');
  }

  /// 使用快取系統初始化數據
  Future<void> initializeWithCache() async {
    try {
      debugPrint('🚀 開始使用快取系統初始化...');

      // 初始化快取
      await _cacheManager.initializeCache();

      // 如果快取有效，直接使用快取數據
      if (_cacheManager.isCacheValid && !_cacheManager.isCacheEmpty) {
        debugPrint('✅ 快取有效，使用快取數據');

        // 將快取數據載入到本地狀態
        await _loadDataFromCache();

        setLoadingState(false);
        debugPrint('⚡ 快取載入完成！');

        // 進入頁面後輕量檢查更新
        _checkForUpdatesAfterEnter();
      } else {
        debugPrint('🔄 快取無效或為空，執行完整載入...');
        await _loadChatData();
      }
    } catch (e) {
      debugPrint('❌ 快取初始化失敗: $e');
      setLoadingState(false, e.toString());
    }
  }

  /// 從快取載入數據到本地狀態
  Future<void> _loadDataFromCache() async {
    try {
      // 載入 Posted Tasks 快取
      _applicationsByTask.clear();
      for (final task in _cacheManager.postedTasksCache) {
        if (task['applications'] != null) {
          _applicationsByTask[task['id'].toString()] =
              List<Map<String, dynamic>>.from(task['applications']);
        }
      }

      debugPrint(
          '📋 快取數據載入完成 - Posted Tasks: ${_cacheManager.postedTasksCache.length}, My Works: ${_cacheManager.myWorksCache.length}');
    } catch (e) {
      debugPrint('❌ 快取數據載入失敗: $e');
    }
  }

  /// 進入頁面後輕量檢查更新
  void _checkForUpdatesAfterEnter() {
    // TODO: 實現輕量更新檢查邏輯
    debugPrint('🔍 檢查數據更新...');
  }

  /// 同步載入所有聊天相關數據
  Future<void> _loadChatData() async {
    try {
      debugPrint('🔄 開始同步載入聊天數據...');

      // 同步載入任務和狀態
      await Future.wait([
        TaskService().loadTasks(),
        TaskService().loadStatuses(),
      ]);
      debugPrint('✅ 任務列表載入完成');

      // 載入應徵者數據
      await _loadApplicationsForPostedTasks();
      debugPrint('✅ 應徵者資料載入完成');

      setLoadingState(false);
      debugPrint('🎉 聊天數據載入完成！');
    } catch (e) {
      debugPrint('❌ 聊天數據載入失敗: $e');
      setLoadingState(false, e.toString());
    }
  }

  /// 載入 Posted Tasks 的應徵者資料
  Future<void> _loadApplicationsForPostedTasks() async {
    try {
      final taskService = TaskService();
      final tasks = taskService.tasks;

      debugPrint('🔍 開始載入應徵者資料，總任務數: ${tasks.length}');

      _applicationsByTask.clear();

      for (final task in tasks) {
        final taskId = task['id'].toString();
        try {
          final applications = await taskService.loadApplicationsByTask(taskId);
          debugPrint('🔍 任務 $taskId 應徵者數量: ${applications.length}');
          if (applications.isNotEmpty) {
            _applicationsByTask[taskId] = applications;
            debugPrint('✅ 任務 $taskId 已儲存 ${applications.length} 個應徵者');
          }
        } catch (e) {
          debugPrint('❌ 載入任務 $taskId 的應徵者失敗: $e');
        }
      }

      debugPrint('📄 應徵者資料載入完成: ${_applicationsByTask.length} 個任務有應徵者');
      debugPrint('📄 應徵者資料詳細: $_applicationsByTask');
    } catch (e) {
      debugPrint('❌ 載入應徵者資料失敗: $e');
    }
  }

  /// 強制刷新所有數據
  Future<void> forceRefresh() async {
    setLoadingState(true);
    await _cacheManager.forceRefresh();
    await _loadChatData();
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _tabController.dispose();
    }
    // 清理靜態實例
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }
}

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
    0: 'updated_time',
    1: 'updated_time'
  };
  final Map<int, bool> _sortAscending = {0: false, 1: false};

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
        switchTab(_tabController.index);
      }
    });

    // 設置靜態實例，供外部訪問
    _instance = this;

    _isInitialized = true;
    notifyListeners();
  }

  /// 獲取當前實例（用於外部訪問）
  static ChatListProvider? get instance => _instance;

  /// 切換 Tab
  void switchTab(int index) {
    if (_currentTabIndex == index) return;

    _currentTabIndex = index;

    // 同步內部 TabController（ChatListPage 中的 TabBarView）
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }

    // 不重置篩選條件，每個分頁保持獨立狀態
    notifyListeners();
  }

  /// 更新搜索查詢
  void updateSearchQuery(String query) {
    if (searchQuery == query) return;
    _searchQueries[_currentTabIndex] = query;
    notifyListeners();
  }

  /// 更新位置篩選
  void updateLocationFilter(Set<String> locations) {
    _selectedLocations[_currentTabIndex] = locations;
    notifyListeners();
  }

  /// 更新狀態篩選
  void updateStatusFilter(Set<String> statuses) {
    _selectedStatuses[_currentTabIndex] = statuses;
    notifyListeners();
  }

  /// 設置排序方式
  void setSortOrder(String sortBy) {
    final currentSort = currentSortBy;
    final currentAsc = sortAscending;

    if (currentSort == sortBy) {
      _sortAscending[_currentTabIndex] = !currentAsc;
    } else {
      _currentSortBy[_currentTabIndex] = sortBy;
      _sortAscending[_currentTabIndex] = true;
    }
    notifyListeners();
  }

  /// 重置當前分頁的所有篩選條件
  void resetFilters() {
    _searchQueries[_currentTabIndex] = '';
    _selectedLocations[_currentTabIndex]?.clear();
    _selectedStatuses[_currentTabIndex]?.clear();
    _currentSortBy[_currentTabIndex] = 'updated_time';
    _sortAscending[_currentTabIndex] = false;
    notifyListeners();
  }

  /// 更新載入狀態
  void setLoadingState(bool isLoading, [String? errorMessage]) {
    _isLoading = isLoading;
    _errorMessage = errorMessage;
    notifyListeners();
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

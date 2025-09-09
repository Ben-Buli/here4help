import 'dart:async';
import 'package:flutter/material.dart';
import 'package:here4help/auth/services/user_service.dart' show UserService;
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

  // 外部 TabController（如 AppBar 中的）//
  TabController? _externalTabController;

  // 搜索和篩選狀態 - 分頁獨立
  final Map<int, String> _searchQueries = {tabPostedTasks: '', tabMyWorks: ''};
  final Map<int, Set<String>> _selectedLocations = {
    tabPostedTasks: <String>{},
    tabMyWorks: <String>{}
  };
  final Map<int, Set<String>> _selectedStatuses = {
    tabPostedTasks: <String>{},
    tabMyWorks: <String>{}
  };

  // 排序狀態 - 分頁獨立
  final Map<int, String> _currentSortBy = {
    tabPostedTasks: 'status_id', // 改為 status_id，與後端 SQL 排序一致
    tabMyWorks: 'status_id' // 統一使用狀態優先級排序
  };
  final Map<int, bool> _sortAscending = {
    tabPostedTasks: true, // status_id 使用升序排序（1,2,3...）
    tabMyWorks: true // 與後端 ASC 排序一致
  };

  // 相關性搜尋狀態
  final Map<int, bool> _crossLocationSearch = {
    tabPostedTasks: false,
    tabMyWorks: false
  };

  // 追蹤用戶是否手動選擇過排序
  final Map<int, bool> _hasManualSortOverride = {
    tabPostedTasks: false,
    tabMyWorks: false
  };

  // 分頁常數定義
  static const int tabPostedTasks = 0;
  static const int tabMyWorks = 1;

  // 分頁未讀提示（小圓點）
  final Map<int, bool> _tabHasUnread = {
    tabPostedTasks: false,
    tabMyWorks: false
  };

  // 房間級別未讀數管理
  final Map<String, int> _unreadByRoom = {};

  // 未讀事件防抖處理
  final Map<int, Timer?> _unreadDebounceTimers = {
    tabPostedTasks: null,
    tabMyWorks: null
  };
  final Map<int, bool?> _pendingTabUnread = {
    tabPostedTasks: null,
    tabMyWorks: null
  };

  // 防抖狀態追蹤
  final Map<int, DateTime> _lastUnreadUpdate = {
    tabPostedTasks: DateTime.now(),
    tabMyWorks: DateTime.now()
  };

  // 載入狀態（全域狀態，只用於全量刷新操作）
  bool _isLoading = false;
  String? _errorMessage;

  // 分頁級別的載入狀態管理
  final Map<int, bool> _tabIsLoading = {
    tabPostedTasks: false,
    tabMyWorks: false
  };
  final Map<int, bool> _tabLoaded = {tabPostedTasks: false, tabMyWorks: false};
  final Map<int, String?> _tabErrors = {tabPostedTasks: null, tabMyWorks: null};

  // 快取管理
  late ChatCacheManager _cacheManager;

  // Posted Tasks 應徵者資料快取
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // My Works 應徵記錄快取
  final List<Map<String, dynamic>> _myWorksApplications = [];

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

  // 分頁狀態查詢器
  bool isTabLoading(int tab) => _tabIsLoading[tab] ?? false;
  bool isTabLoaded(int tab) => _tabLoaded[tab] ?? false;
  String? getTabError(int tab) => _tabErrors[tab];

  List<Map<String, dynamic>> get myWorksApplications => _myWorksApplications;

  /// 獲取已發布的任務列表
  List<Map<String, dynamic>> get postedTasks => _cacheManager.postedTasksCache;

  /// 獲取過濾後的已發布任務列表
  List<Map<String, dynamic>> get filteredPostedTasks {
    if (!isTabLoaded(tabPostedTasks)) {
      debugPrint('⚠️ [ChatListProvider] Posted Tasks 分頁尚未載入完成');
      return [];
    }

    var tasks = List<Map<String, dynamic>>.from(_cacheManager.postedTasksCache);

    // 應用搜尋過濾（僅任務標題）
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      tasks = tasks.where((task) {
        final title = (task['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
      debugPrint('🔍 [ChatListProvider] 標題搜尋過濾後任務數量: ${tasks.length}');
    }

    // 應用位置過濾
    if (selectedLocations.isNotEmpty) {
      tasks = tasks.where((task) {
        final location = (task['location'] ?? '').toString();
        return selectedLocations.contains(location);
      }).toList();
      debugPrint('📍 [ChatListProvider] 位置過濾後任務數量: ${tasks.length}');
    }

    // 應用狀態過濾
    if (selectedStatuses.isNotEmpty) {
      tasks = tasks.where((task) {
        final statusId = task['status_id']?.toString();
        // 這裡需要根據 status_id 查找對應的狀態代碼
        // 暫時使用 status_id 進行過濾
        return selectedStatuses.contains(statusId);
      }).toList();
      debugPrint('📊 [ChatListProvider] 狀態過濾後任務數量: ${tasks.length}');
    }

    // 應用混合排序（未讀優先 + 用戶選擇的排序）
    tasks = _applyUnreadPrioritySort(tasks, currentSortBy, sortAscending);

    debugPrint('✅ [ChatListProvider] 過濾後的 Posted Tasks 數量: ${tasks.length}');
    return tasks;
  }

  /// 獲取過濾後的我的工作列表
  List<Map<String, dynamic>> get filteredMyWorks {
    if (!isTabLoaded(tabMyWorks)) {
      debugPrint('⚠️ [ChatListProvider] My Works 分頁尚未載入完成');
      return [];
    }

    var works = List<Map<String, dynamic>>.from(_myWorksApplications);

    // 應用搜尋過濾（僅任務標題）
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      works = works.where((work) {
        final title = (work['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
      debugPrint('🔍 [ChatListProvider] My Works 標題搜尋過濾後數量: ${works.length}');
    }

    // 應用位置過濾
    if (selectedLocations.isNotEmpty) {
      works = works.where((work) {
        final location = (work['location'] ?? '').toString();
        return selectedLocations.contains(location);
      }).toList();
      debugPrint('📍 [ChatListProvider] My Works 位置過濾後數量: ${works.length}');
    }

    // 應用狀態過濾
    if (selectedStatuses.isNotEmpty) {
      works = works.where((work) {
        final statusId = work['status_id']?.toString();
        return selectedStatuses.contains(statusId);
      }).toList();
      debugPrint('📊 [ChatListProvider] My Works 狀態過濾後數量: ${works.length}');
    }

    // 應用混合排序（未讀優先 + 用戶選擇的排序）
    works = _applyUnreadPrioritySort(works, currentSortBy, sortAscending);

    debugPrint('✅ [ChatListProvider] 過濾後的 My Works 數量: ${works.length}');
    return works;
  }

  /// 獲取當前分頁的過濾後數據
  List<Map<String, dynamic>> get currentTabData {
    switch (_currentTabIndex) {
      case tabPostedTasks:
        return filteredPostedTasks;
      case tabMyWorks:
        return filteredMyWorks;
      default:
        return [];
    }
  }

  /// 獲取當前分頁的數據總數
  int get currentTabDataCount => currentTabData.length;

  /// 應用混合排序（未讀優先 + 用戶選擇的排序）
  List<Map<String, dynamic>> _applyUnreadPrioritySort(
      List<Map<String, dynamic>> items, String baseSortBy, bool ascending) {
    return items
      ..sort((a, b) {
        // 1. 首先按未讀狀態排序（有未讀的優先）
        final aHasUnread = _hasUnreadMessages(a);
        final bHasUnread = _hasUnreadMessages(b);

        if (aHasUnread && !bHasUnread) return -1;
        if (!aHasUnread && bHasUnread) return 1;

        // 2. 未讀狀態相同時，按原有排序邏輯
        return _compareBySortType(a, b, baseSortBy, ascending);
      });
  }

  /// 檢查項目是否有未讀訊息
  bool _hasUnreadMessages(Map<String, dynamic> item) {
    // Posted Tasks: 檢查任一應徵者聊天室有未讀
    if (_currentTabIndex == tabPostedTasks) {
      final taskId = item['id']?.toString();
      final applicants = _applicationsByTask[taskId] ?? [];
      return applicants.any((app) {
        final roomId = app['chat_room_id']?.toString();
        return roomId != null && (_unreadByRoom[roomId] ?? 0) > 0;
      });
    }

    // My Works: 檢查聊天室有未讀
    if (_currentTabIndex == tabMyWorks) {
      final roomId = item['chat_room_id']?.toString();
      return roomId != null && (_unreadByRoom[roomId] ?? 0) > 0;
    }

    return false;
  }

  /// 根據排序類型比較兩個項目
  int _compareBySortType(Map<String, dynamic> a, Map<String, dynamic> b,
      String sortBy, bool ascending) {
    switch (sortBy) {
      case 'updated_time':
        final aTime =
            DateTime.tryParse(a['updated_at'] ?? '') ?? DateTime(1970);
        final bTime =
            DateTime.tryParse(b['updated_at'] ?? '') ?? DateTime(1970);
        return ascending ? aTime.compareTo(bTime) : bTime.compareTo(aTime);

      case 'status_id':
        final aStatus = int.tryParse(a['status_id']?.toString() ?? '0') ?? 0;
        final bStatus = int.tryParse(b['status_id']?.toString() ?? '0') ?? 0;
        return ascending
            ? aStatus.compareTo(bStatus)
            : bStatus.compareTo(aStatus);

      case 'popularity':
        // Posted Tasks: 根據應徵數量排序
        if (_currentTabIndex == tabPostedTasks) {
          final aCount = _applicationsByTask[a['id']?.toString()]?.length ?? 0;
          final bCount = _applicationsByTask[b['id']?.toString()]?.length ?? 0;
          return ascending
              ? aCount.compareTo(bCount)
              : bCount.compareTo(aCount);
        }
        // My Works: 不適用，使用預設排序
        return 0;

      case 'relevance':
        // 相關性排序（僅在搜尋時使用）
        final aRelevance = a['_relevance'] ?? 0;
        final bRelevance = b['_relevance'] ?? 0;
        return ascending
            ? aRelevance.compareTo(bRelevance)
            : bRelevance.compareTo(aRelevance);

      default:
        // 預設按更新時間排序
        final aTime =
            DateTime.tryParse(a['updated_at'] ?? '') ?? DateTime(1970);
        final bTime =
            DateTime.tryParse(b['updated_at'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime); // 降序
    }
  }

  /// 設置分頁載入狀態（只在變動時 notify）
  void setTabLoading(int tab, bool value) {
    final prev = _tabIsLoading[tab];
    if (prev != value) {
      _tabIsLoading[tab] = value;
      debugPrint('🔄 [ChatListProvider] 分頁 $tab 載入狀態: $prev -> $value');
      _emit('tab_loading_$tab');
    }
  }

  /// 設置分頁載入完成狀態
  void setTabLoaded(int tab, bool value) {
    final prev = _tabLoaded[tab];
    if (prev != value) {
      _tabLoaded[tab] = value;
      debugPrint('🔄 [ChatListProvider] 分頁 $tab 載入完成狀態: $prev -> $value');
      _emit('tab_loaded_$tab');
    }
  }

  /// 設置分頁錯誤狀態
  void setTabError(int tab, String? error) {
    final prev = _tabErrors[tab];
    if (prev != error) {
      _tabErrors[tab] = error;
      debugPrint('🔄 [ChatListProvider] 分頁 $tab 錯誤狀態: $prev -> $error');
      _emit('tab_error_$tab');
    }
  }

  /// 清除分頁錯誤狀態
  void clearTabError(int tab) {
    setTabError(tab, null);
  }

  /// 清除所有分頁錯誤狀態
  void clearAllTabErrors() {
    for (int tab = 0; tab < 2; tab++) {
      clearTabError(tab);
    }
  }

  bool get hasActiveFilters =>
      selectedLocations.isNotEmpty ||
      selectedStatuses.isNotEmpty ||
      searchQuery.isNotEmpty;

  bool get taskerFilterEnabled => _currentTabIndex == tabMyWorks;

  // 分頁類型判斷
  bool get isPostedTasksTab => _currentTabIndex == tabPostedTasks;
  bool get isMyWorksTab => _currentTabIndex == tabMyWorks;

  // 未讀數管理 getters
  int unreadForRoom(String roomId) => _unreadByRoom[roomId] ?? 0;
  Map<String, int> get unreadByRoom => Map.unmodifiable(_unreadByRoom);

  // 最近一次狀態事件（用於避免無限刷新迴圈）
  String _lastEvent = '';
  String get lastEvent => _lastEvent;

  void _emit(String event) {
    _lastEvent = event;
    debugPrint('📡 [ChatListProvider] 發出事件: $event');
    notifyListeners();
  }

  /// 初始化 TabController
  void initializeTabController(TickerProvider vsync,
      {int initialTab = tabPostedTasks}) {
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

    // 初始化完成，觸發初始分頁的數據載入
    debugPrint('🚀 [ChatListProvider] 初始化完成，觸發初始分頁 $initialTab 的數據載入');

    // 延遲觸發初始分頁載入，確保所有初始化完成
    Future.microtask(() {
      if (_isInitialized) {
        checkAndTriggerTabLoad(initialTab);
      }
    });
  }

  /// 獲取當前實例（用於外部訪問）
  static ChatListProvider? get instance => _instance;

  /// 註冊外部 TabController（如 AppBar 中的）
  void registerExternalTabController(TabController externalController) {
    if (_externalTabController == externalController) return;

    _externalTabController = externalController;

    // 監聽外層 Tab 切換，與 Provider 狀態同步
    _externalTabController!.addListener(() {
      final newIndex = _externalTabController!.index;
      if (_currentTabIndex != newIndex) {
        _currentTabIndex = newIndex;

        // 與內部 TabController 同步（若存在）
        if (_isInitialized && _tabController.index != newIndex) {
          _tabController.animateTo(newIndex);
        }

        // 觸發分頁首次載入（若需要）
        _checkAndTriggerTabLoad(newIndex);

        _emit('tab_external');
      }
    });
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

    // 檢查是否需要觸發該分頁的首次載入
    _checkAndTriggerTabLoad(index);

    // 不重置篩選條件，每個分頁保持獨立狀態
    _emit('tab');
  }

  /// 檢查並觸發分頁的首次載入
  void checkAndTriggerTabLoad([int? tabIndex]) {
    // 如果沒有指定 tabIndex，預設為當前分頁或 0
    final targetTabIndex = tabIndex ?? _currentTabIndex;

    // 確保 Provider 已初始化
    if (!_isInitialized) {
      debugPrint(
          '⚠️ [ChatListProvider] Provider 尚未初始化，跳過分頁 $targetTabIndex 載入');
      return;
    }

    // 確保分頁索引有效
    if (targetTabIndex < 0 || targetTabIndex >= 2) {
      debugPrint('❌ [ChatListProvider] 無效的分頁索引: $targetTabIndex');
      return;
    }

    if (!isTabLoaded(targetTabIndex) && !isTabLoading(targetTabIndex)) {
      debugPrint('🚀 [ChatListProvider] 分頁 $targetTabIndex 首次載入，觸發數據載入');
      _loadTabData(targetTabIndex);
    } else {
      debugPrint('✅ [ChatListProvider] 分頁 $targetTabIndex 已載入或正在載入中');
    }
  }

  /// 檢查並觸發分頁的首次載入（內部使用）
  void _checkAndTriggerTabLoad([int? tabIndex]) {
    checkAndTriggerTabLoad(tabIndex);
  }

  /// 載入指定分頁的數據
  Future<void> _loadTabData(int tabIndex) async {
    debugPrint('🚀 [ChatListProvider] 開始載入分頁 $tabIndex 數據');

    if (isTabLoading(tabIndex)) {
      debugPrint('⚠️ [ChatListProvider] 分頁 $tabIndex 正在載入中，跳過重複載入');
      return;
    }

    setTabLoading(tabIndex, true);
    setTabError(tabIndex, null);

    debugPrint('🔄 [ChatListProvider] 分頁 $tabIndex 載入狀態設置為 true');

    try {
      switch (tabIndex) {
        case tabPostedTasks:
          debugPrint('📡 [ChatListProvider] 開始載入 Posted Tasks 數據');

          // 載入任務狀態（仍需要用於UI顯示）
          debugPrint('📡 [ChatListProvider] 載入任務狀態...');
          await TaskService().loadStatuses();
          debugPrint('✅ [ChatListProvider] 任務狀態載入完成');

          // 使用聚合API一次性載入任務和應徵者資料
          await _loadApplicationsForPostedTasks();
          debugPrint('✅ [ChatListProvider] Posted Tasks 數據載入完成');
          break;
        case tabMyWorks:
          debugPrint('📡 [ChatListProvider] 開始載入 My Works 數據');
          await _loadMyWorksData();
          debugPrint('✅ [ChatListProvider] My Works 數據載入完成');
          break;
        default:
          throw Exception('未知的分頁索引: $tabIndex');
      }

      setTabLoaded(tabIndex, true);
      debugPrint('✅ [ChatListProvider] 分頁 $tabIndex 數據載入完成，設置載入完成狀態');

      // 添加詳細的狀態檢查
      debugPrint('🔍 [ChatListProvider] 分頁 $tabIndex 最終狀態檢查:');
      debugPrint('  - 載入中: ${isTabLoading(tabIndex)}');
      debugPrint('  - 載入完成: ${isTabLoaded(tabIndex)}');
      debugPrint('  - 錯誤: ${getTabError(tabIndex)}');
    } catch (e) {
      debugPrint('❌ [ChatListProvider] 分頁 $tabIndex 數據載入失敗: $e');
      setTabError(tabIndex, e.toString());
      debugPrint('❌ [ChatListProvider] 分頁 $tabIndex 錯誤狀態已設置');
    } finally {
      setTabLoading(tabIndex, false);
      debugPrint('🔄 [ChatListProvider] 分頁 $tabIndex 載入狀態設置為 false');
    }
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
        // 搜尋清空時，如果當前是 relevance，則切換回 status_id
        _currentSortBy[_currentTabIndex] = 'status_id';
        _sortAscending[_currentTabIndex] = true;
        // 重置手動覆蓋標記
        _hasManualSortOverride[_currentTabIndex] = false;
        debugPrint('🔍 [ChatListProvider] 搜尋清空，切換到狀態優先級排序');
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

  /// 設置排序方式（支援 toggle 功能）
  void setSortOrder(String sortBy, {bool? ascending}) {
    final currentSortBy = _currentSortBy[_currentTabIndex];
    final currentAscending = _sortAscending[_currentTabIndex] ?? false;

    // 如果選擇相同的排序方式，則 toggle 升序/降序
    if (currentSortBy == sortBy && ascending == null) {
      _sortAscending[_currentTabIndex] = !currentAscending;
      debugPrint(
          '🔄 [ChatListProvider] Toggle 排序方向: ${!currentAscending ? "升序" : "降序"}');
    } else {
      // 選擇不同的排序方式，使用預設方向或指定方向
      _currentSortBy[_currentTabIndex] = sortBy;
      _sortAscending[_currentTabIndex] =
          ascending ?? _getDefaultAscending(sortBy);
      debugPrint(
          '🔄 [ChatListProvider] 切換排序方式: $sortBy (${(_sortAscending[_currentTabIndex] ?? false) ? "升序" : "降序"})');
    }

    // 追蹤用戶手動選擇的排序
    if (sortBy != 'relevance' ||
        _searchQueries[_currentTabIndex]?.isNotEmpty == true) {
      _hasManualSortOverride[_currentTabIndex] = true;
      debugPrint('🔍 [ChatListProvider] 用戶手動選擇排序: $sortBy');
    }

    _emit('sort_changed');
  }

  /// 獲取排序方式的預設升序/降序設定
  bool _getDefaultAscending(String sortBy) {
    switch (sortBy) {
      case 'status_id':
        return true; // 狀態 ID 升序
      case 'updated_time':
        return false; // 更新時間降序（最新的在前）
      case 'relevance':
        return false; // 相關性降序（最相關的在前）
      case 'applicant_count':
        return false; // 應徵者數量降序（最多的在前）
      default:
        return false; // 預設降序
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
    _currentSortBy[_currentTabIndex] = 'status_id'; // 重置為狀態優先級排序
    _sortAscending[_currentTabIndex] = true; // 狀態ID升序
    _hasManualSortOverride[_currentTabIndex] = false; // 重置手動覆蓋標記
    _emit('criteria');
  }

  /// 更新某個分頁是否有未讀（供 Posted/MyWorks widget 設定）
  /// 添加防循環 + 防抖機制，避免連環通知造成無限刷新
  void setTabHasUnread(int tabIndex, bool value) {
    final prev = _tabHasUnread[tabIndex];
    // 若實際狀態未變更，直接忽略
    if (prev == value) {
      // debugPrint(
      //     '🔄 [ChatListProvider] 未讀狀態未改變，跳過通知: tab=$tabIndex, value=$value');
      return;
    }

    // 檢查時間間隔防抖
    final now = DateTime.now();
    final lastUpdate = _lastUnreadUpdate[tabIndex] ?? DateTime(1970);
    final timeDiff = now.difference(lastUpdate).inMilliseconds;

    if (timeDiff < 500) {
      // 500ms 內的重複更新被忽略
      debugPrint(
          '⏱️ [ChatListProvider] 時間防抖: tab=$tabIndex, 間隔=${timeDiff}ms < 500ms，跳過更新');
      return;
    }

    // 記錄待更新值
    _pendingTabUnread[tabIndex] = value;

    // 先取消舊的計時器
    _unreadDebounceTimers[tabIndex]?.cancel();

    // 啟動防抖計時器（避免抖動 true/false 快速切換）
    _unreadDebounceTimers[tabIndex] =
        Timer(const Duration(milliseconds: 250), () {
      // 防抖時間設為 250ms
      final pending = _pendingTabUnread[tabIndex];

      // 再次確認與目前值是否真的不同
      if (pending != null && pending != _tabHasUnread[tabIndex]) {
        _tabHasUnread[tabIndex] = pending;
        _lastUnreadUpdate[tabIndex] = DateTime.now(); // 更新最後更新時間
        debugPrint('✅ [ChatListProvider] 更新未讀狀態(防抖後): tab=$tabIndex, $pending');
        _emit('unread_update');
      } else {
        debugPrint('🔄 [ChatListProvider] 未讀狀態在防抖期間已一致，略過通知');
      }

      // 清理
      _pendingTabUnread[tabIndex] = null;
      _unreadDebounceTimers[tabIndex]?.cancel();
      _unreadDebounceTimers[tabIndex] = null;
    });
  }

  /// 房間級別未讀數管理方法
  /// 設置特定聊天室的未讀數
  void setUnreadForRoom(String roomId, int count) {
    // 確保 count 不為負數
    final safeCount = count < 0 ? 0 : count;
    final prev = _unreadByRoom[roomId] ?? 0;

    if (prev == safeCount) return;

    if (safeCount == 0) {
      // 移除 0 值項目以節省記憶體
      _unreadByRoom.remove(roomId);
      debugPrint('✅ [ChatListProvider] 移除房間未讀數: $roomId (設為0)');
    } else {
      _unreadByRoom[roomId] = safeCount;
      debugPrint(
          '✅ [ChatListProvider] 更新房間未讀數: $roomId = $safeCount (原: $prev)');
    }
    _emit('room_unread_update');
  }

  /// 增量更新房間未讀數
  void applyUnreadDelta(String roomId, int delta) {
    final current = _unreadByRoom[roomId] ?? 0;
    final newCount = (current + delta).clamp(0, 999); // 限制在 0-999 範圍
    setUnreadForRoom(roomId, newCount);
  }

  /// 將聊天室設為已讀
  void markRoomRead(String roomId) {
    setUnreadForRoom(roomId, 0);
  }

  /// 標記房間為已讀（別名方法，用於向後相容）
  void markRoomAsRead(String roomId) {
    markRoomRead(roomId);
  }

  /// 批量更新未讀數（用於初始化或同步）
  void updateUnreadByRoom(Map<String, int> unreadData) {
    debugPrint('🔍 [ChatListProvider] 批量更新未讀數請求: ${unreadData.length} 個房間');
    debugPrint(
        '🔍 [ChatListProvider] 調用堆疊: ${StackTrace.current.toString().split('\n').take(5).join('\n')}');

    bool hasChanges = false;
    int addedCount = 0;
    int updatedCount = 0;
    int totalUnread = 0;

    for (final entry in unreadData.entries) {
      final roomId = entry.key;
      final count = entry.value < 0 ? 0 : entry.value; // 確保不為負數
      final prev = _unreadByRoom[roomId] ?? 0;

      if (prev != count) {
        if (count == 0) {
          _unreadByRoom.remove(roomId);
        } else {
          _unreadByRoom[roomId] = count;
        }
        hasChanges = true;

        if (prev == 0) {
          addedCount++;
        } else {
          updatedCount++;
        }
      }

      totalUnread += count;
    }

    if (hasChanges) {
      debugPrint(
          '✅ [ChatListProvider] 批量更新完成: 新增=$addedCount, 更新=$updatedCount, 總未讀=$totalUnread');
      debugPrint('✅ [ChatListProvider] 當前房間總數: ${_unreadByRoom.length}');
      _emit('room_unread_update');
    } else {
      debugPrint('🔄 [ChatListProvider] 批量更新無變化: ${unreadData.length} 個房間');
    }
  }

  /// 使用快照覆蓋未讀數（全量替換，不保留舊房間）
  void replaceUnreadByRoom(Map<String, int> snapshot) {
    // debugPrint('🧹 [ChatListProvider] 準備以快照覆蓋未讀數: ${snapshot.length} 個房間');

    // 標準化新數據
    final normalizedSnapshot =
        snapshot.map((k, v) => MapEntry(k, v < 0 ? 0 : v));

    // 檢查是否有實際變化
    bool hasChanges = false;

    // 檢查房間數量是否變化
    if (_unreadByRoom.length != normalizedSnapshot.length) {
      hasChanges = true;
      debugPrint(
          '🔍 [ChatListProvider] 房間數量變化: ${_unreadByRoom.length} -> ${normalizedSnapshot.length}');
    }

    // 檢查每個房間的未讀數是否變化
    if (!hasChanges) {
      for (final entry in normalizedSnapshot.entries) {
        final roomId = entry.key;
        final newCount = entry.value;
        final oldCount = _unreadByRoom[roomId] ?? 0;

        if (oldCount != newCount) {
          hasChanges = true;
          debugPrint(
              '🔍 [ChatListProvider] 房間 $roomId 未讀數變化: $oldCount -> $newCount');
          break;
        }
      }
    }

    // 檢查是否有房間被移除
    if (!hasChanges) {
      for (final roomId in _unreadByRoom.keys) {
        if (!normalizedSnapshot.containsKey(roomId)) {
          hasChanges = true;
          debugPrint('🔍 [ChatListProvider] 房間 $roomId 被移除');
          break;
        }
      }
    }

    // 只有在有變化時才更新
    if (hasChanges) {
      debugPrint('✅ [ChatListProvider] 檢測到變化，執行快照覆蓋');
      // 全量替換，確保不在快照中的房間被移除
      _unreadByRoom
        ..clear()
        ..addAll(normalizedSnapshot);

      // 廣播更新
      _emit('room_unread_replace');
    } else {
      debugPrint('⏭️ [ChatListProvider] 未檢測到變化，跳過快照覆蓋');
    }
  }

  /// Socket 事件處理方法
  /// 處理 new_message 事件
  void handleNewMessage(String roomId) {
    applyUnreadDelta(roomId, 1);
    debugPrint('📨 [ChatListProvider] 新訊息事件: $roomId');
  }

  /// 處理 unread_update 事件
  void handleUnreadUpdate(String roomId, int count) {
    setUnreadForRoom(roomId, count);
    debugPrint('📊 [ChatListProvider] 未讀更新事件: $roomId = $count');
  }

  /// 處理進入聊天室事件
  void handleEnterChatRoom(String roomId) {
    markRoomRead(roomId);
    debugPrint('🚪 [ChatListProvider] 進入聊天室: $roomId');
  }

  /// 刷新 Posted Tasks 應徵數據
  Future<void> refreshPostedTasksApplications() async {
    debugPrint('🔄 [ChatListProvider] 開始刷新 Posted Tasks 應徵數據');

    // 清除現有的應徵數據快取
    _applicationsByTask.clear();

    // 重新載入 Posted Tasks 分頁數據
    await _loadTabData(tabPostedTasks);

    debugPrint('✅ [ChatListProvider] Posted Tasks 應徵數據刷新完成');
  }

  /// ID 綁定驗證方法
  /// 驗證 Posted Tasks 分頁的 ID 綁定
  bool isValidPostedTasksId(String id, String type) {
    switch (type) {
      case 'task':
        // 任務卡片應該綁定 task id
        return id.isNotEmpty && !id.startsWith('room_');
      case 'room':
        // 應徵者應該綁定 room id
        return id.isNotEmpty && id.startsWith('room_');
      default:
        return false;
    }
  }

  /// 驗證 My Works 分頁的 ID 綁定
  bool isValidMyWorksId(String id, String type) {
    switch (type) {
      case 'room':
        // My Works 任務卡片應該綁定 room id
        return id.isNotEmpty && id.startsWith('room_');
      default:
        return false;
    }
  }

  /// 獲取分頁的 ID 綁定規則
  Map<String, String> getTabIdBindingRules(int tabIndex) {
    switch (tabIndex) {
      case tabPostedTasks:
        return {
          'task_card': 'task_id',
          'applicant_card': 'room_id',
        };
      case tabMyWorks:
        return {
          'task_card': 'room_id',
        };
      default:
        return {};
    }
  }

  /// 檢查當前分頁狀態
  String getCurrentTabDescription() {
    switch (_currentTabIndex) {
      case tabPostedTasks:
        return 'Posted Tasks (任務列表)';
      case tabMyWorks:
        return 'My Works (我的應徵)';
      default:
        return 'Unknown Tab';
    }
  }

  /// 獲取分頁的數據載入狀態
  Map<String, dynamic> getTabDataStatus() {
    return {
      'current_tab': _currentTabIndex,
      'tab_description': getCurrentTabDescription(),
      'is_loading': _isLoading,
      'error_message': _errorMessage,
      'posted_tasks_count': _cacheManager.postedTasksCache.length,
      'my_works_count': _cacheManager.myWorksCache.length,
      'unread_rooms_count': _unreadByRoom.length,
      'tab_has_unread': {
        'posted_tasks': _tabHasUnread[tabPostedTasks] ?? false,
        'my_works': _tabHasUnread[tabMyWorks] ?? false,
      },
    };
  }

  /// 檢查快取數據是否可用於特定分頁
  bool isCacheReadyForTab(int tabIndex) {
    if (!_cacheManager.isCacheValid) return false;

    switch (tabIndex) {
      case tabPostedTasks:
        final hasPostedTasks = _cacheManager.postedTasksCache.isNotEmpty;
        debugPrint(
            '🔍 [Cache Check] Posted Tasks: $hasPostedTasks (${_cacheManager.postedTasksCache.length})');
        return hasPostedTasks;
      case tabMyWorks:
        final hasMyWorks = _cacheManager.myWorksCache.isNotEmpty;
        debugPrint(
            '🔍 [Cache Check] My Works: $hasMyWorks (${_cacheManager.myWorksCache.length})');
        return hasMyWorks;
      default:
        debugPrint('🔍 [Cache Check] Unknown tab: $tabIndex');
        return false;
    }
  }

  /// 強制刷新快取數據
  Future<void> forceRefreshCache() async {
    debugPrint('🔄 [ChatListProvider] 強制刷新快取數據...');
    await _cacheManager.forceRefresh();
    _emit('cache_refreshed');
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

      debugPrint('📊 快取初始化完成，檢查狀態:');
      debugPrint('  - 快取有效: ${_cacheManager.isCacheValid}');
      debugPrint('  - 快取為空: ${_cacheManager.isCacheEmpty}');
      debugPrint('  - Posted Tasks: ${_cacheManager.postedTasksCache.length}');
      debugPrint('  - My Works: ${_cacheManager.myWorksCache.length}');

      // 如果快取有效，直接使用快取數據
      if (_cacheManager.isCacheValid && !_cacheManager.isCacheEmpty) {
        debugPrint('✅ 快取有效，使用快取數據');

        // 將快取數據載入到本地狀態
        await _loadDataFromCache();

        // 不再設置全域 loading 狀態
        // setLoadingState(false);
        debugPrint('⚡ 快取載入完成！');
        debugPrint('📊 快取數據統計:');
        debugPrint(
            '  - Posted Tasks: ${_cacheManager.postedTasksCache.length}');
        debugPrint('  - My Works: ${_cacheManager.myWorksCache.length}');
        // debugPrint('  - 應徵者數據: ${_applicationsByTask.length} 個任務');

        // 進入頁面後輕量檢查更新
        _checkForUpdatesAfterEnter();
      } else {
        debugPrint('🔄 快取無效或為空，執行完整載入...');
        await _loadChatDataDeprecated();
      }
    } catch (e) {
      debugPrint('❌ 快取初始化失敗: $e');
      // 不再設置全域 loading 狀態
      // setLoadingState(false, e.toString());
    }
  }

  /// 從快取載入數據到本地狀態
  Future<void> _loadDataFromCache() async {
    try {
      debugPrint('📋 開始從快取載入數據...');

      // 載入 Posted Tasks 快取
      _applicationsByTask.clear();
      debugPrint(
          '📋 Posted Tasks 快取數據: ${_cacheManager.postedTasksCache.length} 個任務');

      for (final task in _cacheManager.postedTasksCache) {
        final taskId = task['id'].toString();
        debugPrint('📋 處理任務: $taskId');

        if (task['applications'] != null) {
          final applications =
              List<Map<String, dynamic>>.from(task['applications']);
          _applicationsByTask[taskId] = applications;
          debugPrint('📋 任務 $taskId: ${applications.length} 個應徵者');
        } else {
          debugPrint('📋 任務 $taskId: 無應徵者數據');
          // 即使沒有應徵者，也要記錄任務
          _applicationsByTask[taskId] = [];
        }
      }

      // 載入 My Works 快取
      debugPrint(
          '📋 My Works 快取數據: ${_cacheManager.myWorksCache.length} 個應徵記錄');
      for (final myWork in _cacheManager.myWorksCache) {
        debugPrint('📋 處理 My Work: ${myWork['id']} - ${myWork['title']}');
      }

      // 驗證快取數據完整性
      _validateCacheData();

      debugPrint('📋 快取數據載入完成:');
      debugPrint('  - Posted Tasks: ${_cacheManager.postedTasksCache.length}');
      debugPrint('  - My Works: ${_cacheManager.myWorksCache.length}');
      debugPrint('  - 應徵者數據: ${_applicationsByTask.length} 個任務有應徵者');

      // 調試：檢查 getter 方法的返回值
      debugPrint('🔍 [Debug] 檢查 getter 方法返回值:');
      debugPrint('  - postedTasks.length: ${postedTasks.length}');
      debugPrint(
          '  - filteredPostedTasks.length: ${filteredPostedTasks.length}');
      debugPrint(
          '  - myWorksApplications.length: ${myWorksApplications.length}');
      debugPrint('  - filteredMyWorks.length: ${filteredMyWorks.length}');
      debugPrint('  - currentTabData.length: ${currentTabData.length}');

      // 通知監聽者數據已載入
      _emit('cache_loaded');
    } catch (e) {
      debugPrint('❌ 快取數據載入失敗: $e');
    }
  }

  /// 驗證快取數據完整性
  void _validateCacheData() {
    debugPrint('🔍 [Cache Validation] 開始驗證快取數據...');

    // 驗證 Posted Tasks 快取
    if (_cacheManager.postedTasksCache.isNotEmpty) {
      debugPrint('✅ [Cache Validation] Posted Tasks 快取有效');
      for (final task in _cacheManager.postedTasksCache) {
        final taskId = task['id'];
        final hasApplications = task['applications'] != null;
        debugPrint('  - 任務 $taskId: 有應徵者數據 = $hasApplications');
      }
    } else {
      debugPrint('⚠️ [Cache Validation] Posted Tasks 快取為空');
    }

    // 驗證 My Works 快取
    if (_cacheManager.myWorksCache.isNotEmpty) {
      debugPrint('✅ [Cache Validation] My Works 快取有效');
      for (final myWork in _cacheManager.myWorksCache) {
        final workId = myWork['id'];
        final title = myWork['title'];
        debugPrint('  - My Work $workId: $title');
      }
    } else {
      debugPrint('⚠️ [Cache Validation] My Works 快取為空');
    }
  }

  /// 進入頁面後輕量檢查更新
  void _checkForUpdatesAfterEnter() {
    // TODO: 實現輕量更新檢查邏輯
    debugPrint('🔍 檢查數據更新...');
  }

  /// 同步載入所有聊天相關數據（已棄用，改用分頁級別載入）
  @Deprecated('Use tab-specific loading methods instead')
  Future<void> _loadChatDataDeprecated() async {
    try {
      debugPrint('🔄 [DEPRECATED] 開始同步載入聊天數據...');

      // 同步載入任務和狀態
      await Future.wait([
        TaskService().loadTasks(),
        TaskService().loadStatuses(),
      ]);
      debugPrint('✅ 任務列表載入完成');

      // 載入 Posted Tasks 應徵者數據
      await _loadApplicationsForPostedTasks();
      debugPrint('✅ Posted Tasks 應徵者資料載入完成');

      // 載入 My Works 應徵記錄數據
      await _loadMyWorksData();
      debugPrint('✅ My Works 應徵記錄資料載入完成');

      debugPrint('🎉 [DEPRECATED] 聊天數據載入完成！');
    } catch (e) {
      debugPrint('❌ [DEPRECATED] 聊天數據載入失敗: $e');
      // 不再設置全域 loading 狀態，改用分頁級別狀態
    }
  }

  /// 載入 Posted Tasks 的應徵者資料（使用聚合API提升效能）
  Future<void> _loadApplicationsForPostedTasks() async {
    try {
      final taskService = TaskService();

      // 獲取當前用戶ID作為creator_id
      final userService = UserService();
      final currentUserId = userService.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('❌ 無法獲取當前用戶ID，跳過應徵者載入');
        return;
      }

      // 檢查快取是否有效且不為空
      if (_cacheManager.isCacheValid &&
          _cacheManager.postedTasksCache.isNotEmpty) {
        debugPrint('🔍 [批次載入] 使用有效快取，跳過API請求');
        debugPrint(
            '🔍 [批次載入] 快取任務數量: ${_cacheManager.postedTasksCache.length}');

        // 從快取載入應徵者資料
        _applicationsByTask.clear();
        for (final task in _cacheManager.postedTasksCache) {
          final taskId = task['id'].toString();
          final applicants = task['applicants'] ?? [];

          final List<Map<String, dynamic>> applications = (applicants is List)
              ? applicants.map((e) => Map<String, dynamic>.from(e)).toList()
              : [];

          _applicationsByTask[taskId] = applications;
        }

        debugPrint('📄 [批次載入] 從快取載入完成: ${_applicationsByTask.length} 個任務有應徵者');
        return;
      }

      _applicationsByTask.clear();

      debugPrint('🔍 [批次載入] 開始使用聚合API載入Posted Tasks及應徵者資料');
      debugPrint('🔍 [批次載入] 用戶ID: $currentUserId');

      // 使用聚合API一次性載入所有任務及其應徵者資料
      final result = await taskService.fetchPostedTasksAggregated(
        limit: 1000, // 設置較大的限制以獲取所有任務
        offset: 0,
        creatorId: currentUserId.toString(),
      );

      final tasks = result.tasks;
      debugPrint('🔍 [批次載入] 聚合API返回 ${tasks.length} 個任務');

      // 注意：我們不再需要更新TaskService的內部任務列表
      // 因為我們直接使用聚合API返回的資料

      // 提取每個任務的應徵者資料
      for (final task in tasks) {
        final taskId = task['id'].toString();
        final applicants = task['applicants'] ?? [];

        // 確保applicants是List<Map<String, dynamic>>格式
        final List<Map<String, dynamic>> applications = (applicants is List)
            ? applicants.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];

        _applicationsByTask[taskId] = applications;

        if (applications.isNotEmpty) {
          debugPrint('🔍 [批次載入] 任務 $taskId: ${applications.length} 個應徵者');
        }
      }

      // 更新快取管理器的Posted Tasks資料
      await _cacheManager.updatePostedTasksCache(tasks);

      debugPrint('📄 [批次載入] 應徵者資料載入完成: ${_applicationsByTask.length} 個任務有應徵者');
      debugPrint('📊 [批次載入] 效能提升: 從 ${tasks.length} 個API請求減少到 1 個API請求');
      debugPrint(
          '💾 [批次載入] 已更新快取管理器: ${_cacheManager.postedTasksCache.length} 個任務');
    } catch (e) {
      debugPrint('❌ [批次載入] 載入應徵者資料失敗: $e');
      rethrow;
    }
  }

  /// 載入 My Works 的應徵記錄資料
  Future<void> _loadMyWorksData() async {
    try {
      final taskService = TaskService();

      // 創建 UserService 實例並等待初始化
      final userService = UserService();

      // 等待用戶服務初始化完成
      int retryCount = 0;
      const maxRetries = 3;

      while (userService.currentUser?.id == null && retryCount < maxRetries) {
        debugPrint('🔄 等待用戶服務初始化，嘗試 $retryCount/$maxRetries');
        await Future.delayed(const Duration(milliseconds: 500));
        retryCount++;
      }

      final currentUserId = userService.currentUser?.id;

      debugPrint('🔍 開始載入 My Works 資料，用戶 ID: $currentUserId');

      // 檢查用戶 ID 是否有效
      if (currentUserId == null) {
        debugPrint('❌ 用戶服務初始化失敗，用戶 ID 仍為 null');
        throw Exception('用戶未登入或 ID 無效，請檢查登入狀態');
      }

      // 調用 API 載入用戶的應徵記錄
      debugPrint(
          '🔍 [ChatListProvider] 開始調用 TaskService.loadMyApplications($currentUserId)');
      await taskService.loadMyApplications(currentUserId);
      debugPrint('🔍 [ChatListProvider] TaskService.loadMyApplications 完成');
      debugPrint(
          '🔍 [ChatListProvider] TaskService.myApplications 長度: ${taskService.myApplications.length}');

      // 將數據載入到本地快取
      _myWorksApplications.clear();
      _myWorksApplications.addAll(taskService.myApplications);

      debugPrint('✅ My Works 資料載入完成');
      debugPrint('📊 My Works 統計: ${_myWorksApplications.length} 個應徵記錄');

      // 即使沒有應徵記錄，也標記為載入完成
      if (taskService.myApplications.isEmpty) {
        debugPrint('⚠️ 沒有應徵記錄，但標記為載入完成');
      }
    } catch (e) {
      debugPrint('❌ 載入 My Works 資料失敗: $e');
      rethrow; // 重新拋出異常，讓上層處理
    }
  }

  /// 強制刷新所有數據（已棄用，改用分頁級別刷新）
  @Deprecated('Use tab-specific refresh methods instead')
  Future<void> forceRefresh() async {
    debugPrint('🔄 [DEPRECATED] 強制刷新所有數據');

    // 設置全域 loading 狀態
    setLoadingState(true);

    try {
      await _cacheManager.forceRefresh();

      // 刷新所有分頁的數據
      for (int tabIndex = 0; tabIndex < 2; tabIndex++) {
        debugPrint('🔄 [DEPRECATED] 刷新分頁 $tabIndex 數據');
        setTabLoaded(tabIndex, false); // 重置載入完成狀態
        setTabError(tabIndex, null); // 清除錯誤狀態
        checkAndTriggerTabLoad(tabIndex);
      }
    } finally {
      // 保證全域 loading 狀態被關閉
      setLoadingState(false);
      debugPrint('🔄 [DEPRECATED] 全域 loading 狀態已關閉');
    }
  }

  /// 刷新指定分頁的數據
  Future<void> refreshTab(int tabIndex) async {
    if (tabIndex < 0 || tabIndex >= 2) {
      debugPrint('❌ [ChatListProvider] 無效的分頁索引: $tabIndex');
      return;
    }

    debugPrint('🔄 [ChatListProvider] 刷新分頁 $tabIndex 數據');

    // 重置分頁狀態
    setTabLoaded(tabIndex, false);
    setTabError(tabIndex, null);

    // 觸發重新載入
    checkAndTriggerTabLoad(tabIndex);
  }

  /// 刷新當前分頁的數據
  Future<void> refreshCurrentTab() async {
    refreshTab(_currentTabIndex);
  }

  /// 精確更新特定任務的狀態（避免全量刷新）
  void updateTaskStatus(String taskId, Map<String, dynamic> updatedTask) {
    debugPrint('🔄 [ChatListProvider] 精確更新任務狀態: $taskId');

    bool hasUpdates = false;

    // 更新 Posted Tasks 快取中的任務
    for (int i = 0; i < _cacheManager.postedTasksCache.length; i++) {
      if (_cacheManager.postedTasksCache[i]['id'].toString() == taskId) {
        _cacheManager.postedTasksCache[i] = {
          ..._cacheManager.postedTasksCache[i],
          ...updatedTask,
        };
        hasUpdates = true;
        debugPrint('✅ [ChatListProvider] 已更新 Posted Tasks 快取中的任務 $taskId');
        break;
      }
    }

    // 更新 My Works 快取中的任務
    for (int i = 0; i < _myWorksApplications.length; i++) {
      if (_myWorksApplications[i]['task_id'].toString() == taskId) {
        _myWorksApplications[i] = {
          ..._myWorksApplications[i],
          ...updatedTask,
        };
        hasUpdates = true;
        debugPrint('✅ [ChatListProvider] 已更新 My Works 快取中的任務 $taskId');
        break;
      }
    }

    if (hasUpdates) {
      _emit('task_status_updated');
      debugPrint('✅ [ChatListProvider] 任務狀態更新完成，已通知監聽者');
    } else {
      debugPrint('⚠️ [ChatListProvider] 未找到任務 $taskId，無法更新');
    }
  }

  /// 精確更新特定應徵者的狀態
  void updateApplicantStatus(String taskId, String applicantUserId,
      Map<String, dynamic> updatedApplicant) {
    debugPrint(
        '🔄 [ChatListProvider] 精確更新應徵者狀態: 任務=$taskId, 應徵者=$applicantUserId');

    bool hasUpdates = false;

    // 更新 Posted Tasks 的應徵者數據
    if (_applicationsByTask.containsKey(taskId)) {
      final applicants = _applicationsByTask[taskId]!;
      for (int i = 0; i < applicants.length; i++) {
        if (applicants[i]['user_id'].toString() == applicantUserId) {
          applicants[i] = {
            ...applicants[i],
            ...updatedApplicant,
          };
          hasUpdates = true;
          debugPrint('✅ [ChatListProvider] 已更新應徵者 $applicantUserId 的狀態');
          break;
        }
      }
    }

    // 同時更新 Posted Tasks 快取中的應徵者數據
    for (final task in _cacheManager.postedTasksCache) {
      if (task['id'].toString() == taskId && task['applicants'] != null) {
        final applicants = task['applicants'] as List;
        for (int i = 0; i < applicants.length; i++) {
          if (applicants[i]['user_id'].toString() == applicantUserId) {
            applicants[i] = {
              ...applicants[i],
              ...updatedApplicant,
            };
            hasUpdates = true;
            debugPrint('✅ [ChatListProvider] 已更新快取中應徵者 $applicantUserId 的狀態');
            break;
          }
        }
        break;
      }
    }

    if (hasUpdates) {
      _emit('applicant_status_updated');
      debugPrint('✅ [ChatListProvider] 應徵者狀態更新完成，已通知監聽者');
    } else {
      debugPrint('⚠️ [ChatListProvider] 未找到應徵者 $applicantUserId，無法更新');
    }
  }

  /// 精確更新聊天室相關數據（如未讀數、最新訊息等）
  void updateChatRoomData(String roomId, Map<String, dynamic> updatedData) {
    debugPrint('🔄 [ChatListProvider] 精確更新聊天室數據: $roomId');

    bool hasUpdates = false;

    // 更新未讀數
    if (updatedData.containsKey('unread_count')) {
      final unreadCount = updatedData['unread_count'] as int;
      setUnreadForRoom(roomId, unreadCount);
      hasUpdates = true;
    }

    // 更新 My Works 中的聊天室數據
    for (int i = 0; i < _myWorksApplications.length; i++) {
      if (_myWorksApplications[i]['chat_room_id'].toString() == roomId) {
        _myWorksApplications[i] = {
          ..._myWorksApplications[i],
          ...updatedData,
        };
        hasUpdates = true;
        debugPrint('✅ [ChatListProvider] 已更新 My Works 中聊天室 $roomId 的數據');
        break;
      }
    }

    // 更新 Posted Tasks 中的應徵者聊天室數據
    for (final applicants in _applicationsByTask.values) {
      for (int i = 0; i < applicants.length; i++) {
        if (applicants[i]['chat_room_id'].toString() == roomId) {
          applicants[i] = {
            ...applicants[i],
            ...updatedData,
          };
          hasUpdates = true;
          debugPrint('✅ [ChatListProvider] 已更新 Posted Tasks 中聊天室 $roomId 的數據');
          break;
        }
      }
    }

    if (hasUpdates) {
      _emit('chat_room_updated');
      debugPrint('✅ [ChatListProvider] 聊天室數據更新完成，已通知監聽者');
    }
  }

  /// 批量更新多個項目（用於複雜操作）
  void batchUpdate(List<Map<String, dynamic>> updates) {
    debugPrint('🔄 [ChatListProvider] 開始批量更新: ${updates.length} 個項目');

    for (final update in updates) {
      final type = update['type'] as String;
      switch (type) {
        case 'task':
          updateTaskStatus(update['id'], update['data']);
          break;
        case 'applicant':
          updateApplicantStatus(
              update['task_id'], update['user_id'], update['data']);
          break;
        case 'chat_room':
          updateChatRoomData(update['room_id'], update['data']);
          break;
      }
    }

    debugPrint('✅ [ChatListProvider] 批量更新完成');
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

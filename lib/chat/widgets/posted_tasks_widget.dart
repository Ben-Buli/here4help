import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/permission_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:here4help/chat/services/chat_navigation_service.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:here4help/chat/services/chat_preload_service.dart';
import 'package:here4help/chat/widgets/highlighted_text.dart';
import 'package:here4help/chat/widgets/cached_avatar_widget.dart';
import 'package:here4help/chat/utils/avatar_cache_manager.dart';

const bool verboseSearchLog = false; // 控制搜尋相關的詳細日誌

/// Posted Tasks 組件
/// 從原 ChatListPage 中抽取的 Posted Tasks 相關功能
class PostedTasksWidget extends StatefulWidget {
  const PostedTasksWidget({super.key});

  @override
  State<PostedTasksWidget> createState() => _PostedTasksWidgetState();
}

class _PostedTasksWidgetState extends State<PostedTasksWidget>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 20;
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 0);
  // 任務數據
  final List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredTasks = []; // 新增：篩選後的任務
  List<Map<String, dynamic>> _sortedTasks = []; // 新增：排序後的任務

  // Pin 功能相關狀態
  final Set<String> _pinnedTaskIds = {}; // 已釘選的任務 ID

  /// 臨時偵錯方法 - 用於追蹤 widget 生命週期
  void _guard(String tag) {
    assert(() {
      // debugPrint('🧪 GUARD $tag | mounted=$mounted');
      return true;
    }());
  }

  @override
  void initState() {
    super.initState();
    // 分頁監聽（移入既有 initState，避免重複定義）
    _pagingController.addPageRequestListener((offset) {
      _fetchPostedTasksPage(offset);
    });
    // 首次進入時主動載入第一頁
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pagingController.refresh();
    });

    // 初始化未讀數據監聽器
    _setupUnreadListener();

    // 統一設置 Provider 監聽器（避免重複設置）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 安全地獲取 Provider
      ChatListProvider? chatProvider;
      try {
        chatProvider = _getChatProvider();
      } catch (e) {
        debugPrint(
            '⚠️ [Posted Tasks][initState] 無法獲取 ChatListProvider，跳過監聽器設置');
        return;
      }

      // 設置 Provider 變化監聽器
      chatProvider?.addListener(_handleProviderChanges);

      // 檢查 Provider 是否已初始化
      if (chatProvider?.isInitialized == true) {
        debugPrint('✅ [Posted Tasks] Provider 已初始化，檢查分頁狀態');
        _checkAndLoadIfNeeded();
      } else {
        debugPrint('⏳ [Posted Tasks] Provider 未初始化，等待初始化完成');
        // 等待 Provider 初始化完成
        _initializationListener = () {
          if (!mounted) return;
          if (chatProvider?.isInitialized == true) {
            debugPrint('✅ [Posted Tasks] Provider 初始化完成，檢查分頁狀態');
            _checkAndLoadIfNeeded();
          }
        };
        chatProvider?.addListener(_initializationListener!);
      }

      // 監聽快取載入完成事件
      _cacheLoadListener = () {
        if (!mounted) return;
        if ((chatProvider?.lastEvent) == 'cache_loaded') {
          debugPrint('📡 [Posted Tasks] 收到快取載入完成事件，重新載入數據');
          _fetchAllTasks();
        }
        // 新增：監聽分頁載入完成事件（tab_loaded_0），載入任務清單
        if ((chatProvider?.lastEvent) == 'tab_loaded_0') {
          debugPrint('📡 [Posted Tasks] 分頁載入完成 (tab_loaded_0)，載入任務清單');
          _fetchAllTasks();
        }
      };
      chatProvider?.addListener(_cacheLoadListener!);
    });
  }

  /// 檢查並按需載入數據
  void _checkAndLoadIfNeeded() {
    if (!mounted) return;

    // 使用輔助方法安全地獲取 Provider
    final chatProvider = _getChatProvider();
    if (chatProvider == null) {
      debugPrint(
          '⚠️ [Posted Tasks][_checkAndLoadIfNeeded()] 無法獲取 ChatListProvider，跳過載入檢查');
      return;
    }

    // 檢查 Provider 是否已初始化
    if (!chatProvider.isInitialized) {
      debugPrint('⏳ [Posted Tasks] Provider 尚未初始化，跳過載入檢查');
      return;
    }

    // 檢查當前是否為 Posted Tasks 分頁且可見
    if (chatProvider.isPostedTasksTab) {
      debugPrint('🔍 [Posted Tasks] 當前為 Posted Tasks 分頁，檢查載入狀態');
      debugPrint(
          '  - 分頁載入狀態: ${chatProvider.isTabLoading(ChatListProvider.tabPostedTasks)}');
      debugPrint(
          '  - 分頁載入完成: ${chatProvider.isTabLoaded(ChatListProvider.tabPostedTasks)}');
      debugPrint(
          '  - 分頁錯誤: ${chatProvider.getTabError(ChatListProvider.tabPostedTasks)}');

      // 如果分頁尚未載入且不在載入中，觸發載入
      if (!chatProvider.isTabLoaded(ChatListProvider.tabPostedTasks) &&
          !chatProvider.isTabLoading(ChatListProvider.tabPostedTasks)) {
        debugPrint('🚀 [Posted Tasks] 觸發分頁數據載入');

        // 先觸發 Provider 的載入
        chatProvider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);

        // 同時直接載入任務數據
        debugPrint('🚀 [Posted Tasks] 直接調用 _fetchAllTasks() 載入任務數據');
        _fetchAllTasks();
      } else {
        debugPrint('✅ [Posted Tasks] 分頁已載入或正在載入中');

        // 即使分頁已載入，也要檢查本地任務數據是否需要更新
        if (_allTasks.isEmpty) {
          debugPrint('🔄 [Posted Tasks] 分頁已載入但本地任務數據為空，重新載入任務數據');
          _fetchAllTasks();
        }
      }
    } else {
      debugPrint('⏸️ [Posted Tasks] 當前不是 Posted Tasks 分頁，跳過載入');
    }
  }

  // 應徵者數據
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // 載入狀態（已棄用，改用 Provider 的分頁狀態）
  // bool _isLoading = true;
  // String? _error;

  // 展開狀態
  final Set<String> _expandedTaskIds = {};

  // 篩選條件追蹤
  String _lastSearchQuery = '';
  Set<String> _lastSelectedLocations = {};
  Set<String> _lastSelectedStatuses = {};

  // Provider 監聽器
  StreamSubscription<Map<String, int>>? _unreadSub;

  // 匿名監聽器的引用，用於在 dispose 時移除
  VoidCallback? _initializationListener;
  VoidCallback? _cacheLoadListener;

  @override
  bool get wantKeepAlive => true;

  /// 安全地獲取 ChatListProvider
  ChatListProvider? _getChatProvider() {
    if (!mounted) return null;

    // 先嘗試使用靜態實例，避免在 deactivated 階段透過 context 查找祖先
    final staticInstance = ChatListProvider.instance;
    if (staticInstance != null) {
      return staticInstance;
    }

    // 檢查 widget 是否仍然在 widget tree 中
    if (!mounted) return null;

    // 額外檢查：確保 context 仍然有效
    try {
      if (!context.mounted) return null;
    } catch (e) {
      // context 可能已經無效
      return null;
    }

    // 回退：僅在需要時才透過 context 取得，降低在 deactivated 階段觸發錯誤的機率
    try {
      return Provider.of<ChatListProvider>(context, listen: false);
    } catch (e) {
      debugPrint('⚠️ [Posted Tasks] 無法獲取 ChatListProvider: $e');
      return null;
    }
  }

  void _updatePostedTabUnreadFlag() {
    if (!mounted) return;

    try {
      // 計算當前未讀狀態
      bool hasUnread = false;

      // 使用輔助方法安全地獲取 Provider
      final provider = _getChatProvider();
      if (provider == null) return;

      for (final appliers in _applicationsByTask.values) {
        for (final ap in appliers) {
          final roomId = ap['chat_room_id']?.toString();
          if (roomId != null && roomId.isNotEmpty) {
            final cnt = provider.unreadForRoom(roomId);
            if (cnt > 0) {
              hasUnread = true;
              break;
            }
          }
        }
        if (hasUnread) break;
      }

      final oldState =
          provider.hasUnreadForTab(ChatListProvider.tabPostedTasks);

      // 只有狀態真正改變時才更新
      if (oldState != hasUnread) {
        if (kDebugMode && verboseSearchLog) {
          debugPrint('🔄 [Posted Tasks] 未讀狀態變化: $oldState -> $hasUnread');
        }

        // 使用 addPostFrameCallback 避免在 build 過程中調用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            // 再次檢查 mounted 狀態
            if (!mounted) return;

            // 安全地獲取 Provider
            ChatListProvider? safeProvider;
            try {
              safeProvider = _getChatProvider();
            } catch (e) {
              debugPrint('⚠️ [Posted Tasks] PostFrame 中無法獲取 ChatListProvider');
              return;
            }

            safeProvider?.setTabHasUnread(
                ChatListProvider.tabPostedTasks, hasUnread);
          } catch (e) {
            debugPrint('❌ [Posted Tasks] 設置未讀狀態失敗: $e');
          }
        });
      } else {
        if (kDebugMode && verboseSearchLog) {
          debugPrint('🔄 [Posted Tasks] 未讀狀態未改變，跳過更新: $hasUnread');
        }
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 更新 Tab 未讀狀態失敗: $e');
    }
  }

  /// 設置未讀數據監聽器
  void _setupUnreadListener() {
    try {
      // 移除重複監聽：NotificationCenter 已自動同步到 Provider
      // 只監聽未讀數據變化來更新 Tab 標記
      _unreadSub = NotificationCenter().byRoomStream.listen((unreadData) {
        if (!mounted) return;

        if (kDebugMode && verboseSearchLog) {
          debugPrint('📡 [Posted Tasks] 收到未讀數據更新: ${unreadData.length} 個房間');
        }

        // 只更新 Tab 未讀標記，不重複呼叫 replaceUnreadByRoom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          _updatePostedTabUnreadFlag();
        });
      });
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 設置未讀監聽器失敗: $e');
    }
  }

  /// 預載入聊天室數據
  void _preloadChatData() {
    try {
      // 收集所有有聊天室的應徵者
      final roomIds = <String>[];
      for (final appliers in _applicationsByTask.values) {
        for (final applier in appliers) {
          final roomId = applier['chat_room_id']?.toString();
          if (roomId != null && roomId.isNotEmpty) {
            roomIds.add(roomId);
          }
        }
      }

      if (roomIds.isNotEmpty) {
        debugPrint('🚀 [Posted Tasks] 開始預載入 ${roomIds.length} 個聊天室數據');
        ChatPreloadService.preloadMultipleChatData(roomIds);
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 預載入聊天室數據失敗: $e');
    }
  }

  /// 預載入頭像數據
  void _preloadAvatars() {
    try {
      final avatarPaths = <String>[];

      // 收集所有應徵者的頭像路徑
      for (final appliers in _applicationsByTask.values) {
        for (final applier in appliers) {
          final avatarPath = applier['applier_avatar']?.toString();
          if (avatarPath != null &&
              avatarPath.isNotEmpty &&
              !avatarPaths.contains(avatarPath)) {
            avatarPaths.add(avatarPath);
          }
        }
      }

      if (avatarPaths.isNotEmpty) {
        debugPrint('🚀 [Posted Tasks] 開始預載入 ${avatarPaths.length} 個頭像');
        AvatarCacheManager.preloadAvatars(avatarPaths);
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 預載入頭像失敗: $e');
    }
  }

  /// 載入應徵者數據
  Future<void> _loadApplicantsData() async {
    try {
      debugPrint('🔍 [Posted Tasks] 開始載入應徵者數據，總任務數: ${_allTasks.length}');

      // 清空舊數據
      _applicationsByTask.clear();

      // 直接從任務數據中提取應徵者信息（API 已聚合）
      for (final task in _allTasks) {
        final taskId = task['id'].toString();
        final applicantsRaw = task['applicants'] ?? [];

        // debugPrint('🔍 [Posted Tasks] 任務 $taskId 的原始應徵者數據: $applicantsRaw');

        final List<Map<String, dynamic>> applicants = (applicantsRaw is List)
            ? applicantsRaw.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];

        _applicationsByTask[taskId] = applicants;

        // debugPrint(
        //     '🔍 [Posted Tasks] 任務 $taskId 處理後應徵者數量: ${applicants.length}');

        // 調試：顯示應徵者詳細信息
        for (int i = 0; i < applicants.length; i++) {
          final applicant = applicants[i];
          // debugPrint(
          //     '  - 應徵者 $i: ${applicant['applier_name']} (ID: ${applicant['user_id']})');
          // debugPrint('    - 評分: ${applicant['avg_rating']}');
          // debugPrint('    - 評論數: ${applicant['review_count']}');
          // debugPrint('    - 聊天室ID: ${applicant['chat_room_id']}');
          // debugPrint('    - 申請狀態: ${applicant['application_status']}');
          // debugPrint(
          //     '    - 申請信: ${applicant['cover_letter']?.toString().substring(0, math.min(50, applicant['cover_letter']?.toString().length ?? 0))}...');
        }
      }

      // debugPrint (
      // '📄 [Posted Tasks] 應徵者資料載入完成: ${_applicationsByTask.length} 個任務有應徵者');

      // 驗證資料對接的完整性
      debugPrint('🔍 [Posted Tasks] 資料對接驗證:');
      for (final entry in _applicationsByTask.entries) {
        final taskId = entry.key;
        final applicants = entry.value;
        // debugPrint('  - 任務 $taskId: ${applicants.length} 個應徵者');

        // 檢查每個應徵者的必要欄位
        final List<Map<String, dynamic>> applicantData = [];
        for (int i = 0; i < applicants.length; i++) {
          final applicant = applicants[i];
          final requiredFields = [
            'user_id',
            'applier_name',
            'avg_rating',
            'review_count',
            'chat_room_id'
          ];
          final missingFields = requiredFields
              .where((field) => applicant[field] == null)
              .toList();

          if (missingFields.isNotEmpty) {
            applicantData.add({
              'missingFields': '❌ 應徵者 $i 缺少欄位: $missingFields',
              'ApplicantDataComplete': false
            });
          } else {
            applicantData.add({'ApplicantDataComplete': true});
          }
        }
        debugPrint('🔍 [Posted Tasks] 應徵者資料載入完成: $applicantData');
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 載入應徵者數據失敗: $e');
    }
  }

  /// 確保未讀數據已載入
  Future<void> _ensureUnreadDataLoaded() async {
    try {
      if (kDebugMode && verboseSearchLog) {
        debugPrint('🔄 [Posted Tasks] 開始載入未讀數據...');
      }

      // 等待 NotificationCenter 初始化完成
      await NotificationCenter().waitForUnreadData();

      // NotificationCenter 會自動同步到 Provider，無需手動呼叫 replaceUnreadByRoom
      if (kDebugMode && verboseSearchLog) {
        debugPrint('✅ [Posted Tasks] 未讀數據載入完成');
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 未讀數據載入失敗: $e');
    }
  }

  void _handleProviderChanges() {
    if (!mounted) return;

    try {
      final chatProvider = _getChatProvider();
      if (chatProvider == null) {
        debugPrint(
            '⚠️ [Posted Tasks][_handleProviderChanges()] 無法獲取 ChatListProvider，跳過變化處理');
        return;
      }

      // 只有當前是 Posted Tasks 分頁時才刷新
      if (chatProvider.isPostedTasksTab == true) {
        // 檢查是否為 unread_update 事件，如果是則跳過篩選刷新
        if (chatProvider.lastEvent == 'unread_update') {
          debugPrint('🔄 [Posted Tasks] 跳過 unread_update 事件觸發的篩選刷新');
          return;
        }
        final currentSearchQuery = chatProvider.searchQuery;
        final currentLocations =
            Set<String>.from(chatProvider.selectedLocations);
        final currentStatuses = Set<String>.from(chatProvider.selectedStatuses);

        if (kDebugMode && verboseSearchLog) {
          debugPrint('🔄 [Posted Tasks] Provider 變化檢測:');
          debugPrint('  - 當前搜尋查詢: "$currentSearchQuery"');
          debugPrint('  - 上次搜尋查詢: "$_lastSearchQuery"');
          debugPrint('  - 搜尋查詢變化: ${currentSearchQuery != _lastSearchQuery}');
          debugPrint('  - 有活躍篩選: ${chatProvider.hasActiveFilters}');
          debugPrint('  - 選中位置: $currentLocations');
          debugPrint('  - 選中狀態: $currentStatuses');
        }

        // 檢查是否有實際變化
        final hasSearchChanged = currentSearchQuery != _lastSearchQuery;
        final hasLocationChanged =
            currentLocations.length != _lastSelectedLocations.length ||
                !currentLocations
                    .every((loc) => _lastSelectedLocations.contains(loc));
        final hasStatusChanged =
            currentStatuses.length != _lastSelectedStatuses.length ||
                !currentStatuses
                    .every((status) => _lastSelectedStatuses.contains(status));

        if (hasSearchChanged || hasLocationChanged || hasStatusChanged) {
          if (kDebugMode && verboseSearchLog) {
            debugPrint('✅ [Posted Tasks] 檢測到篩選條件變化，觸發刷新');
          }

          // 更新追蹤狀態
          _lastSearchQuery = currentSearchQuery;
          _lastSelectedLocations = currentLocations;
          _lastSelectedStatuses = currentStatuses;

          // 搜尋和篩選互斥邏輯：執行其中一個時重設另一個
          if (hasSearchChanged && currentSearchQuery.isNotEmpty) {
            // 有搜尋查詢時，清空篩選條件
            if (kDebugMode && verboseSearchLog) {
              debugPrint('🔍 [Posted Tasks] 搜尋查詢變化，清空篩選條件');
            }
            // 只清空篩選條件，不清空搜尋查詢
            chatProvider.updateLocationFilter({});
            chatProvider.updateStatusFilter({});
          } else if (hasLocationChanged || hasStatusChanged) {
            // 有篩選條件變化時，清空搜尋查詢
            if (kDebugMode && verboseSearchLog) {
              debugPrint('🔍 [Posted Tasks] 篩選條件變化，清空搜尋查詢');
            }
            chatProvider.setSearchQuery('');
          }

          // 重新應用篩選和排序
          _applyFiltersAndSort();
        } else {
          if (kDebugMode && verboseSearchLog) {
            debugPrint('🔄 [Posted Tasks] 無篩選條件變化，跳過刷新');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] Provider 變化處理失敗: $e');
    }
  }

  /// 應用篩選和排序（不重新載入數據）
  void _applyFiltersAndSort() {
    if (!mounted) return;

    try {
      debugPrint('🔍 [Posted Tasks] [_applyFiltersAndSort()] 開始應用篩選和排序');
      debugPrint('  - 輸入 _allTasks 長度: ${_allTasks.length}');

      ChatListProvider? chatProvider;
      try {
        chatProvider = _getChatProvider();
      } catch (e) {
        debugPrint(
            '⚠️ [Posted Tasks][_applyFiltersAndSort()] 無法獲取 ChatListProvider，跳過篩選和排序');
        return;
      }

      // 應用篩選
      final filteredTasks = _filterTasks(_allTasks, chatProvider!);
      debugPrint('🔍 [Posted Tasks] [_applyFiltersAndSort()] 篩選完成:');
      // debugPrint('  - 篩選後任務數: ${filteredTasks.length}');

      // 應用排序
      final sortedTasks = _sortTasks(filteredTasks, chatProvider);
      debugPrint('🔍 [Posted Tasks] [_applyFiltersAndSort()] 排序完成:');
      // debugPrint('  - 排序後任務數: ${sortedTasks.length}');

      debugPrint('🔍 [Posted Tasks] [_applyFiltersAndSort()] 篩選和排序完成:');
      // debugPrint('  - 原始任務數: ${_allTasks.length}');
      // debugPrint('  - 篩選後任務數: ${filteredTasks.length}');
      // debugPrint('  - 排序後任務數: ${sortedTasks.length}');

      // 更新狀態
      setState(() {
        _filteredTasks = filteredTasks;
        _sortedTasks = sortedTasks;
        debugPrint('🔍 [Posted Tasks] [_applyFiltersAndSort()] 狀態已更新');
        // debugPrint('  - _filteredTasks 長度: ${_filteredTasks.length}');
        // debugPrint('  - _sortedTasks 長度: ${_sortedTasks.length}');
      });
    } catch (e) {
      debugPrint('❌ [Posted Tasks] [_applyFiltersAndSort()] 篩選和排序失敗: $e');
    }
  }

  @override
  void dispose() {
    // 分頁控制器
    try {
      _pagingController.dispose();
    } catch (_) {}

    // 安全地移除 provider listener（避免在 dispose 中訪問 context）
    try {
      // 使用靜態實例而不是 context
      final chatProvider = ChatListProvider.instance;
      if (chatProvider != null) {
        chatProvider.removeListener(_handleProviderChanges);

        // 移除匿名監聽器
        if (_initializationListener != null) {
          chatProvider.removeListener(_initializationListener!);
          _initializationListener = null;
        }
        if (_cacheLoadListener != null) {
          chatProvider.removeListener(_cacheLoadListener!);
          _cacheLoadListener = null;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [Posted Tasks] 移除 Provider 監聽器失敗: $e');
    }

    // 取消未讀數據訂閱
    _unreadSub?.cancel();
    _unreadSub = null;

    super.dispose();
  }

  /// 一次讀取所有任務
  Future<void> _fetchAllTasks() async {
    try {
      // debugPrint  ('🔍 [Posted Tasks] [_fetchAllTasks()] 開始從 API 獲取任務');

      // 安全地獲取 Provider
      final chatProvider = _getChatProvider();
      if (chatProvider == null) {
        debugPrint(
            '⚠️ [Posted Tasks][_fetchAllTasks()] 無法獲取 ChatListProvider，跳過任務獲取');
        return;
      }

      // 安全地獲取 UserService
      UserService? userService;
      try {
        userService = context.read<UserService>();
      } catch (e) {
        debugPrint(
            '⚠️ [Posted Tasks][_fetchAllTasks()] 無法獲取 UserService，跳過任務獲取');
        return;
      }

      final currentUserId = userService.currentUser?.id;
      // debugPrint(
      //     '🔍 [Posted Tasks] [_fetchAllTasks()] 當前用戶 ID: $currentUserId');

      if (currentUserId == null) {
        debugPrint('❌ [Posted Tasks] [_fetchAllTasks()] 用戶未登入，無法獲取任務');
        return;
      }

      debugPrint(
          '🔍 [Posted Tasks] [_fetchAllTasks()] 調用 TaskService.fetchPostedTasksAggregated()');

      // 調用新的聚合 API
      final result = await TaskService().fetchPostedTasksAggregated(
        creatorId: currentUserId.toString(),
        limit: 50,
        offset: 0,
      );

      // debugPrint('🔍 [Posted Tasks] [_fetchAllTasks()] API 返回結果:');
      // debugPrint('  - 任務數量: ${result.tasks.length}');
      // debugPrint('  - 是否有更多: ${result.hasMore}');
      if (result.tasks.isNotEmpty) {
        // debugPrint('  - 第一個任務 ID: ${result.tasks.first['id']}');
        // debugPrint('  - 第一個任務標題: ${result.tasks.first['title']}');

        // 檢查第一個任務的應徵者數據
        final firstTask = result.tasks.first;
        final firstTaskApplicants = firstTask['applicants'] ?? [];
        // debugPrint('  - 第一個任務應徵者數量: ${firstTaskApplicants.length}');

        if (firstTaskApplicants.isNotEmpty) {
          // debugPrint('  - 第一個任務應徵者詳細信息:');
          for (int i = 0; i < firstTaskApplicants.length; i++) {
            final applicant = firstTaskApplicants[i];
            debugPrint('    - 應徵者 $i:');
            debugPrint('      - 用戶ID: ${applicant['user_id']}');
            // debugPrint('      - 姓名: ${applicant['applier_name']}');
            // debugPrint('      - 評分: ${applicant['avg_rating']}');
            // debugPrint('      - 評論數: ${applicant['review_count']}');
            // debugPrint('      - 聊天室ID: ${applicant['chat_room_id']}');
            // debugPrint('      - 申請狀態: ${applicant['application_status']}');
            // debugPrint('      - 所有欄位: ${applicant.keys.toList()}');
          }
        } else {
          debugPrint('  - 第一個任務沒有應徵者');
        }
      }

      if (mounted) {
        // 將數據載入到 ChatListProvider 的快取中
        chatProvider.replacePostedTasksAggregated(result.tasks,
            markLoaded: true);

        setState(() {
          _allTasks.clear();
          _allTasks.addAll(result.tasks);
          debugPrint(
              '🔍 [Posted Tasks] [_fetchAllTasks()] 已更新 ChatListProvider 快取和本地 _allTasks，長度: ${_allTasks.length}');
        });

        // 載入應徵者數據
        // ChatListProvider 已同步資料，此處僅處理視覺前置任務
        await _loadApplicantsData();

        // 預載入聊天室數據
        _preloadChatData();

        // 預載入頭像
        _preloadAvatars();

        debugPrint('🔍 [Posted Tasks] [_fetchAllTasks()] 任務獲取完成');
        debugPrint(
            '  - ChatListProvider 快取長度: ${chatProvider.postedTasks.length}');
        debugPrint('  - 篩選後任務長度: ${chatProvider.filteredPostedTasks.length}');
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] [_fetchAllTasks()] 獲取任務失敗: $e');
    }
  }

  /// 篩選任務列表
  List<Map<String, dynamic>> _filterTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    if (kDebugMode && verboseSearchLog) {
      debugPrint('🔍 [Posted Tasks] 開始篩選任務: ${tasks.length} 個任務');
      // debugPrint('  - 搜尋關鍵字: "${chatProvider.searchQuery}"');
      // debugPrint('  - 選中位置: ${chatProvider.selectedLocations}');
      // debugPrint('  - 選中狀態: ${chatProvider.selectedStatuses}');
    }

    final filteredTasks = tasks.where((task) {
      if (kDebugMode && verboseSearchLog) {
        // 調試：顯示當前任務的完整數據
        // debugPrint('🔍 檢查任務: ${task['id']}');
        // debugPrint('  - 原始 title: "${task['title']}"');
        // debugPrint('  - 原始 description: "${task['description']}"');
        debugPrint('  - 所有可用欄位: ${task.keys.toList()}');
      }

      final rawQuery = chatProvider.searchQuery.trim();
      final hasSearchQuery = rawQuery.isNotEmpty;

      final title = (task['title'] ?? '-').toString();
      final description = (task['description'] ?? '-').toString();
      final location = (task['location'] ?? '-').toString();
      final language = (task['language_requirement'] ?? '-').toString();
      final statusDisplay = _displayStatus(task);
      final hashtags = (task['hashtags'] is List)
          ? (task['hashtags'] as List).join(' ')
          : (task['hashtags'] ?? '').toString();

      // 正規化
      final normalizedQuery = _normalizeSearchText(rawQuery.toLowerCase());
      final nTitle = _normalizeSearchText(title);
      final nDesc = _normalizeSearchText(description);
      final nLoc = _normalizeSearchText(location);
      final nLang = _normalizeSearchText(language);
      final nStatus = _normalizeSearchText(statusDisplay);
      final nTags = _normalizeSearchText(hashtags);

      // 搜尋：僅任務標題匹配
      bool matchQuery = true;
      int relevanceScore = 0;

      if (hasSearchQuery) {
        // 僅檢查標題匹配
        if (nTitle.contains(normalizedQuery)) {
          relevanceScore = 3; // 標題匹配固定 3 分
          matchQuery = true;
        } else {
          matchQuery = false;
        }

        if (!matchQuery) {
          if (kDebugMode && verboseSearchLog) {
            debugPrint('  ❌ 任務 "${task['title']}" 標題不符合搜尋條件');
          }
          return false;
        }

        // 將相關性分數掛到任務上
        task['_relevance'] = relevanceScore;
      }

      // 位置篩選
      final locationVal = (task['location'] ?? '').toString();
      // 支援跨位置搜尋選項，但預設尊重使用者的位置篩選
      final matchLocation = chatProvider.crossLocationSearch ||
          chatProvider.selectedLocations.isEmpty ||
          chatProvider.selectedLocations.contains(locationVal);
      if (!matchLocation) {
        if (kDebugMode && verboseSearchLog) {
          debugPrint('  ❌ 任務 "${task['title']}" 位置 "$locationVal" 不符合篩選條件');
        }
        return false;
      }

      // 狀態篩選
      final status = _displayStatus(task);
      final matchStatus = chatProvider.selectedStatuses.isEmpty ||
          chatProvider.selectedStatuses.contains(status);
      if (!matchStatus) {
        if (kDebugMode && verboseSearchLog) {
          debugPrint('  ❌ 任務 "${task['title']}" 狀態 "$status" 不符合篩選條件');
        }
        return false;
      }

      if (kDebugMode && verboseSearchLog) {
        debugPrint('  ✅ 任務 "${task['title']}" 通過所有篩選條件');
      }
      return true;
    }).toList();

    if (kDebugMode && verboseSearchLog) {
      debugPrint('🔍 [Posted Tasks] 篩選完成: ${filteredTasks.length} 個任務');
    }
    return filteredTasks;
  }

  /// 排序任務列表（混合排序：釘選 > 未讀 > 用戶選擇）
  List<Map<String, dynamic>> _sortTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    debugPrint('🔄 [Posted Tasks] 開始混合排序任務: ${tasks.length} 個任務');
    debugPrint('  - 排序方式: ${chatProvider.currentSortBy}');
    debugPrint('  - 排序方向: ${chatProvider.sortAscending ? "升序" : "降序"}');

    // 混合排序：釘選 > 未讀 > 用戶選擇的排序
    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) {
      // 1. 首先按釘選狀態排序（釘選的任務優先）
      final aPinned = _isTaskPinned(a['id'].toString());
      final bPinned = _isTaskPinned(b['id'].toString());

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      // 2. 釘選狀態相同時，按未讀狀態排序（有未讀的優先）
      final aHasUnread = _taskHasUnreadMessages(a);
      final bHasUnread = _taskHasUnreadMessages(b);

      if (aHasUnread && !bHasUnread) return -1;
      if (!aHasUnread && bHasUnread) return 1;

      // 3. 未讀狀態相同時，按用戶選擇的排序方式
      return _compareByUserSortChoice(a, b, chatProvider);
    });

    debugPrint('✅ [Posted Tasks] 混合排序完成');
    return sortedTasks;
  }

  /// 檢查任務是否有未讀訊息
  bool _taskHasUnreadMessages(Map<String, dynamic> task) {
    final taskId = task['id'].toString();
    final applicants = _applicationsByTask[taskId] ?? [];

    return applicants.any((app) {
      final roomId = app['chat_room_id']?.toString();
      if (roomId == null || roomId.isEmpty) return false;

      final chatProvider = _getChatProvider();
      return (chatProvider?.unreadForRoom(roomId) ?? 0) > 0;
    });
  }

  /// 根據用戶選擇的排序方式比較兩個任務
  int _compareByUserSortChoice(Map<String, dynamic> a, Map<String, dynamic> b,
      ChatListProvider chatProvider) {
    switch (chatProvider.currentSortBy) {
      case 'relevance':
        final aRelevance = a['_relevance'] ?? 0;
        final bRelevance = b['_relevance'] ?? 0;
        return bRelevance.compareTo(aRelevance); // 相關性降序

      case 'updated_time':
        final aTime =
            DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
        final bTime =
            DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
        return chatProvider.sortAscending
            ? aTime.compareTo(bTime)
            : bTime.compareTo(aTime);

      case 'applicant_count':
        final aCount = (_applicationsByTask[a['id']?.toString()] ?? []).length;
        final bCount = (_applicationsByTask[b['id']?.toString()] ?? []).length;
        return chatProvider.sortAscending
            ? aCount.compareTo(bCount)
            : bCount.compareTo(aCount);

      case 'status_id':
      default:
        // 預設按更新時間降序
        final aTime =
            DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
        final bTime =
            DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
        return bTime.compareTo(aTime);
    }
  }

  String _displayStatus(Map<String, dynamic> task) {
    final dynamic display = task['status_display'];
    if (display != null && display is String && display.isNotEmpty) {
      return display;
    }
    final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
    return (codeOrLegacy ?? '').toString();
  }

  /// 正規化搜尋文本 - 移除特殊字符並轉為小寫
  String _normalizeSearchText(String text) {
    if (text.isEmpty) return '';

    // 更寬鬆的正規化，保留更多字符
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\-\(\)\.\,\:\;\!\?]'), '') // 保留更多標點符號
        .replaceAll(RegExp(r'\s+'), ' ') // 將多個空格替換為單個空格
        .trim();

    if (kDebugMode && verboseSearchLog) {
      debugPrint('🔍 正規化搜尋文本: "$text" -> "$normalized"');
    }
    return normalized;
  }

  // (removed) 舊的測試搜尋匹配函式已整合至多欄位搜尋邏輯

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin
    return Selector<ChatListProvider, bool>(
      selector: (context, provider) => provider.isPostedTasksTab,
      builder: (context, isPostedTasksTab, child) {
        if (!isPostedTasksTab) {
          // debugPrint('🔍 [Posted Tasks] [build()] 不是 Posted Tasks 分頁，返回空容器');
          return const SizedBox.shrink();
        }

        return Selector<ChatListProvider, ChatListProvider>(
          selector: (context, provider) => provider,
          builder: (context, chatProvider, child) {
            // 添加詳細的調試日誌
            // debugPrint('🔍 [Posted Tasks] [build()] 開始建構 UI');
            // debugPrint('  - _allTasks 長度: ${_allTasks.length}');
            // debugPrint('  - _sortedTasks 長度: ${_sortedTasks.length}');
            // debugPrint('  - _filteredTasks 長度: ${_filteredTasks.length}');
            // debugPrint(
            //     '  - chatProvider.isTabLoading(0): ${chatProvider.isTabLoading(0)}');
            // debugPrint(
            //     '  - chatProvider.isTabLoaded(0): ${chatProvider.isTabLoaded(0)}');
            // debugPrint(
            //     '  - chatProvider.getTabError(0): ${chatProvider.getTabError(0)}');
            // debugPrint(
            //     '  - chatProvider.hasActiveFilters: ${chatProvider.hasActiveFilters}');
            // debugPrint(
            //     '  - chatProvider.searchQuery: "${chatProvider.searchQuery}"');

            if (chatProvider.isTabLoading(0)) {
              debugPrint('🔍 [Posted Tasks] [build()] 顯示載入中狀態');
              return _buildLoadingState();
            } else if (chatProvider.getTabError(0) != null) {
              debugPrint(
                  '🔍 [Posted Tasks] [build()] 顯示錯誤狀態: ${chatProvider.getTabError(0)}');
              return _buildErrorState(chatProvider);
            }
            // 使用 ChatListProvider 的篩選結果（支援即時搜尋和篩選）
            return Consumer<ChatListProvider>(
              builder: (context, chatProvider, child) {
                final filteredTasks = chatProvider.filteredPostedTasks;

                debugPrint(
                    '🔍 [Posted Tasks] 使用 ChatListProvider 篩選結果: ${filteredTasks.length} 個任務');
                debugPrint('  - 搜尋查詢: "${chatProvider.searchQuery}"');
                debugPrint('  - 選中位置: ${chatProvider.selectedLocations}');
                debugPrint('  - 選中狀態: ${chatProvider.selectedStatuses}');

                return RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await chatProvider.cacheManager.forceRefresh();
                      // 重新載入任務數據到 Provider 的快取中
                      await _fetchAllTasks();
                    } catch (e) {
                      debugPrint('❌ [Posted Tasks] 刷新失敗: $e');
                    }
                  },
                  child: filteredTasks.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: _buildEmptyState(
                                  isDataError:
                                      chatProvider.getTabError(0) != null,
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 12,
                            bottom: 80,
                          ),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return _buildTaskCard(task);
                          },
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 後端分頁載入 Posted Tasks
  Future<void> _fetchPostedTasksPage(int offset) async {
    try {
      // 安全地獲取 Provider 與 User
      ChatListProvider? chatProvider;
      UserService? userService;
      try {
        chatProvider = _getChatProvider();
        userService = context.read<UserService>();
      } catch (_) {}

      final currentUserId = userService?.currentUser?.id;
      if (currentUserId == null) {
        _pagingController.appendLastPage([]);
        return;
      }

      final result = await TaskService().fetchPostedTasksAggregated(
        creatorId: currentUserId.toString(),
        limit: _pageSize,
        offset: offset,
      );

      final items = result.tasks;

      // 更新內部快取（應徵者資料）
      for (final task in items) {
        final taskId = task['id'].toString();
        final applicantsRaw = task['applicants'] ?? [];
        final List<Map<String, dynamic>> applicants = (applicantsRaw is List)
            ? applicantsRaw.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _applicationsByTask[taskId] = applicants;
      }

      // 聚合總列表（供其他功能沿用）
      _allTasks.addAll(items);

      if (result.hasMore && items.isNotEmpty) {
        _pagingController.appendPage(items, offset + _pageSize);
      } else {
        _pagingController.appendLastPage(items);
      }

      // 依需求可應用過濾與排序，這裡暫以 API 順序為準
      // _applyFiltersAndSort();
    } catch (e) {
      _pagingController.error = e;
    }
  }

  // /// 顯示無搜尋結果的狀態
  // Widget _buildNoResultsState(ChatListProvider chatProvider) {
  //   debugPrint('🔍 [Posted Tasks] [_buildNoResultsState()] 無搜尋結果');
  //   return Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
  //         const SizedBox(height: 16),
  //         Text(
  //           'No tasks found',
  //           style: TextStyle(
  //             fontSize: 18,
  //             fontWeight: FontWeight.w600,
  //             color: Colors.grey[600],
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           'Try adjusting your search or filters',
  //           style: TextStyle(
  //             fontSize: 14,
  //             color: Colors.grey[500],
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         if (chatProvider.hasActiveFilters)
  //           ElevatedButton(
  //             onPressed: () => chatProvider.resetFilters(),
  //             child: const Text('Clear Filters'),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final taskId = task['id'].toString();
    final applicants = _applicationsByTask[taskId] ?? [];

    // 添加調試信息
    // debugPrint('🔍 [Posted Tasks] 建構任務卡片 $taskId');
    // debugPrint('  - 任務標題: ${task['title']}');
    // debugPrint('  - 應徵者數量: ${applicants.length}');
    // debugPrint('  - 應徵者數據: $applicants');

    if (applicants.isEmpty) {
      // debugPrint('⚠️ [Posted Tasks] 任務 $taskId 沒有應徵者數據');
    } else {
      // debugPrint('✅ [Posted Tasks] 任務 $taskId 有 ${applicants.length} 個應徵者');
      for (int i = 0; i < applicants.length; i++) {
        final applicant = applicants[i];
        // debugPrint(
        //     '    - 應徵者 $i: ${applicant['applier_name']} (ID: ${applicant['user_id']})');
        // debugPrint('      - 評分: ${applicant['avg_rating']}');
        // debugPrint('      - 評論數: ${applicant['review_count']}');
        // debugPrint('      - 聊天室ID: ${applicant['chat_room_id']}');
      }
    }

    // 新的聚合API直接返回應徵者資料，不需要轉換
    final applierChatItems = applicants
        .map((applicant) => {
              'id':
                  'app_${applicant['application_id'] ?? applicant['user_id']}',
              'taskId': taskId,
              'name': applicant['applier_name'] ?? 'Anonymous',
              'avatar': applicant['applier_avatar'],
              'rating': applicant['avg_rating'],
              'reviewsCount': applicant['review_count'],
              'questionReply': applicant['cover_letter'] ?? '',
              // 顯示最後一則訊息（或以 cover_letter 作為備援）
              'latest_message_snippet': applicant['latest_message_snippet'] ??
                  (applicant['cover_letter']?.toString().isNotEmpty == true
                      ? applicant['cover_letter']
                      : 'Applied for this task'),
              // 兼容欄位（若有需要）
              'first_message_snippet': applicant['first_message_snippet'] ??
                  (applicant['cover_letter']?.toString().isNotEmpty == true
                      ? applicant['cover_letter']
                      : null),
              'sentMessages': [
                applicant['latest_message_snippet'] ?? 'Applied for this task'
              ],
              'user_id': applicant['user_id'],
              'application_id': applicant['application_id'],
              'application_status':
                  applicant['application_status'] ?? 'applied',
              'answers_json': applicant['answers_json'],
              'created_at': applicant['application_created_at'],
              'chat_room_id': applicant['chat_room_id'], // 新增聊天室ID
              'isMuted': false,
              'isHidden': false,
            })
        .toList();

    // debugPrint('🔍 [Posted Tasks] 轉換後的應徵者聊天項目: ${applierChatItems.length} 個');

    return _buildPostedTasksCardWithAccordion(
        task, applierChatItems.cast<Map<String, dynamic>>());
  }

  /// Posted Tasks 分頁的任務卡片（使用 My Works 風格 + 手風琴功能）
  Widget _buildPostedTasksCardWithAccordion(
      Map<String, dynamic> task, List<Map<String, dynamic>> applierChatItems) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayStatus = TaskCardUtils.displayStatus(task);
    final progressData = TaskCardUtils.getProgressData(displayStatus);
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;
    final taskId = task['id'].toString();
    final isExpanded = _expandedTaskIds.contains(taskId);

    // 過濾可見的應徵者
    final visibleAppliers =
        applierChatItems.where((ap) => ap['isHidden'] != true).toList();
    // 已改為在卡片右側利用 hasUnread 圓點邏輯與應徵者卡片未讀數字顯示

    return Card(
      key: ValueKey('posted-task-$taskId'), // 明確標識為 Posted Tasks 的任務卡片
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              // 主要任務卡片
              InkWell(
                onTap: () {
                  // 點擊任務卡片時關閉鍵盤
                  FocusScope.of(context).unfocus();

                  if (mounted) {
                    setState(() {
                      if (isExpanded) {
                        _expandedTaskIds.remove(taskId);
                      } else {
                        // 一次只能展開一個任務，關閉其他任務
                        _expandedTaskIds.clear();
                        _expandedTaskIds.add(taskId);
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 左側：中空圓餅圖進度指示器
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CustomPaint(
                          painter: PieChartPainter(
                            progress: progress,
                            baseColor: baseColor,
                            strokeWidth: 4,
                          ),
                          child: Center(
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: baseColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 中間：任務資訊
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 任務標題
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Consumer<ChatListProvider>(
                                    builder: (context, chatProvider, child) {
                                      return HighlightedText(
                                        text: task['title'] ?? 'Untitled Task',
                                        highlight: chatProvider.searchQuery,
                                        normalStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                        highlightStyle: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        maxLines: null,
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // 任務狀態
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: baseColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      displayStatus,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: baseColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // 任務資訊 2x2 格局
                            _buildTaskInfoGrid(task, colorScheme),
                          ],
                        ),
                      ),

                      // 右側：未讀圓點（任一應徵者聊天室有未讀即顯示）與箭頭
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 任務卡層級：若任一應徵者聊天室存在未讀 → 顯示警示色圓點
                          Selector<ChatListProvider, bool>(
                            selector: (context, provider) {
                              return visibleAppliers.any((ap) {
                                final roomId = ap['chat_room_id']?.toString();
                                if (roomId == null || roomId.isEmpty) {
                                  return false;
                                }
                                return provider.unreadForRoom(roomId) > 0;
                              });
                            },
                            builder: (context, hasUnread, child) {
                              // 向 Provider 回報當前分頁是否有未讀（避免 build 期間 setState）
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                try {
                                  final provider = _getChatProvider();
                                  provider?.setTabHasUnread(
                                      ChatListProvider.tabPostedTasks,
                                      hasUnread);
                                } catch (_) {}
                              });

                              return hasUnread
                                  ? Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : const SizedBox(height: 16);
                            },
                          ),
                          AnimatedRotation(
                            turns: isExpanded ? 0.25 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 手風琴展開內容 - 添加動畫效果
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Column(
                        children: [
                          _buildActionBar(task, colorScheme),
                          if (visibleAppliers.isNotEmpty)
                            ...visibleAppliers.map((applier) =>
                                _buildApplierCard(applier, taskId, colorScheme))
                          else
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No applicants',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),

          // 倒數計時懸浮在右上角
          if (TaskCardUtils.isCountdownStatus(displayStatus))
            Positioned(
              top: -8,
              right: -8,
              child: CompactCountdownTimerWidget(
                task: task,
                onCountdownComplete: () {
                  // 倒數計時完成，執行自動完成任務流程
                  _executeAutoCompleteTask(task);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskInfoGrid(
      Map<String, dynamic> task, ColorScheme colorScheme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        children: [
          // 第一行：獎勵 + 位置
          Row(
            children: [
              // 獎勵
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.attach_money, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '${task['reward_point'] ?? task['salary'] ?? 0}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 位置
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        task['location'] ?? 'Unknown Location',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 第二行：日期 + 語言要求
          Row(
            children: [
              // 日期
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      DateFormat('MM/dd').format(
                        DateTime.parse(
                            task['task_date'] ?? DateTime.now().toString()),
                      ),
                      style:
                          TextStyle(fontSize: 11, color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 語言要求
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.language, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        task['language_requirement'] ?? 'No Requirement',
                        style:
                            TextStyle(fontSize: 11, color: colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(Map<String, dynamic> task, ColorScheme colorScheme) {
    final displayStatus = TaskCardUtils.displayStatus(task);
    final userService = Provider.of<UserService>(context, listen: false);
    final currentPermission = userService.getCurrentPermissionLevel();
    final isAdmin = PermissionService.canAccessAdmin(currentPermission);
    final isPendingConfirmation = task['status_id'] == 3;

    // 調試日誌
    debugPrint('🔍 [Posted Tasks] Timeup 按鈕調試:');
    debugPrint('  - 任務 ID: ${task['id']}');
    debugPrint('  - 任務標題: ${task['title']}');
    debugPrint('  - 當前用戶權限: $currentPermission');
    debugPrint('  - isAdmin: $isAdmin');
    debugPrint('  - 任務狀態結構: $task');
    debugPrint('  - 任務狀態 code: ${task['status_id']}');
    debugPrint('  - isPendingConfirmation: $isPendingConfirmation');
    debugPrint('  - displayStatus: $displayStatus');
    debugPrint('  - 應該顯示 Timeup 按鈕: ${isAdmin && isPendingConfirmation}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: displayStatus == 'Open'
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pin 按鈕
                // SizedBox(
                //   width: 40,
                //   child: OutlinedButton(
                //     onPressed: () => _togglePinTask(task),
                //     style: OutlinedButton.styleFrom(
                //       side: BorderSide(color: colorScheme.primary),
                //       padding: const EdgeInsets.symmetric(vertical: 4),
                //       minimumSize: const Size(40, 32),
                //     ),
                //     child: Icon(
                //       _isTaskPinned(task['id'].toString())
                //           ? Icons.push_pin
                //           : Icons.push_pin_outlined,
                //       size: 16,
                //       color: _isTaskPinned(task['id'].toString())
                //           ? colorScheme.primary
                //           : colorScheme.primary,
                //     ),
                //   ),
                // ),
                // const SizedBox(width: 8),
                // Info 按鈕
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showTaskInfoDialog(task),
                    icon: Icon(Icons.info_outline,
                        size: 16, color: colorScheme.primary),
                    label: Text('Info',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit 按鈕
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToEditTask(task),
                    icon: Icon(Icons.edit_outlined,
                        size: 16, color: colorScheme.primary),
                    label: Text('Edit',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete 按鈕（僅限 Open 狀態）
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteTask(task),
                    icon: Icon(Icons.delete_outline,
                        size: 16, color: colorScheme.error),
                    label: Text('Delete',
                        style:
                            TextStyle(fontSize: 12, color: colorScheme.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.error),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pin 按鈕（非 Open 狀態也顯示）
                // SizedBox(
                //   width: 40,
                //   child: OutlinedButton(
                //     onPressed: () => _togglePinTask(task),
                //     style: OutlinedButton.styleFrom(
                //       side: BorderSide(color: colorScheme.primary),
                //       padding: const EdgeInsets.symmetric(vertical: 4),
                //       minimumSize: const Size(40, 32),
                //     ),
                //     child: Icon(
                //       _isTaskPinned(task['id'].toString())
                //           ? Icons.push_pin
                //           : Icons.push_pin_outlined,
                //       size: 16,
                //       color: _isTaskPinned(task['id'].toString())
                //           ? colorScheme.primary
                //           : colorScheme.primary,
                //     ),
                //   ),
                // ),
                // const SizedBox(width: 16),
                // Timeup 按鈕（僅限管理員且 pending_confirmation 狀態）
                if (isAdmin && isPendingConfirmation) ...[
                  SizedBox(
                    width: 100,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmTimeupTask(task),
                      icon: Icon(Icons.timer_off,
                          size: 16, color: Colors.purple[700]),
                      label: Text('Timeup',
                          style: TextStyle(
                              fontSize: 12, color: Colors.purple[700])),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.purple[700]!),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                // Info 按鈕
                SizedBox(
                  width: 120,
                  child: OutlinedButton.icon(
                    onPressed: () => _showTaskInfoDialog(task),
                    icon: Icon(Icons.info_outline,
                        size: 16, color: colorScheme.primary),
                    label: Text('Info',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 建構帶有錯誤回退的頭像（使用快取）
  Widget _buildAvatarWithFallback(
    String? avatarPath,
    String? name, {
    double radius = 20,
    double fontSize = 14,
  }) {
    return CachedAvatarWidget(
      avatarPath: avatarPath,
      name: name ?? 'Unknown',
      radius: radius,
      fontSize: fontSize,
    );
  }

  Widget _buildApplierCard(
      Map<String, dynamic> applier, String taskId, ColorScheme colorScheme) {
    final roomId = applier['chat_room_id']?.toString() ?? '';
    final applicationStatus =
        applier['application_status']?.toString() ?? 'applied';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Slidable(
        key: ValueKey(
            'posted-applicant-$roomId-${applier['user_id']}'), // 🔧 更唯一的 key
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: _buildSwipeActions(
              applier, taskId, applicationStatus, colorScheme),
        ),
        child: Card(
          key: ValueKey(
              'applier-card-$roomId-${applier['user_id']}'), // 🔧 添加卡片 key
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: _buildAvatarWithFallback(
              applier['avatar']?.toString(),
              applier['name'],
              radius: 20,
              fontSize: 14,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    applier['name'] ?? 'Applier',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // 評分與評論數（小字灰色）
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasValidRating(applier['rating'])) ...[
                      Icon(Icons.star, color: Colors.amber[600], size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${applier['rating']}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '(${applier['reviewsCount']})',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ] else ...[
                      Icon(Icons.eco, color: Colors.lightGreen[600], size: 12),
                      const SizedBox(width: 2),
                      const Text(
                        'New Tasker', // Unreviewed
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ]
                  ],
                ),
              ],
            ),
            subtitle: _buildRealTimeMessageSubtitle(applier),
            trailing: // 未讀數字徽章（警示色）
                Selector<ChatListProvider, int>(
              selector: (context, provider) {
                final roomId = applier['chat_room_id']?.toString();
                final unreadCount =
                    roomId == null ? 0 : provider.unreadForRoom(roomId);

                // 🔧 調試：記錄每個應徵者的未讀數字
                if (kDebugMode) {
                  debugPrint(
                      '🔍 [Posted Tasks] 應徵者 ${applier['name']} (房間 $roomId) 未讀數: $unreadCount');
                }

                return unreadCount;
              },
              builder: (context, unread, child) {
                if (unread <= 0) return const SizedBox.shrink();

                return Container(
                  key: ValueKey(
                      'unread-badge-${applier['chat_room_id']}'), // 🔧 添加唯一 key
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            onTap: () async {
              // 點擊應徵者卡片時關閉鍵盤
              FocusScope.of(context).unfocus();

              final chatRoomId = applier['chat_room_id']?.toString();
              if (chatRoomId != null && chatRoomId.isNotEmpty) {
                // 使用統一的導航服務
                final currentLocation =
                    GoRouterState.of(context).uri.toString();

                final success =
                    await ChatNavigationService.navigateToChatDetail(
                  context: context,
                  roomId: chatRoomId,
                  sourceTab: 'posted-tasks',
                  returnPath: currentLocation,
                );

                if (!success) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Cannot enter chat room with ${applier['name']}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Chat room unavailable: ${applier['name']}'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  /// 構建滑動動作按鈕
  List<SlidableAction> _buildSwipeActions(Map<String, dynamic> applier,
      String taskId, String applicationStatus, ColorScheme colorScheme) {
    final List<SlidableAction> actions = [];

    // 根據應徵狀態決定可用的動作
    // switch (applicationStatus.toLowerCase()) {
    //   case 'applied':
    //     // 新應徵：可以標記已讀、拒絕、刪除
    //     actions.addAll([
    //       SlidableAction(
    //         onPressed: (context) => _markAsRead(applier, taskId),
    //         backgroundColor: Colors.blue,
    //         foregroundColor: Colors.white,
    //         icon: Icons.mark_email_read,
    //         label: 'Read',
    //       ),
    //       SlidableAction(
    //         onPressed: (context) => _rejectApplication(applier, taskId),
    //         backgroundColor: Colors.orange,
    //         foregroundColor: Colors.white,
    //         icon: Icons.close,
    //         label: 'Reject',
    //       ),
    //       SlidableAction(
    //         onPressed: (context) => _deleteApplication(applier, taskId),
    //         backgroundColor: Colors.red,
    //         foregroundColor: Colors.white,
    //         icon: Icons.delete,
    //         label: 'Delete',
    //       ),
    //     ]);
    //     break;

    //   case 'accepted':
    //     // 已接受：可以標記已讀、取消接受
    //     actions.addAll([
    //       SlidableAction(
    //         onPressed: (context) => _markAsRead(applier, taskId),
    //         backgroundColor: Colors.blue,
    //         foregroundColor: Colors.white,
    //         icon: Icons.mark_email_read,
    //         label: 'Read',
    //       ),
    //       SlidableAction(
    //         onPressed: (context) => _cancelAcceptance(applier, taskId),
    //         backgroundColor: Colors.orange,
    //         foregroundColor: Colors.white,
    //         icon: Icons.undo,
    //         label: 'Cancel',
    //       ),
    //     ]);
    //     break;

    //   case 'rejected':
    //     // 已拒絕：可以標記已讀、刪除
    //     actions.addAll([
    //       SlidableAction(
    //         onPressed: (context) => _markAsRead(applier, taskId),
    //         backgroundColor: Colors.blue,
    //         foregroundColor: Colors.white,
    //         icon: Icons.mark_email_read,
    //         label: 'Read',
    //       ),
    //       SlidableAction(
    //         onPressed: (context) => _deleteApplication(applier, taskId),
    //         backgroundColor: Colors.red,
    //         foregroundColor: Colors.white,
    //         icon: Icons.delete,
    //         label: 'Delete',
    //       ),
    //     ]);
    //     break;

    //   default:
    //     // 其他狀態：只能標記已讀
    //     actions.add(
    //       SlidableAction(
    //         onPressed: (context) => _markAsRead(applier, taskId),
    //         backgroundColor: Colors.blue,
    //         foregroundColor: Colors.white,
    //         icon: Icons.mark_email_read,
    //         label: 'Read',
    //       ),
    //     );
    // }

    return actions;
  }

  /// 標記為已讀
  Future<void> _markAsRead(Map<String, dynamic> applier, String taskId) async {
    final roomId = applier['chat_room_id']?.toString();
    if (roomId == null) return;

    try {
      // 這裡可以調用相應的 API 來標記聊天室為已讀
      // 暫時使用 Provider 來清除未讀數
      final provider = _getChatProvider();
      provider?.markRoomAsRead(roomId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Marked conversation with ${applier['name']} as read'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 拒絕應徵
  Future<void> _rejectApplication(
      Map<String, dynamic> applier, String taskId) async {
    final applicationId = applier['application_id']?.toString();
    if (applicationId == null) return;

    // 顯示確認對話框
    final confirmed = await _showConfirmDialog(
      'Reject Application',
      'Are you sure you want to reject ${applier['name']}\'s application?',
    );

    if (!confirmed) return;

    try {
      // 調用 TaskService 來拒絕應徵
      await TaskService().updateApplicationStatus(
        applicationId: applicationId,
        status: 'rejected',
      );

      // 刷新數據
      _refreshApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${applier['name']}\'s application'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 刪除應徵
  Future<void> _deleteApplication(
      Map<String, dynamic> applier, String taskId) async {
    final applicationId = applier['application_id']?.toString();
    if (applicationId == null) return;

    // 顯示確認對話框
    final confirmed = await _showConfirmDialog(
      'Delete Application',
      'Are you sure you want to permanently delete ${applier['name']}\'s application? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      // 調用 TaskService 來刪除應徵
      await TaskService().deleteApplication(applicationId: applicationId);

      // 刷新數據
      _refreshApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${applier['name']}\'s application'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 取消接受
  Future<void> _cancelAcceptance(
      Map<String, dynamic> applier, String taskId) async {
    final applicationId = applier['application_id']?.toString();
    if (applicationId == null) return;

    // 顯示確認對話框
    final confirmed = await _showConfirmDialog(
      'Cancel Acceptance',
      'Are you sure you want to cancel the acceptance of ${applier['name']}\'s application?',
    );

    if (!confirmed) return;

    try {
      // 調用 TaskService 來取消接受
      await TaskService().updateApplicationStatus(
        applicationId: applicationId,
        status: 'applied',
      );

      // 刷新數據
      _refreshApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cancelled acceptance of ${applier['name']}\'s application'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel acceptance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 顯示確認對話框
  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// 刷新應徵數據
  void _refreshApplications() {
    // 觸發 Provider 重新載入數據
    final provider = _getChatProvider();
    provider?.refreshPostedTasksApplications();
  }

  /// 顯示任務資訊對話框（使用 awesome_dialog）
  void _showTaskInfoDialog(Map<String, dynamic> task) {
    final themeManager = context.read<ThemeConfigManager>();
    final theme = themeManager.effectiveTheme;

    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.bottomSlide,
      title: task['title'] ?? 'Task Details',
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: theme.onSurface,
      ),
      body: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _buildTaskDescription(task),
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 14,
            color: theme.onSurface.withValues(alpha: 0.8),
            height: 1.4,
          ),
        ),
      ),
      btnOkColor: theme.primary,
      btnOkText: 'Close',
      btnOkOnPress: () {},
      dialogBackgroundColor: theme.surface,
      headerAnimationLoop: false,
      width: MediaQuery.of(context).size.width * 0.9,
      padding: const EdgeInsets.all(16),
    ).show();
  }

  /// 構建任務描述文字
  String _buildTaskDescription(Map<String, dynamic> task) {
    final applicants = _applicationsByTask[task['id'].toString()] ?? [];
    final applicantCount = applicants.length;

    return '''📝 Description: ${task['description'] ?? 'No description provided'}

📍 Location: ${task['location'] ?? 'Not specified'}

💰 Reward: ${task['reward_point'] ?? '0'} points

🌐 Language: ${task['language_requirement'] ?? 'Not specified'}

📊 Status: ${TaskCardUtils.displayStatus(task)}

👥 Applicants: $applicantCount

📅 Created: ${_formatDate(task['created_at'])}

🔄 Updated: ${_formatDate(task['updated_at'])}''';
  }

  /// 格式化日期顯示
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';

    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy/MM/dd HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  /// 前往編輯任務頁面
  void _navigateToEditTask(Map<String, dynamic> task) {
    final taskId = task['id']?.toString();
    if (taskId == null || taskId.isEmpty) {
      context.go('/task/edit', extra: task);
      return;
    }
    // 優先載入聚合資料再前往編輯
    TaskService()
        .fetchTaskEditData(taskId)
        .then((fullTask) => context.go('/task/edit', extra: fullTask ?? task))
        .catchError((_) => context.go('/task/edit', extra: task));
  }

  /// 確認刪除任務
  void _confirmDeleteTask(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
            'Are you sure you want to delete "${task['title']}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTask(task);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// 刪除任務（設置狀態為 cancelled）
  void _deleteTask(Map<String, dynamic> task) async {
    final taskId = task['id'].toString();

    try {
      final taskService = TaskService();
      await taskService.updateTaskStatus(
        taskId,
        'cancelled',
        statusId: 8,
      );

      if (mounted) {
        // 從本地列表中移除該任務
        _removeTaskById(taskId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  /// 通過 ID 移除任務（更新 ChatListProvider 快取）
  void _removeTaskById(String taskId) {
    if (!mounted) return;

    try {
      // 安全地獲取 ChatListProvider
      final chatProvider = _getChatProvider();
      if (chatProvider == null) {
        debugPrint('⚠️ [Posted Tasks] 無法獲取 ChatListProvider，無法移除任務');
        return;
      }

      // 從 ChatListProvider 的快取中移除任務
      final postedTasksCache = chatProvider.cacheManager.postedTasksCache;
      final originalLength = postedTasksCache.length;

      postedTasksCache.removeWhere((task) => task['id'].toString() == taskId);

      debugPrint('🗑️ [Posted Tasks] 已從 ChatListProvider 快取中移除任務: $taskId');
      debugPrint('  - 原始快取數量: $originalLength');
      debugPrint('  - 移除後快取數量: ${postedTasksCache.length}');

      // 從應徵者數據中移除
      _applicationsByTask.remove(taskId);

      // 從展開狀態中移除
      _expandedTaskIds.remove(taskId);

      // 由於我們直接修改了快取數據，Consumer 會自動檢測到變化並重新渲染
      // 但為了確保更新，我們可以觸發一個輕量級的刷新
      debugPrint('✅ [Posted Tasks] 任務移除完成，UI 將自動更新');
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 移除任務失敗: $e');
    }
  }

  /// 確認 Timeup 任務（管理員強制完成）
  void _confirmTimeupTask(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.purple[700]),
            const SizedBox(width: 8),
            const Text('Force Complete Task'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to force complete "${task['title']}"?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.purple[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Admin Action',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This will immediately complete the task and transfer points to the tasker.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _executeTimeupTask(task);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.purple[700],
            ),
            child: const Text('Force Complete'),
          ),
        ],
      ),
    );
  }

  /// 執行 Timeup 任務（強制完成）
  void _executeTimeupTask(Map<String, dynamic> task) async {
    final taskId = task['id'].toString();

    try {
      debugPrint('🔍 [Posted Tasks] 開始執行 Timeup 任務: $taskId');
      debugPrint('  - 任務資料: $task');

      // 顯示載入中
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Force completing task...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 使用現有的 confirmCompletion API 來強制完成任務
      final taskService = TaskService();
      debugPrint('🔍 [Posted Tasks] 調用 TaskService.confirmCompletion...');

      final result = await taskService.confirmCompletion(
        taskId: taskId,
        preview: false, // 直接執行，不預覽
      );

      debugPrint('✅ [Posted Tasks] confirmCompletion 成功: $result');

      if (mounted) {
        // 更新本地任務狀態
        _updateTaskById(taskId, {'status': 'completed'});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "${task['title']}" has been force completed'),
            backgroundColor: Colors.green,
          ),
        );

        debugPrint('✅ [Posted Tasks] Timeup 任務執行成功: $taskId');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [Posted Tasks] Timeup 任務執行失敗: $taskId');
      debugPrint('❌ 錯誤詳情: $e');
      debugPrint('❌ 堆疊追蹤: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to force complete task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 執行自動完成任務（倒數計時結束時觸發）
  void _executeAutoCompleteTask(Map<String, dynamic> task) async {
    final taskId = task['id'].toString();

    try {
      debugPrint('⏰ [Posted Tasks] 倒數計時結束，開始自動完成任務: $taskId');

      // 使用現有的 confirmCompletion API 來自動完成任務
      final taskService = TaskService();
      await taskService.confirmCompletion(
        taskId: taskId,
        preview: false, // 直接執行，不預覽
      );

      if (mounted) {
        // 更新本地任務狀態
        _updateTaskById(taskId, {'status': 'completed'});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task "${task['title']}" has been automatically completed'),
            backgroundColor: Colors.green,
          ),
        );

        debugPrint('✅ [Posted Tasks] 任務自動完成成功: $taskId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to auto complete task: $e'),
            backgroundColor: Colors.red,
          ),
        );

        debugPrint('❌ [Posted Tasks] 任務自動完成失敗: $taskId, 錯誤: $e');
      }
    }
  }

  /// 通過 ID 更新任務狀態（本地狀態更新）
  void _updateTaskById(String taskId, Map<String, dynamic> updatedTask) {
    if (!mounted) return;

    setState(() {
      // 更新 _allTasks 中的任務
      final allTaskIndex =
          _allTasks.indexWhere((task) => task['id'].toString() == taskId);
      if (allTaskIndex != -1) {
        _allTasks[allTaskIndex] = updatedTask;
      }

      // 更新 _filteredTasks 中的任務
      final filteredTaskIndex =
          _filteredTasks.indexWhere((task) => task['id'].toString() == taskId);
      if (filteredTaskIndex != -1) {
        _filteredTasks[filteredTaskIndex] = updatedTask;
      }

      // 更新 _sortedTasks 中的任務
      final sortedTaskIndex =
          _sortedTasks.indexWhere((task) => task['id'].toString() == taskId);
      if (sortedTaskIndex != -1) {
        _sortedTasks[sortedTaskIndex] = updatedTask;
      }
    });

    // 更新分頁控制器的狀態
    try {
      final currentItems = _pagingController.itemList ?? [];
      final updatedItems = currentItems.map((task) {
        if (task['id'].toString() == taskId) {
          return updatedTask;
        }
        return task;
      }).toList();

      _pagingController.itemList = updatedItems;

      debugPrint('🔄 [Posted Tasks] 已更新任務: $taskId');
    } catch (e) {
      debugPrint('⚠️ [Posted Tasks] 更新分頁控制器失敗: $e');
    }
  }

  /// 建構主要載入動畫
  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading tasks...',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 建構分頁載入動畫
  Widget _buildPaginationLoadingAnimation() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// 建構空狀態
  Widget _buildEmptyState({bool isDataError = false}) {
    debugPrint(
        '🔍 [Posted Tasks] [_buildEmptyState()] 建構空狀態 - isDataError: $isDataError');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDataError ? Icons.error_outline : Icons.inbox_outlined,
            size: 64,
            color: isDataError
                ? Colors.red[300]
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isDataError ? 'No tasks found' : 'No posted tasks yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDataError
                  ? Colors.red[600]
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
            ),
          ),
          if (isDataError) ...[
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 建構載入中狀態
  Widget _buildLoadingState() {
    // debugPrint('🔍 [Posted Tasks] [_buildLoadingState()] 建構載入中狀態');
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// 建構錯誤狀態
  Widget _buildErrorState(ChatListProvider chatProvider) {
    debugPrint('🔍 [Posted Tasks] [_buildErrorState()] 建構錯誤狀態');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error: ${chatProvider.getTabError(0)}',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => chatProvider
                .checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Pin 功能相關方法

  /// 檢查任務是否已釘選
  bool _isTaskPinned(String taskId) {
    return _pinnedTaskIds.contains(taskId);
  }

  /// 切換任務釘選狀態
  void _togglePinTask(Map<String, dynamic> task) {
    final taskId = task['id'].toString();

    setState(() {
      if (_pinnedTaskIds.contains(taskId)) {
        _pinnedTaskIds.remove(taskId);
        debugPrint('📌 [Posted Tasks] 取消釘選任務: $taskId');
      } else {
        _pinnedTaskIds.add(taskId);
        debugPrint('📌 [Posted Tasks] 釘選任務: $taskId');
      }
    });

    // 重新應用篩選和排序
    _applyFiltersAndSort();
  }

  /// 檢查是否有有效的評分
  bool _hasValidRating(dynamic rating) {
    if (rating == null) return false;

    // 處理數字類型
    if (rating is num) {
      return rating > 0;
    }

    // 處理字符串類型
    if (rating is String) {
      final parsedRating = double.tryParse(rating);
      return parsedRating != null && parsedRating > 0;
    }

    return false;
  }

  /// 建構實時消息副標題
  Widget _buildRealTimeMessageSubtitle(Map<String, dynamic> applier) {
    final roomId = applier['chat_room_id']?.toString();
    String initialText = applier['latest_message_snippet'] ?? 'No messages';

    if (roomId == null || roomId.isEmpty) {
      return Text(
        initialText,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: SocketService().messagesForRoom(roomId),
      builder: (context, snapshot) {
        String messageText = initialText;

        // 🔧 修復：檢查訊息是否屬於當前房間
        if (snapshot.hasData && snapshot.data != null) {
          final messageData = snapshot.data!;
          final messageRoomId = messageData['roomId']?.toString() ??
              messageData['room_id']?.toString();

          // 只有當訊息確實屬於當前房間時才更新顯示
          if (messageRoomId == roomId) {
            final text = messageData['text']?.toString() ??
                messageData['content']?.toString() ??
                messageData['message']?.toString() ??
                '';
            if (text.isNotEmpty) {
              messageText = text;
              debugPrint(
                  '🔄 [Posted Tasks] 更新房間 $roomId 的最新訊息: ${text.substring(0, text.length > 20 ? 20 : text.length)}...');
            }
          }
        }

        return Text(
          messageText,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// 舊的 _AvatarWithFallback 已移除，統一使用 CachedAvatarWidget

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/utils/avatar_error_cache.dart';
import 'package:here4help/chat/services/smart_refresh_strategy.dart';
import 'package:here4help/chat/services/chat_navigation_service.dart';

/// My Works 分頁組件
/// 從原 ChatListPage 中抽取的 My Works 相關功能
class MyWorksWidget extends StatefulWidget {
  const MyWorksWidget({super.key});

  @override
  State<MyWorksWidget> createState() => _MyWorksWidgetState();
}

class _MyWorksWidgetState extends State<MyWorksWidget> {
  // -------- Safe extractors & normalizers --------
  T _as<T>(Object? v, T fallback) {
    if (v is T) return v;
    try {
      if (v == null) return fallback;
      if (T == String) return v.toString().trim() as T;
      if (T == int) return int.tryParse(v.toString()) as T? ?? fallback;
      if (T == double) return double.tryParse(v.toString()) as T? ?? fallback;
      if (T == bool) {
        final s = v.toString().toLowerCase();
        if (s == 'true' || s == '1') return true as T;
        if (s == 'false' || s == '0') return false as T;
        return fallback;
      }
    } catch (_) {}
    return fallback;
  }

  DateTime _parseDateOrNow(Object? v) {
    if (v == null) return DateTime.now();
    final s = v.toString().trim();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _asDateStr(Object? v) {
    try {
      return _parseDateOrNow(v).toIso8601String();
    } catch (_) {
      return DateTime.now().toIso8601String();
    }
  }

  String _normStatus(Object? code, Object? display) {
    final raw = (display ?? code ?? '').toString().trim();
    if (raw.isEmpty) return '';
    final s = raw.toLowerCase();
    const aliases = <String, String>{
      'open': 'Open',
      'in progress': 'In Progress',
      'pending confirmation': 'Pending Confirmation',
      'completed': 'Completed',
      'dispute': 'Dispute',
      'rejected': 'Rejected',
      'cancelled': 'Cancelled',
    };
    return aliases[s] ?? raw;
  }

  static const int _pageSize = 20;
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 0);

  StreamSubscription<Map<String, int>>? _unreadSub;

  /// 檢查並按需載入數據
  void _checkAndLoadIfNeeded() {
    if (!mounted) return;

    // 安全地獲取 ChatListProvider
    ChatListProvider? chatProvider;
    try {
      chatProvider = context.read<ChatListProvider>();
    } catch (e) {
      debugPrint(
          '⚠️ [My Works] _checkAndLoadIfNeeded 無法獲取 ChatListProvider: $e');
      return;
    }

    // 檢查 Provider 是否已初始化
    if (!chatProvider.isInitialized) {
      debugPrint('⏳ [My Works] Provider 尚未初始化，跳過載入檢查');
      return;
    }

    // 檢查當前是否為 My Works 分頁且可見
    if (chatProvider.isMyWorksTab) {
      debugPrint('🔍 [My Works] 當前為 My Works 分頁，檢查載入狀態');
      debugPrint(
          '  - 分頁載入狀態: ${chatProvider.isTabLoading(ChatListProvider.TAB_MY_WORKS)}');
      debugPrint(
          '  - 分頁載入完成: ${chatProvider.isTabLoaded(ChatListProvider.TAB_MY_WORKS)}');
      debugPrint(
          '  - 分頁錯誤: ${chatProvider.getTabError(ChatListProvider.TAB_MY_WORKS)}');

      // 如果分頁尚未載入且不在載入中，觸發載入
      if (!chatProvider.isTabLoaded(ChatListProvider.TAB_MY_WORKS) &&
          !chatProvider.isTabLoading(ChatListProvider.TAB_MY_WORKS)) {
        debugPrint('🚀 [My Works] 觸發分頁數據載入');
        chatProvider.checkAndTriggerTabLoad(ChatListProvider.TAB_MY_WORKS);
      } else {
        debugPrint('✅ [My Works] 分頁已載入或正在載入中');
      }
    } else {
      debugPrint('⏸️ [My Works] 當前不是 My Works 分頁，跳過載入');
    }
  }

  void _updateMyWorksTabUnreadFlag() {
    if (!mounted) return;
    bool hasUnread = false;

    try {
      // 使用 try-catch 包裝 context.read 調用
      final provider = context.read<ChatListProvider>();

      // 檢查所有未讀訊息映射中是否有大於 0 的計數
      for (final count in provider.unreadByRoom.values) {
        if (count > 0) {
          hasUnread = true;
          break;
        }
      }

      final oldState = provider.hasUnreadForTab(ChatListProvider.TAB_MY_WORKS);

      // 使用智能刷新策略的狀態更新器
      SmartRefreshStrategy.updateUnreadState(
        componentKey: 'MyWorks-Tab',
        oldState: oldState,
        newState: hasUnread,
        updateCallback: () {
          if (!mounted) return;
          try {
            debugPrint('✅ [My Works] 更新 Tab 未讀狀態: $hasUnread');
            provider.setTabHasUnread(ChatListProvider.TAB_MY_WORKS, hasUnread);
          } catch (e) {
            debugPrint('❌ [My Works] 更新 Tab 未讀狀態失敗: $e');
          }
        },
        description: 'My Works Tab 未讀狀態',
      );
    } catch (e) {
      debugPrint('❌ [My Works] 更新 Tab 未讀狀態失敗: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // 確保未讀數據已載入
    _ensureUnreadDataLoaded();

    _pagingController.addPageRequestListener((offset) {
      if (context.mounted) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _fetchMyWorksPage(offset));
      } else {
        _fetchMyWorksPage(offset);
      }
    });

    // 主動載入第一頁數據
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('🚀 [My Works] 初始化時主動載入第一頁數據');
        _fetchMyWorksPage(0);
      }
    });

    // 監聽 ChatListProvider 的篩選條件變化（僅針對當前tab）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final chatProvider = context.read<ChatListProvider>();
        chatProvider.addListener(_handleProviderChanges);

        // 檢查並按需載入數據
        _checkAndLoadIfNeeded();
      } catch (e) {
        debugPrint('❌ [My Works] initState 中設置 Provider listener 失敗: $e');
      }
    });

    _unreadSub = NotificationCenter().byRoomStream.listen((map) {
      if (!mounted) return;
      debugPrint('🔍 [My Works] 收到未讀數據更新: ${map.length} 個房間');

      // 更新 Provider 中的未讀數據
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          // 再次檢查 mounted 狀態
          if (!mounted) return;

          // 安全地獲取 Provider
          ChatListProvider? safeProvider;
          try {
            safeProvider = context.read<ChatListProvider>();
          } catch (e) {
            debugPrint('⚠️ [My Works] PostFrame 中無法獲取 ChatListProvider');
            return;
          }

          safeProvider.updateUnreadByRoom(map);
          debugPrint('✅ [My Works] 未讀數據已同步完成');
        } catch (e) {
          debugPrint('❌ [My Works] 更新未讀數據失敗: $e');
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateMyWorksTabUnreadFlag();
      });
    });
  }

  /// 確保未讀數據已載入
  Future<void> _ensureUnreadDataLoaded() async {
    try {
      debugPrint('🔄 [My Works] 開始確保未讀數據載入...');

      // 等待 NotificationCenter 初始化完成
      await NotificationCenter().waitForUnreadData();

      // 強制刷新快照
      await NotificationCenter().service.refreshSnapshot();
      debugPrint('✅ [My Works] 未讀數據初始化完成');
    } catch (e) {
      debugPrint('❌ [My Works] 未讀數據初始化失敗: $e');
    }
  }

  void _handleProviderChanges() {
    if (!mounted) return;

    try {
      final chatProvider = context.read<ChatListProvider>();

      // 只有當前是 My Works 分頁時才刷新
      if (chatProvider.isMyWorksTab) {
        // 使用智能刷新策略決策
        SmartRefreshStrategy.executeSmartRefresh(
          refreshKey: 'MyWorks-Provider',
          refreshCallback: () {
            if (!mounted) return;
            try {
              debugPrint('✅ [My Works] 執行智能刷新');
              _pagingController.refresh();
            } catch (e) {
              debugPrint('❌ [My Works] 智能刷新失敗: $e');
            }
          },
          hasActiveFilters: chatProvider.hasActiveFilters,
          searchQuery: chatProvider.searchQuery,
          isUnreadUpdate: true, // 假設這是未讀狀態更新觸發的
          forceRefresh: false,
          enableDebounce: true,
        );
      }
    } catch (e) {
      debugPrint('❌ [My Works] Provider 變化處理失敗: $e');
    }
  }

  @override
  void dispose() {
    // 移除 provider listener
    try {
      if (mounted) {
        final chatProvider = context.read<ChatListProvider>();
        chatProvider.removeListener(_handleProviderChanges);
      }
    } catch (e) {
      // Provider may not be available during dispose
      debugPrint('⚠️ [My Works] dispose 時移除 listener 失敗: $e');
    }

    // 取消未讀數據訂閱
    _unreadSub?.cancel();
    _unreadSub = null;

    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyWorksPage(int offset) async {
    try {
      debugPrint('🔍 [My Works] _fetchMyWorksPage 開始，offset: $offset');

      // 安全地獲取 Provider
      ChatListProvider? chatProvider;
      UserService? userService;

      try {
        chatProvider = context.read<ChatListProvider>();
        userService = context.read<UserService>();
      } catch (e) {
        debugPrint('⚠️ [My Works] 無法獲取 Provider: $e');
        return;
      }

      final taskService = TaskService();
      final currentUserId = userService.currentUser?.id;

      debugPrint('🔍 [My Works] 當前用戶 ID: $currentUserId');
      debugPrint('🔍 [My Works] TaskService 實例: $taskService');

      if (currentUserId != null) {
        debugPrint('📡 [My Works] 後端分頁載入: offset=$offset, limit=$_pageSize');
        final page = await taskService.fetchMyWorksApplications(
          userId: currentUserId.toString(),
          limit: _pageSize,
          offset: offset,
        );
        final converted = _processApplicationsFromService(page.items);
        if (!mounted) return;
        if (page.hasMore && converted.isNotEmpty) {
          _pagingController.appendPage(converted, offset + _pageSize);
          debugPrint('✅ [My Works] 追加分頁，下一頁 key: ${offset + _pageSize}');
        } else {
          _pagingController.appendLastPage(converted);
          debugPrint('✅ [My Works] 最後一頁，筆數: ${converted.length}');
        }
        // 資料載入完成後更新未讀標記
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _updateMyWorksTabUnreadFlag();
        });
        debugPrint('✅ [My Works] _fetchMyWorksPage 完成');
        return;
      } else {
        debugPrint('❌ [My Works] 當前用戶 ID 為空');
        _pagingController.appendLastPage([]);
        return;
      }

      final allTasks = _composeMyWorks(taskService, currentUserId);
      debugPrint('🔍 [My Works] 組合後的任務數量: ${allTasks.length}');

      // 應用篩選和排序
      final filtered = _filterTasks(allTasks, chatProvider);
      debugPrint('🔍 [My Works] 篩選後的任務數量: ${filtered.length}');

      final sorted = _sortTasks(filtered, chatProvider);
      debugPrint('🔍 [My Works] 排序後的任務數量: ${sorted.length}');

      final start = offset;
      final end = (offset + _pageSize) > sorted.length
          ? sorted.length
          : (offset + _pageSize);
      final slice = sorted.sublist(start, end);
      final hasMore = end < sorted.length;

      debugPrint(
          '🔍 [My Works] 分頁處理: start=$start, end=$end, slice=${slice.length}, hasMore=$hasMore');

      if (!mounted) return;

      if (hasMore) {
        _pagingController.appendPage(slice, end);
        debugPrint('✅ [My Works] 添加分頁數據，下一頁 key: $end');
      } else {
        _pagingController.appendLastPage(slice);
        debugPrint('✅ [My Works] 添加最後一頁數據');
      }

      // 資料載入完成後更新未讀標記
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateMyWorksTabUnreadFlag();
      });

      debugPrint('✅ [My Works] _fetchMyWorksPage 完成');
    } catch (error) {
      debugPrint('❌ [My Works] _fetchMyWorksPage 錯誤: $error');
      if (mounted) {
        _pagingController.error = error;
      }
    }
  }

  /// 處理從 TaskService 獲取的應徵記錄（備用方法）
  List<Map<String, dynamic>> _processApplicationsFromService(
      List<Map<String, dynamic>> apps) {
    if (apps.isEmpty) {
      debugPrint('⚠️ [My Works] _processApplicationsFromService: 沒有應徵記錄');
      return [];
    }

    debugPrint(
        '🔍 [My Works] _processApplicationsFromService: 處理 ${apps.length} 個應徵記錄');

    return apps.map((raw) {
      final Map<String, dynamic> app = Map<String, dynamic>.from(raw);

      final statusCodeRaw =
          app['status_code'] ?? app['client_status_code'] ?? app['status'];
      final statusDispRaw = app['status_display'] ??
          app['client_status_display'] ??
          app['display_status'];

      return {
        'id': app['id'] != null ? _as<String>(app['id'], '') : '',
        'task_id':
            app['task_id'] != null ? _as<String>(app['task_id'], '') : '',
        'title': app['title'] != null
            ? _as<String>(app['title'], 'Untitled Task')
            : 'Untitled Task',
        'description': app['description'] != null
            ? _as<String>(app['description'], '')
            : '',
        'reward_point': app['reward_point'] != null
            ? _as<double>(app['reward_point'], 0.0)
            : 0.0,
        'location':
            app['location'] != null ? _as<String>(app['location'], '') : '',
        'task_date':
            app['task_date'] != null ? _asDateStr(app['task_date']) : '',
        'language_requirement': app['language_requirement'] != null
            ? _as<String>(app['language_requirement'], '')
            : '',
        'status_code':
            statusCodeRaw != null ? _as<String>(statusCodeRaw, '') : '',
        'status_display': _normStatus(statusCodeRaw, statusDispRaw),
        'creator_id':
            app['creator_id'] != null ? _as<int>(app['creator_id'], 0) : 0,
        'creator_name': app['creator_name'] != null
            ? _as<String>(app['creator_name'], 'Unknown')
            : 'Unknown',
        'creator_avatar': app['creator_avatar'] != null
            ? _as<String>(app['creator_avatar'], '')
            : '',
        'latest_message_snippet': app['latest_message_snippet'] != null
            ? _as<String>(app['latest_message_snippet'], 'No conversation yet')
            : 'No conversation yet',
        'chat_room_id': app['chat_room_id'] != null
            ? _as<String>(app['chat_room_id'], '')
            : '',
        'applied_by_me': true,
        'application_id': app['application_id'] != null
            ? _as<String>(app['application_id'], '')
            : '',
        'application_status': app['application_status'] != null
            ? _as<String>(app['application_status'], '')
            : '',
        'application_created_at': app['application_created_at'] != null
            ? _asDateStr(app['application_created_at'])
            : '',
        'application_updated_at': app['application_updated_at'] != null
            ? _asDateStr(app['application_updated_at'])
            : '',
        'sort_order': app['sort_order'] ?? 999,
        'updated_at': app['updated_at'] ?? DateTime.now().toString(),
      };
    }).toList();
  }

  /// 整理 My Works 清單：優先使用 ChatListProvider 快取，回退到 TaskService
  List<Map<String, dynamic>> _composeMyWorks(
      TaskService service, int? currentUserId) {
    // 安全地獲取 ChatListProvider
    ChatListProvider? chatProvider;
    try {
      chatProvider = context.read<ChatListProvider>();
    } catch (e) {
      debugPrint('⚠️ [My Works] _composeMyWorks 無法獲取 ChatListProvider: $e');
      // 如果無法獲取 Provider，直接使用 TaskService 數據
      final apps = service.myApplications;
      debugPrint('📡 [My Works] 使用 TaskService 數據作為備用: ${apps.length} 個應徵記錄');
      return _processApplicationsFromService(apps);
    }

    List<Map<String, dynamic>> apps = [];

    // 檢查 Provider 中的數據
    if (chatProvider.myWorksApplications.isNotEmpty) {
      apps = List<Map<String, dynamic>>.from(chatProvider.myWorksApplications);
      debugPrint('✅ [My Works] 使用 ChatListProvider 快取: ${apps.length} 個應徵記錄');
    } else if (chatProvider.isCacheReadyForTab(ChatListProvider.TAB_MY_WORKS)) {
      apps = List<Map<String, dynamic>>.from(
          chatProvider.cacheManager.myWorksCache);
      debugPrint('✅ [My Works] 使用 ChatCacheManager 快取: ${apps.length} 個應徵記錄');
    } else {
      // 如果 Provider 中沒有數據，強制從 TaskService 載入
      debugPrint('📡 [My Works] Provider 中沒有數據，強制從 TaskService 載入');
      apps = service.myApplications;
      debugPrint('📡 [My Works] TaskService 數據: ${apps.length} 個應徵記錄');

      // 如果 TaskService 中也沒有數據，嘗試強制重新載入
      if (apps.isEmpty && currentUserId != null) {
        debugPrint('🔄 [My Works] TaskService 中沒有數據，嘗試強制重新載入');
        try {
          // 這裡不能直接 await，因為這個方法不是 async
          // 但我們可以記錄需要重新載入的狀態
          debugPrint('⚠️ [My Works] 需要重新載入數據，請檢查 API 調用');
        } catch (e) {
          debugPrint('❌ [My Works] 強制重新載入失敗: $e');
        }
      }
    }

    // 添加詳細的除錯資訊
    // debugPrint('🔍 [My Works] _composeMyWorks 開始');
    debugPrint('🔍 [My Works] currentUserId: $currentUserId');
    debugPrint(
        '🔍 [My Works][_composeMyWorks] 數據來源: ${chatProvider.isCacheReadyForTab(ChatListProvider.TAB_MY_WORKS) ? "快取" : "API"}');
    // debugPrint('🔍 [My Works] 應徵記錄長度: ${apps.length}');
    debugPrint('🔍 [My Works][_composeMyWorks] 應徵記錄內容: ${apps.length} 個應徵記錄');

    // 如果沒有應徵數據，返回空列表
    if (apps.isEmpty) {
      debugPrint('⚠️ [My Works] 沒有應徵數據，返回空列表');
      return [];
    }

    final result = apps.map((raw) {
      // 確保是可變 Map 並統一鍵值型別
      final Map<String, dynamic> app = Map<String, dynamic>.from(raw);

      final statusCodeRaw =
          app['status_code'] ?? app['client_status_code'] ?? app['status'];
      final statusDispRaw = app['status_display'] ??
          app['client_status_display'] ??
          app['display_status'];

      return {
        'id': app['id'] != null ? _as<String>(app['id'], '') : '',
        'task_id':
            app['task_id'] != null ? _as<String>(app['task_id'], '') : '',
        'title': app['title'] != null
            ? _as<String>(app['title'], 'Untitled Task')
            : 'Untitled Task',
        'description': app['description'] != null
            ? _as<String>(app['description'], '')
            : '',
        'reward_point': app['reward_point'] != null
            ? _as<double>(app['reward_point'], 0.0)
            : 0.0,
        'location':
            app['location'] != null ? _as<String>(app['location'], '') : '',
        'task_date':
            app['task_date'] != null ? _asDateStr(app['task_date']) : '',
        'language_requirement': app['language_requirement'] != null
            ? _as<String>(app['language_requirement'], '')
            : '',
        'status_code':
            statusCodeRaw != null ? _as<String>(statusCodeRaw, '') : '',
        'status_display': _normStatus(statusCodeRaw, statusDispRaw),
        'creator_id': app['creator_id'] != null
            ? _as<int>(app['creator_id'], 0)
            : 0, // 若為 UUID 改成 _as<String>
        'creator_name': app['creator_name'] != null
            ? _as<String>(app['creator_name'], 'Unknown')
            : 'Unknown',
        'creator_avatar': app['creator_avatar'] != null
            ? _as<String>(app['creator_avatar'], '')
            : '',
        'latest_message_snippet': app['latest_message_snippet'] != null
            ? _as<String>(app['latest_message_snippet'], 'No conversation yet')
            : 'No conversation yet',
        'chat_room_id': app['chat_room_id'] != null
            ? _as<String>(app['chat_room_id'], '')
            : '',
        'applied_by_me': true,
        'application_id': app['application_id'] != null
            ? _as<String>(app['application_id'], '')
            : '',
        'application_status': app['application_status'] != null
            ? _as<String>(app['application_status'], '')
            : '',
        'application_created_at': app['application_created_at'] != null
            ? _asDateStr(app['application_created_at'])
            : '',
        'application_updated_at': app['application_updated_at'] != null
            ? _asDateStr(app['application_updated_at'])
            : '',
        // 供排序用的輔助欄位（避免 parse 失敗）
        'updated_at':
            (app['application_updated_at'] != null || app['updated_at'] != null)
                ? _asDateStr(app['application_updated_at'] ?? app['updated_at'])
                : '',
      };
    }).toList();

    debugPrint('✅ [My Works] _composeMyWorks 完成，返回 ${result.length} 個任務');
    // debugPrint('🔍 [My Works] 轉換後的任務列表: $result');

    return result;
  }

  /// 正規化搜尋文本 - 與 PostedTasks 一致，移除特殊字符並轉為小寫
  String _normalizeSearchText(String text) {
    if (text.isEmpty) return '';
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\-\(\)\.\,\:\;\!\?]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  /// 篩選任務列表（My Works）— 統一搜尋/篩選邏輯
  List<Map<String, dynamic>> _filterTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    final rawQuery = chatProvider.searchQuery.trim();
    final hasSearchQuery = rawQuery.isNotEmpty;
    final normalizedQuery = _normalizeSearchText(rawQuery);

    return tasks.where((task) {
      final title = (task['title'] ?? '').toString();
      final description = (task['description'] ?? '').toString();
      final latestMessage = (task['latest_message_snippet'] ?? '').toString();
      final creatorName = (task['creator_name'] ?? '').toString();
      final location = (task['location'] ?? '').toString();
      final language = (task['language_requirement'] ?? '').toString();
      final statusDisplay = _displayStatus(task);

      // 統一正規化
      final nTitle = _normalizeSearchText(title);
      final nDesc = _normalizeSearchText(description);
      final nMsg = _normalizeSearchText(latestMessage);
      final nCreator = _normalizeSearchText(creatorName);
      final nLoc = _normalizeSearchText(location);
      final nLang = _normalizeSearchText(language);
      final nStatus = _normalizeSearchText(statusDisplay);

      // 搜尋：任一可見欄位命中即可
      bool matchQuery = true;
      if (hasSearchQuery) {
        matchQuery = nTitle.contains(normalizedQuery) ||
            nDesc.contains(normalizedQuery) ||
            nMsg.contains(normalizedQuery) ||
            nCreator.contains(normalizedQuery) ||
            nLoc.contains(normalizedQuery) ||
            nLang.contains(normalizedQuery) ||
            nStatus.contains(normalizedQuery);
      }

      if (!matchQuery) return false;

      // 位置篩選：始終尊重使用者的位置篩選
      final matchLocation = chatProvider.selectedLocations.isEmpty ||
          chatProvider.selectedLocations.contains(location);
      if (!matchLocation) return false;

      // 狀態篩選
      final matchStatus = chatProvider.selectedStatuses.isEmpty ||
          chatProvider.selectedStatuses.contains(statusDisplay);

      return matchStatus;
    }).toList();
  }

  /// 排序任務列表（簡化版：統一使用 status_id 優先級排序）
  List<Map<String, dynamic>> _sortTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    debugPrint('🔄 [My Works] 開始排序任務: ${tasks.length} 個任務');
    debugPrint('  - 排序方式: ${chatProvider.currentSortBy}');
    debugPrint('  - 排序方向: ${chatProvider.sortAscending ? "升序" : "降序"}');

    // 簡化邏輯：統一使用 status_id 優先級排序
    if (chatProvider.currentSortBy == 'status_id') {
      debugPrint('✅ [My Works] 使用預設 status_id 排序');
      return _sortByStatusId(tasks, chatProvider);
    }

    // 用戶選擇其他排序時
    debugPrint('⚠️ [My Works] 用戶選擇排序: ${chatProvider.currentSortBy}');
    return _sortByUserChoice(tasks, chatProvider);
  }

  /// status_id 優先級排序（預設）
  List<Map<String, dynamic>> _sortByStatusId(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    final sortedTasks = List<Map<String, dynamic>>.from(tasks);

    sortedTasks.sort((a, b) {
      // 主鍵：status_id 升序（1,2,3...）
      final statusIdA = int.tryParse(a['status_id']?.toString() ?? '0') ?? 0;
      final statusIdB = int.tryParse(b['status_id']?.toString() ?? '0') ?? 0;
      int comparison = statusIdA.compareTo(statusIdB);

      // 次鍵：updated_at 降序（最新的在前）
      if (comparison == 0) {
        final timeA =
            DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
        final timeB =
            DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
        comparison = timeB.compareTo(timeA);
      }

      // 三次鍵：id 降序（穩定排序）
      if (comparison == 0) {
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        comparison = idB.compareTo(idA);
      }

      return comparison;
    });

    return sortedTasks;
  }

  /// 用戶自選排序
  List<Map<String, dynamic>> _sortByUserChoice(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    final sortedTasks = List<Map<String, dynamic>>.from(tasks);

    sortedTasks.sort((a, b) {
      int comparison = 0;

      switch (chatProvider.currentSortBy) {
        case 'updated_time':
          final timeA =
              DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
          final timeB =
              DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
          comparison = timeA.compareTo(timeB);
          break;

        default:
          // 其他排序選項暫時不支援，使用預設比較
          debugPrint('⚠️ [My Works] 不支援的排序選項: ${chatProvider.currentSortBy}');
          comparison = 0;
      }

      return chatProvider.sortAscending ? comparison : -comparison;
    });

    return sortedTasks;
  }

  String _displayStatus(Map<String, dynamic> task) {
    final dynamic display = task['status_display'];
    if (display != null && display is String && display.isNotEmpty) {
      return display;
    }
    final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
    return (codeOrLegacy ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            final chatProvider = context.read<ChatListProvider>();
            await chatProvider.cacheManager.forceRefresh();
            _pagingController.refresh();
          },
          child: PagedListView<int, Map<String, dynamic>>(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 80, // 保留底部距離，避免被 scroll to top button 遮擋
            ),
            pagingController: _pagingController,
            builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
              itemBuilder: (context, task, index) {
                return _buildTaskCard(task);
              },
              firstPageProgressIndicatorBuilder: (context) =>
                  _buildLoadingAnimation(),
              newPageProgressIndicatorBuilder: (context) =>
                  _buildPaginationLoadingAnimation(),
              noItemsFoundIndicatorBuilder: (context) => _buildEmptyState(),
            ),
          ),
        ),
        // Scroll to top button
        _buildScrollToTopButton(),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return _buildMyWorksChatRoomItem(task);
  }

  /// My Works 分頁的聊天室列表項目
  Widget _buildMyWorksChatRoomItem(Map<String, dynamic> task) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayStatus = TaskCardUtils.displayStatus(task);
    final progressData = TaskCardUtils.getProgressData(displayStatus);
    final progress = (progressData['progress'] is num)
        ? (progressData['progress'] as num).toDouble()
        : 0.0;
    final baseColor = (progressData['color'] is Color)
        ? progressData['color'] as Color
        : (Colors.grey[600]!);

    // 未讀（by_room）
    final roomId = (task['chat_room_id'] ?? '').toString();
    final provider = context.read<ChatListProvider>();

    return Card(
      key: ValueKey('myworks-task-$roomId'), // My Works 任務卡片綁定 room id
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () async {
              // 實現導航到聊天室
              final userService = context.read<UserService>();
              final currentUserId = userService.currentUser?.id;

              // 獲取正確的 task_id（不是 application_id）
              final taskId = task['task_id']?.toString() ?? '';
              final creatorId = (task['creator_id'] is int)
                  ? task['creator_id']
                  : int.tryParse('${task['creator_id']}') ?? 0;
              final participantId = (currentUserId is int)
                  ? currentUserId
                  : int.tryParse('$currentUserId') ?? 0;

              debugPrint('🔍 [My Works] 進入聊天室參數檢查:');
              debugPrint('  - task_id: $taskId');
              debugPrint('  - creator_id: $creatorId');
              debugPrint('  - participant_id: $participantId');
              debugPrint('  - 現有 chat_room_id: ${task['chat_room_id']}');

              if (taskId.isEmpty || creatorId <= 0 || participantId <= 0) {
                debugPrint(
                    '❌ [My Works] ensure_room 參數不足．\ntaskId: $taskId, \ncreatorId: $creatorId, \nparticipantId: $participantId');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('聊天室參數不足'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              // 使用統一的導航服務
              final success = await ChatNavigationService.ensureRoomAndNavigate(
                context: context,
                taskId: taskId,
                creatorId: creatorId,
                participantId: participantId,
                existingRoomId: task['chat_room_id']?.toString(),
                type: 'application',
              );

              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('無法進入聊天室'),
                    backgroundColor: Colors.red,
                  ),
                );
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
                          children: [
                            Expanded(
                              child: Text(
                                task['title'] ?? 'Untitled Task',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // 任務狀態
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            displayStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: baseColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 任務資訊 2x2 格局
                        _buildTaskInfoGrid(task, colorScheme),

                        const SizedBox(height: 8),

                        // 聊天對象與最新訊息
                        _buildChatPartnerSection(task),
                      ],
                    ),
                  ),

                  // 右側：未讀徽章和箭頭（任務卡層級圓點：若 unreadCount>0 顯示）
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Selector<ChatListProvider, int>(
                        selector: (context, provider) {
                          final roomId =
                              (task['chat_room_id'] ?? '').toString();
                          if (roomId.isEmpty) return 0;
                          try {
                            return provider.unreadForRoom(roomId);
                          } catch (_) {
                            return 0;
                          }
                        },
                        builder: (context, unreadCount, child) {
                          return unreadCount > 0
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const SizedBox(height: 16);
                        },
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 倒數計時懸浮在右上角
          if (TaskCardUtils.isCountdownStatus(displayStatus))
            Positioned(
              top: -8,
              right: -8,
              child: CompactCountdownTimerWidget(
                task: task,
                onCountdownComplete: () {
                  // TODO: 實現倒數計時完成邏輯
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskInfoGrid(
      Map<String, dynamic> task, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Column(
              children: [
                // 第一行：位置 + 日期
                Row(
                  children: [
                    // 位置
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              task['location'] ?? 'Not specified location.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 日期
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text(
                            DateFormat('MM/dd')
                                .format(_parseDateOrNow(task['task_date'])),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 第二行：獎勵 + 語言
                Row(
                  children: [
                    // 獎勵
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.attach_money,
                              size: 12, color: Colors.grey[600]),
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
                    // 語言要求
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.language,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              task['language_requirement'] ??
                                  'No language requirement.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
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
          ),
        ),
      ],
    );
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
            'Loading my works...',
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
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No applications found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t applied to any tasks yet',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 建構帶有錯誤回退的頭像
  Widget _buildAvatarWithFallback(
    String? avatarPath,
    String? name, {
    double radius = 16,
    double fontSize = 12,
  }) {
    return _MyWorksAvatarWithFallback(
      avatarPath: avatarPath,
      name: name ?? 'Unknown',
      radius: radius,
      fontSize: fontSize,
    );
  }

  /// 構建聊天對象與最新訊息區塊
  Widget _buildChatPartnerSection(Map<String, dynamic> task) {
    final creatorName = task['creator_name'] ?? 'Unknown';
    final creatorAvatar = task['creator_avatar'];
    final latestMessage =
        task['latest_message_snippet'] ?? 'No conversation yet';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // 創建者頭像
          _buildAvatarWithFallback(
            creatorAvatar?.toString(),
            creatorName,
            radius: 16,
            fontSize: 12,
          ),
          const SizedBox(width: 8),

          // 對象名稱與最新訊息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatorName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  latestMessage,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 建構 Scroll to Top 按鈕
  Widget _buildScrollToTopButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        onPressed: () {
          // 滾動到頂部
          final scrollController = PrimaryScrollController.of(context);
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        child: const Icon(Icons.keyboard_arrow_up, size: 24),
      ),
    );
  }
}

/// 帶有錯誤回退的頭像 Widget (MyWorks 版本)
class _MyWorksAvatarWithFallback extends StatefulWidget {
  final String? avatarPath;
  final String name;
  final double radius;
  final double fontSize;

  const _MyWorksAvatarWithFallback({
    required this.avatarPath,
    required this.name,
    required this.radius,
    required this.fontSize,
  });

  @override
  State<_MyWorksAvatarWithFallback> createState() =>
      _MyWorksAvatarWithFallbackState();
}

class _MyWorksAvatarWithFallbackState
    extends State<_MyWorksAvatarWithFallback> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final avatarPath = widget.avatarPath;

    // 如果沒有頭像路徑、已發生錯誤，或 URL 在失敗快取中，直接顯示首字母
    if (avatarPath == null ||
        avatarPath.isEmpty ||
        _hasError ||
        AvatarErrorCache.isFailedUrl(avatarPath)) {
      return _buildInitialsAvatar();
    }

    // 如果是相對路徑 (assets)
    if (avatarPath.startsWith('assets/')) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: TaskCardUtils.getAvatarColor(widget.name),
        backgroundImage: AssetImage(avatarPath),
        onBackgroundImageError: (exception, stackTrace) {
          AvatarErrorCache.addFailedUrl(avatarPath);
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        },
        child: _hasError ? _buildInitialsText() : null,
      );
    }

    // 如果是網路 URL
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: TaskCardUtils.getAvatarColor(widget.name),
        backgroundImage: NetworkImage(avatarPath),
        onBackgroundImageError: (exception, stackTrace) {
          AvatarErrorCache.addFailedUrl(avatarPath);
          debugPrint('🔴 MyWorks Avatar load error (cached): $avatarPath');
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        },
        child: _hasError ? _buildInitialsText() : null,
      );
    }

    // 其他格式不支援，顯示首字母
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: TaskCardUtils.getAvatarColor(widget.name),
      child: _buildInitialsText(),
    );
  }

  Widget _buildInitialsText() {
    return Text(
      TaskCardUtils.getInitials(widget.name),
      style: TextStyle(
        color: Colors.white,
        fontSize: widget.fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

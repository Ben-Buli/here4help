import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/services/smart_refresh_strategy.dart';
import 'package:here4help/chat/services/chat_navigation_service.dart';
import 'package:here4help/chat/utils/application_status_utils.dart';
import 'package:here4help/chat/widgets/highlighted_text.dart';
import 'package:here4help/chat/widgets/cached_avatar_widget.dart';
import 'package:here4help/chat/utils/avatar_cache_manager.dart';
import 'package:go_router/go_router.dart';

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
    final chatProvider = _getChatProvider();
    if (chatProvider == null) {
      debugPrint('⚠️ [My Works] _checkAndLoadIfNeeded 無法獲取 ChatListProvider');
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
          '  - 分頁載入狀態: ${chatProvider.isTabLoading(ChatListProvider.tabMyWorks)}');
      debugPrint(
          '  - 分頁載入完成: ${chatProvider.isTabLoaded(ChatListProvider.tabMyWorks)}');
      debugPrint(
          '  - 分頁錯誤: ${chatProvider.getTabError(ChatListProvider.tabMyWorks)}');

      // 如果分頁尚未載入且不在載入中，觸發載入
      if (!chatProvider.isTabLoaded(ChatListProvider.tabMyWorks) &&
          !chatProvider.isTabLoading(ChatListProvider.tabMyWorks)) {
        debugPrint('🚀 [My Works] 觸發分頁數據載入');
        chatProvider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
      } else {
        debugPrint('✅ [My Works] 分頁已載入或正在載入中');
      }
    } else {
      debugPrint('⏸️ [My Works] 當前不是 My Works 分頁，跳過載入');
    }
  }

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
      debugPrint('⚠️ [My Works] Context 已無效: $e');
      return null;
    }

    // 回退：僅在需要時才透過 context 取得，降低在 deactivated 階段觸發錯誤的機率
    try {
      return Provider.of<ChatListProvider>(context, listen: false);
    } catch (e) {
      debugPrint('⚠️ [My Works] 無法獲取 ChatListProvider: $e');
      return null;
    }
  }

  // 防抖機制：避免重複調用
  DateTime? _lastUpdateTime;
  static const Duration _updateDebounceDelay = Duration(milliseconds: 500);

  void _updateMyWorksTabUnreadFlag() {
    if (!mounted) {
      debugPrint('⚠️ [My Works] Widget 未掛載，跳過未讀狀態更新');
      return;
    }

    // 🔧 防抖檢查：避免頻繁調用
    final now = DateTime.now();
    if (_lastUpdateTime != null) {
      final timeDiff = now.difference(_lastUpdateTime!);
      if (timeDiff < _updateDebounceDelay) {
        debugPrint(
            '⏱️ [My Works] 防抖跳過更新，間隔: ${timeDiff.inMilliseconds}ms < ${_updateDebounceDelay.inMilliseconds}ms');
        return;
      }
    }
    _lastUpdateTime = now;

    try {
      debugPrint('🔄 [My Works] 開始更新 Tab 未讀狀態...');

      // 安全地獲取 Provider
      final provider = _getChatProvider();
      if (provider == null) {
        debugPrint('❌ [My Works] 無法獲取 ChatListProvider，跳過未讀狀態更新');
        return;
      }

      // 檢查所有未讀訊息映射中是否有大於 0 的計數
      bool hasUnread = false;
      int totalUnreadCount = 0;
      int roomsWithUnread = 0;

      for (final count in provider.unreadByRoom.values) {
        totalUnreadCount += count;
        if (count > 0) {
          hasUnread = true;
          roomsWithUnread++;
        }
      }

      debugPrint(
          '🔍 [My Works] 未讀統計: 總房間=${provider.unreadByRoom.length}, 有未讀房間=$roomsWithUnread, 總未讀數=$totalUnreadCount');

      final oldState = provider.hasUnreadForTab(ChatListProvider.tabMyWorks);
      debugPrint('🔍 [My Works] 狀態變化: $oldState -> $hasUnread');

      // 使用智能刷新策略的狀態更新器
      SmartRefreshStrategy.updateUnreadState(
        componentKey: 'MyWorks-Tab',
        oldState: oldState,
        newState: hasUnread,
        updateCallback: () {
          if (!mounted) {
            debugPrint('⚠️ [My Works] 回調中 Widget 未掛載，跳過狀態更新');
            return;
          }
          try {
            debugPrint('✅ [My Works] 執行 Tab 未讀狀態更新: $hasUnread');
            provider.setTabHasUnread(ChatListProvider.tabMyWorks, hasUnread);
            debugPrint('✅ [My Works] Tab 未讀狀態更新完成');
          } catch (e) {
            debugPrint('❌ [My Works] setTabHasUnread 失敗: $e');
            debugPrint('❌ [My Works] 錯誤堆疊: ${e.toString()}');
          }
        },
        description: 'My Works Tab 未讀狀態',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [My Works] _updateMyWorksTabUnreadFlag 失敗: $e');
      debugPrint('❌ [My Works] 錯誤堆疊: $stackTrace');
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

    // 主動載入數據到 ChatListProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('🚀 [My Works] 初始化時載入數據到 ChatListProvider');
        final chatProvider = _getChatProvider();
        if (chatProvider != null) {
          _refreshMyWorksData(chatProvider);
        }
      }
    });

    // 監聽 ChatListProvider 的篩選條件變化（僅針對當前tab）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final chatProvider = _getChatProvider();
        if (chatProvider != null) {
          chatProvider.addListener(_handleProviderChanges);

          // 檢查並按需載入數據
          _checkAndLoadIfNeeded();
        } else {
          debugPrint('⚠️ [My Works] initState 中無法獲取 ChatListProvider');
        }
      } catch (e) {
        debugPrint('❌ [My Works] initState 中設置 Provider listener 失敗: $e');
      }
    });

    // 移除重複監聽：NotificationCenter 已自動同步到 Provider
    // 只監聽未讀數據變化來更新 Tab 標記
    _unreadSub = NotificationCenter().byRoomStream.listen((map) {
      if (!mounted) return;
      debugPrint('🔍 [My Works] 收到未讀數據更新: ${map.length} 個房間');

      // 🔧 安全的延遲更新：多重檢查 mounted 狀態
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          debugPrint('⚠️ [My Works] PostFrame 回調中 Widget 已卸載，跳過更新');
          return;
        }

        // 🔧 額外檢查 context 有效性
        try {
          if (!context.mounted) {
            debugPrint('⚠️ [My Works] PostFrame 回調中 Context 已無效，跳過更新');
            return;
          }
        } catch (e) {
          debugPrint('⚠️ [My Works] PostFrame 回調中 Context 檢查失敗: $e');
          return;
        }

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

      // NotificationCenter 會自動同步到 Provider，無需手動呼叫 replaceUnreadByRoom
      debugPrint('✅ [My Works] 未讀數據初始化完成');
    } catch (e) {
      debugPrint('❌ [My Works] 未讀數據初始化失敗: $e');
    }
  }

  void _handleProviderChanges() {
    if (!mounted) return;

    try {
      final chatProvider = _getChatProvider();
      if (chatProvider == null) {
        debugPrint(
            '⚠️ [My Works] _handleProviderChanges 無法獲取 ChatListProvider');
        return;
      }

      // 只有當前是 My Works 分頁時才刷新
      if (chatProvider.isMyWorksTab) {
        // 搜尋和篩選變化時，不需要重新載入數據，只需要觸發 UI 重建
        // 因為篩選邏輯已經在 ChatListProvider.filteredMyWorks 中處理
        debugPrint('✅ [My Works] 篩選條件變化，觸發 UI 重建');

        // 使用智能刷新策略決策（僅在必要時重新載入數據）
        SmartRefreshStrategy.executeSmartRefresh(
          refreshKey: 'MyWorks-Provider',
          refreshCallback: () {
            if (!mounted) return;
            try {
              debugPrint('✅ [My Works] 執行數據重新載入');
              _refreshMyWorksData(chatProvider);
            } catch (e) {
              debugPrint('❌ [My Works] 數據重新載入失敗: $e');
            }
          },
          hasActiveFilters: chatProvider.hasActiveFilters,
          searchQuery: chatProvider.searchQuery,
          isUnreadUpdate: false, // 這不是未讀狀態更新
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
    debugPrint('🔄 [My Works] 開始 dispose...');

    // 🔧 清理防抖狀態
    _lastUpdateTime = null;

    // 移除 provider listener
    try {
      // 使用靜態實例而不是 context，避免在 dispose 中訪問 context
      final chatProvider = ChatListProvider.instance;
      if (chatProvider != null) {
        chatProvider.removeListener(_handleProviderChanges);
        debugPrint('✅ [My Works] 已移除 ChatListProvider listener');
      }
    } catch (e) {
      // Provider may not be available during dispose
      debugPrint('⚠️ [My Works] dispose 時移除 listener 失敗: $e');
    }

    // 🔧 安全地取消未讀數據訂閱
    try {
      _unreadSub?.cancel();
      _unreadSub = null;
      debugPrint('✅ [My Works] 已取消未讀數據訂閱');
    } catch (e) {
      debugPrint('⚠️ [My Works] 取消未讀數據訂閱失敗: $e');
    }

    // 🔧 安全地清理分頁控制器
    try {
      _pagingController.dispose();
      debugPrint('✅ [My Works] 已清理分頁控制器');
    } catch (e) {
      debugPrint('⚠️ [My Works] 清理分頁控制器失敗: $e');
    }

    debugPrint('✅ [My Works] dispose 完成');
    super.dispose();
  }

  Future<void> _fetchMyWorksPage(int offset) async {
    try {
      debugPrint('🔍 [My Works] _fetchMyWorksPage 開始，offset: $offset');

      // 安全地獲取 Provider
      UserService? userService;

      try {
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

  /// 刷新 My Works 數據到 ChatListProvider
  Future<void> _refreshMyWorksData(ChatListProvider chatProvider) async {
    try {
      debugPrint('🔄 [My Works] 開始刷新數據到 ChatListProvider...');

      // 安全地獲取 UserService
      UserService? userService;
      try {
        userService = context.read<UserService>();
      } catch (e) {
        debugPrint('⚠️ [My Works] 無法獲取 UserService: $e');
        return;
      }

      final currentUserId = userService.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('❌ [My Works] 用戶未登入，無法刷新數據');
        return;
      }

      // 載入所有 My Works 數據（不分頁）
      final taskService = TaskService();
      final page = await taskService.fetchMyWorksApplications(
        userId: currentUserId.toString(),
        limit: 100, // 載入更多數據
        offset: 0,
      );

      final processedData = _processApplicationsFromService(page.items);

      // 更新 ChatListProvider 的 My Works 快取並標記載入完成
      chatProvider.replaceMyWorksApplications(processedData, markLoaded: true);

      // 預載入頭像
      _preloadAvatars(processedData);

      debugPrint('✅ [My Works] 數據刷新完成: ${processedData.length} 個任務');
    } catch (e) {
      debugPrint('❌ [My Works] 刷新數據失敗: $e');
    }
  }

  /// 預載入頭像數據
  void _preloadAvatars(List<Map<String, dynamic>> tasks) {
    try {
      final avatarPaths = <String>[];

      // 收集所有創建者的頭像路徑
      for (final task in tasks) {
        final creatorAvatar = task['creator_avatar']?.toString();
        if (creatorAvatar != null &&
            creatorAvatar.isNotEmpty &&
            !avatarPaths.contains(creatorAvatar)) {
          avatarPaths.add(creatorAvatar);
        }
      }

      if (avatarPaths.isNotEmpty) {
        debugPrint('🚀 [My Works] 開始預載入 ${avatarPaths.length} 個頭像');
        AvatarCacheManager.preloadAvatars(avatarPaths);
      }
    } catch (e) {
      debugPrint('❌ [My Works] 預載入頭像失敗: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 使用 ChatListProvider 的篩選結果（支援即時搜尋和篩選）
        Consumer<ChatListProvider>(
          builder: (context, chatProvider, child) {
            final filteredWorks = chatProvider.filteredMyWorks;

            if (kDebugMode) {
              debugPrint(
                  '🔍 [My Works] 使用 ChatListProvider 篩選結果: ${filteredWorks.length} 個任務');
              debugPrint('  - 搜尋查詢: "${chatProvider.searchQuery}"');
              debugPrint('  - 選中位置: ${chatProvider.selectedLocations}');
              debugPrint('  - 選中狀態: ${chatProvider.selectedStatuses}');
            }

            return RefreshIndicator(
              onRefresh: () async {
                try {
                  await chatProvider.cacheManager.forceRefresh();
                  // 重新載入 My Works 數據到 Provider 的快取中
                  await _refreshMyWorksData(chatProvider);
                } catch (e) {
                  debugPrint('❌ [My Works] 刷新失敗: $e');
                }
              },
              child: filteredWorks.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: _buildEmptyState(
                              isDataError: chatProvider.getTabError(
                                      ChatListProvider.tabMyWorks) !=
                                  null,
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
                      itemCount: filteredWorks.length,
                      itemBuilder: (context, index) {
                        final task = filteredWorks[index];
                        return _buildTaskCard(task);
                      },
                    ),
            );
          },
        ),
        // 棄用 Scroll to top button
        // _buildScrollToTopButton(),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return _buildMyWorksChatRoomItem(task);
  }

  /// My Works 分頁的聊天室列表項目
  Widget _buildMyWorksChatRoomItem(Map<String, dynamic> task) {
    final colorScheme = Theme.of(context).colorScheme;

    // 使用 ApplicationStatusUtils 來獲取狀態資訊
    final applicationStatus = task['application_status']?.toString();
    final displayStatus =
        ApplicationStatusUtils.getDisplayName(applicationStatus);
    final progressData =
        ApplicationStatusUtils.getProgressData(applicationStatus);
    final progress = (progressData['progress'] is num)
        ? (progressData['progress'] as num).toDouble()
        : 0.0;
    final baseColor = (progressData['color'] is Color)
        ? progressData['color'] as Color
        : ApplicationStatusUtils.getStatusColor(applicationStatus);

    // 未讀（by_room）
    final roomId = (task['chat_room_id'] ?? '').toString();

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
              // 點擊任務卡片時關閉鍵盤
              FocusScope.of(context).unfocus();

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

              debugPrint(
                  '  - task_id: $taskId,creator_id: $creatorId,participant_id: $participantId,existing_room_id: ${task['chat_room_id']}');

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
              final currentLocation = GoRouterState.of(context).uri.toString();

              final success = await ChatNavigationService.ensureRoomAndNavigate(
                context: context,
                taskId: taskId,
                creatorId: creatorId,
                participantId: participantId,
                existingRoomId: task['chat_room_id']?.toString(),
                type: 'application',
                sourceTab: 'my-works',
                returnPath: currentLocation,
              );

              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot enter chat room'),
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
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
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
          if (ApplicationStatusUtils.isCountdownStatus(applicationStatus))
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
  Widget _buildEmptyState({bool isDataError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isDataError ? Icons.error_outline : Icons.work_outline,
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
            isDataError
                ? 'No applications found'
                : 'You haven\'t applied to any tasks yet',
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

  /// 建構帶有錯誤回退的頭像（使用快取）
  Widget _buildAvatarWithFallback(
    String? avatarPath,
    String? name, {
    double radius = 16,
    double fontSize = 12,
  }) {
    return CachedAvatarWidget(
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

  /// 棄用：建構 Scroll to Top 按鈕
  // Widget _buildScrollToTopButton() {
  //   return Positioned(
  //     right: 16,
  //     bottom: 16,
  //     child: FloatingActionButton(
  //       backgroundColor: Theme.of(context).colorScheme.primary,
  //       foregroundColor: Theme.of(context).colorScheme.onPrimary,
  //       onPressed: () {
  //         // 滾動到頂部
  //         final scrollController = PrimaryScrollController.of(context);
  //         scrollController.animateTo(
  //           0,
  //           duration: const Duration(milliseconds: 500),
  //           curve: Curves.easeInOut,
  //         );
  //       },
  //       child: const Icon(Icons.keyboard_arrow_up, size: 24),
  //     ),
  //   );
  // }

  /// 執行自動完成任務（倒數計時結束時觸發）
  void _executeAutoCompleteTask(Map<String, dynamic> task) async {
    final taskId = task['id'].toString();

    try {
      debugPrint('⏰ [My Works] 倒數計時結束，開始自動完成任務: $taskId');

      // 使用現有的 confirmCompletion API 來自動完成任務
      final taskService = TaskService();
      await taskService.confirmCompletion(
        taskId: taskId,
        preview: false, // 直接執行，不預覽
      );

      if (mounted) {
        // 刷新任務列表
        setState(() {
          // 觸發重新載入
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task "${task['title']}" has been automatically completed'),
            backgroundColor: Colors.green,
          ),
        );

        debugPrint('✅ [My Works] 任務自動完成成功: $taskId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to auto complete task: $e'),
            backgroundColor: Colors.red,
          ),
        );

        debugPrint('❌ [My Works] 任務自動完成失敗: $taskId, 錯誤: $e');
      }
    }
  }
}

// 舊的 _MyWorksAvatarWithFallback 已移除，統一使用 CachedAvatarWidget

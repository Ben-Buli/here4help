import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/widgets/task_card_components.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/utils/avatar_error_cache.dart';
import 'package:here4help/chat/services/smart_refresh_strategy.dart';

/// Posted Tasks 分頁組件
/// 從原 ChatListPage 中抽取的 Posted Tasks 相關功能
class PostedTasksWidget extends StatefulWidget {
  const PostedTasksWidget({super.key});

  @override
  State<PostedTasksWidget> createState() => _PostedTasksWidgetState();
}

class _PostedTasksWidgetState extends State<PostedTasksWidget> {
  static const int _pageSize = 10;
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 0);

  // Posted Tasks 應徵者資料快取
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // 手風琴展開狀態管理
  final Set<String> _expandedTaskIds = <String>{};

  // 未讀映射（room_id -> count）
  Map<String, int> _unreadByRoom = {};
  StreamSubscription<Map<String, int>>? _unreadSub;
  bool _unreadDataLoaded = false; // 追蹤未讀數據是否已載入

  // 搜尋狀態追蹤
  String _lastSearchQuery = '';
  Set<String> _lastSelectedLocations = {};
  Set<String> _lastSelectedStatuses = {};

  void _updatePostedTabUnreadFlag() {
    if (!mounted) return;
    bool hasUnread = false;
    for (final appliers in _applicationsByTask.values) {
      for (final ap in appliers) {
        final roomId = ap['chat_room_id']?.toString();
        if (roomId != null && roomId.isNotEmpty) {
          final cnt = _unreadByRoom[roomId] ?? 0;
          if (cnt > 0) {
            hasUnread = true;
            break;
          }
        }
      }
      if (hasUnread) break;
    }

    try {
      final provider = context.read<ChatListProvider>();
      final oldState = provider.hasUnreadForTab(0);

      // 使用智能刷新策略的狀態更新器
      SmartRefreshStrategy.updateUnreadState(
        componentKey: 'PostedTasks-Tab',
        oldState: oldState,
        newState: hasUnread,
        updateCallback: () {
          debugPrint('✅ [Posted Tasks] 更新 Tab 未讀狀態: $hasUnread');
          provider.setTabHasUnread(0, hasUnread);
        },
        description: 'Posted Tasks Tab 未讀狀態',
      );
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 更新 Tab 未讀狀態失敗: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // 確保未讀數據已載入
    _ensureUnreadDataLoaded();

    _pagingController.addPageRequestListener((offset) {
      // 若剛發生 provider 事件且當前仍在 build 期，延後一幀避免循環
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPage(offset));
      } else {
        _fetchPage(offset);
      }
    });

    // 監聽 ChatListProvider 的篩選條件變化（僅針對當前tab）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatListProvider>();
      chatProvider.addListener(_handleProviderChanges);
    });

    // 監聽未讀快照
    _unreadSub = NotificationCenter().byRoomStream.listen((map) {
      if (!mounted) return;
      debugPrint('🔍 [Posted Tasks] 收到未讀數據更新: ${map.length} 個房間');
      setState(() {
        _unreadByRoom = Map<String, int>.from(map);
        _unreadDataLoaded = true; // 標記未讀數據已載入
      });
      // 使用 _unreadDataLoaded 確保數據完整性
      if (_unreadDataLoaded) {
        debugPrint('✅ [Posted Tasks] 未讀數據已同步完成');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updatePostedTabUnreadFlag();
      });
    });
  }

  /// 確保未讀數據已載入
  Future<void> _ensureUnreadDataLoaded() async {
    try {
      debugPrint('🔄 [Posted Tasks] 開始確保未讀數據載入...');

      // 等待 NotificationCenter 初始化完成
      await NotificationCenter().waitForUnreadData();

      // 強制刷新快照
      await NotificationCenter().service.refreshSnapshot();
      debugPrint('✅ [Posted Tasks] 未讀數據初始化完成');
    } catch (e) {
      debugPrint('❌ [Posted Tasks] 未讀數據初始化失敗: $e');
    }
  }

  void _handleProviderChanges() {
    if (!mounted) return;

    try {
      final chatProvider = context.read<ChatListProvider>();
      // 只有當前是 Posted Tasks 分頁時才刷新
      if (chatProvider.currentTabIndex == 0) {
        final currentSearchQuery = chatProvider.searchQuery;
        final currentLocations =
            Set<String>.from(chatProvider.selectedLocations);
        final currentStatuses = Set<String>.from(chatProvider.selectedStatuses);

        debugPrint('🔄 [Posted Tasks] Provider 變化檢測:');
        debugPrint('  - 當前搜尋查詢: "$currentSearchQuery"');
        debugPrint('  - 上次搜尋查詢: "$_lastSearchQuery"');
        debugPrint('  - 搜尋查詢變化: ${currentSearchQuery != _lastSearchQuery}');
        debugPrint('  - 有活躍篩選: ${chatProvider.hasActiveFilters}');
        debugPrint('  - 選中位置: ${currentLocations}');
        debugPrint('  - 選中狀態: ${currentStatuses}');

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
          debugPrint('✅ [Posted Tasks] 檢測到篩選條件變化，觸發刷新');

          // 更新追蹤狀態
          _lastSearchQuery = currentSearchQuery;
          _lastSelectedLocations = currentLocations;
          _lastSelectedStatuses = currentStatuses;

          // 使用智能刷新策略決策
          SmartRefreshStrategy.executeSmartRefresh(
            refreshKey: 'PostedTasks-Provider',
            refreshCallback: () {
              debugPrint('✅ [Posted Tasks] 執行智能刷新');
              _pagingController.refresh();
            },
            hasActiveFilters: chatProvider.hasActiveFilters,
            searchQuery: currentSearchQuery,
            isUnreadUpdate: false, // 這是篩選條件變化，不是未讀狀態更新
            forceRefresh: false,
            enableDebounce: true,
          );
        } else {
          debugPrint('🔄 [Posted Tasks] 無篩選條件變化，跳過刷新');
        }
      }
    } catch (e) {
      debugPrint('❌ [Posted Tasks] Provider 變化處理失敗: $e');
    }
  }

  @override
  void dispose() {
    // 移除 provider listener
    try {
      final chatProvider = context.read<ChatListProvider>();
      chatProvider.removeListener(_handleProviderChanges);
    } catch (e) {
      // Provider may not be available during dispose
    }
    _unreadSub?.cancel();
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int offset) async {
    try {
      final chatProvider = context.read<ChatListProvider>();
      final service = TaskService();

      // Posted Tasks 只載入當前用戶發布的任務
      final userService = context.read<UserService>();
      final currentUserId = userService.currentUser?.id;

      if (currentUserId == null) {
        _pagingController.appendLastPage([]);
        return;
      }

      // 構建篩選條件
      Map<String, String>? filters;

      // 如果有搜尋關鍵字，暫時移除位置篩選以允許跨位置搜尋
      final hasSearchQuery = chatProvider.searchQuery.trim().isNotEmpty;

      if (chatProvider.selectedLocations.isNotEmpty && !hasSearchQuery) {
        filters ??= {};
        filters['location'] = chatProvider.selectedLocations.first;
        debugPrint(
            '🔍 [Posted Tasks] 應用位置篩選: ${chatProvider.selectedLocations.first}');
      } else if (hasSearchQuery) {
        debugPrint('🔍 [Posted Tasks] 有搜尋關鍵字，跳過位置篩選以允許跨位置搜尋');
      }

      if (chatProvider.selectedStatuses.isNotEmpty) {
        filters ??= {};
        filters['status'] = chatProvider.selectedStatuses.first;
      }

      // 使用新的聚合API
      final result = await service.fetchPostedTasksAggregated(
        limit: _pageSize,
        offset: offset,
        creatorId: currentUserId.toString(),
        filters: filters,
      );

      if (!mounted) return;

      // 直接從聚合API獲取應徵者數據
      for (final task in result.tasks) {
        final taskId = task['id'].toString();
        final applicantsRaw = task['applicants'] ?? [];
        final List<Map<String, dynamic>> applicants = (applicantsRaw is List)
            ? applicantsRaw.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _applicationsByTask[taskId] = applicants;
        // debugPrint('🔍 [Posted Tasks] 任務 $taskId 有 ${applicants.length} 個應徵者');
      }
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updatePostedTabUnreadFlag());

      // 應用篩選和排序
      final filteredTasks = _filterTasks(result.tasks, chatProvider);
      final sortedTasks = _sortTasks(filteredTasks, chatProvider);

      debugPrint('📊 [Posted Tasks] 分頁處理:');
      debugPrint('  - 原始任務數: ${result.tasks.length}');
      debugPrint('  - 篩選後任務數: ${filteredTasks.length}');
      debugPrint('  - 排序後任務數: ${sortedTasks.length}');
      debugPrint('  - 當前 offset: $offset');
      debugPrint('  - 頁面大小: $_pageSize');
      debugPrint('  - API 返回 hasMore: ${result.hasMore}');

      // 修正分頁邏輯 - 統一處理，避免重複卡片
      final hasMoreData = result.hasMore && sortedTasks.length >= _pageSize;

      if (sortedTasks.isNotEmpty) {
        // 計算下一頁的正確 offset
        final nextPageKey = hasMoreData ? offset + _pageSize : null;

        debugPrint(
            '  - 有數據，hasMoreData: $hasMoreData, nextPageKey: $nextPageKey');

        if (nextPageKey != null) {
          _pagingController.appendPage(sortedTasks, nextPageKey);
          debugPrint('  ✅ 添加分頁數據，下一頁 key: $nextPageKey');
        } else {
          _pagingController.appendLastPage(sortedTasks);
          debugPrint('  ✅ 添加最後一頁數據');
        }
      } else {
        // 沒有數據時，檢查是否為搜尋/篩選結果
        debugPrint('  - 沒有數據，檢查篩選條件');
        debugPrint('    - hasActiveFilters: ${chatProvider.hasActiveFilters}');
        debugPrint('    - searchQuery: "${chatProvider.searchQuery}"');

        if (chatProvider.hasActiveFilters ||
            chatProvider.searchQuery.isNotEmpty) {
          _pagingController.appendLastPage([]);
          debugPrint('  ✅ 篩選結果為空，顯示空狀態');
        } else if (offset == 0) {
          // 第一頁就沒有數據
          _pagingController.appendLastPage([]);
          debugPrint('  ✅ 第一頁無數據，顯示空狀態');
        } else {
          // 後續頁面沒有更多數據
          _pagingController.appendLastPage([]);
          debugPrint('  ✅ 後續頁面無數據，顯示空狀態');
        }
      }
    } catch (error) {
      debugPrint('❌ [Posted Tasks] 獲取任務失敗: $error');
      if (mounted) {
        _pagingController.error = error;
      }
    }
  }

  /// 篩選任務列表
  List<Map<String, dynamic>> _filterTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    debugPrint('🔍 [Posted Tasks] 開始篩選任務: ${tasks.length} 個任務');
    debugPrint('  - 搜尋關鍵字: "${chatProvider.searchQuery}"');
    debugPrint('  - 選中位置: ${chatProvider.selectedLocations}');
    debugPrint('  - 選中狀態: ${chatProvider.selectedStatuses}');

    // 調試：顯示所有任務的標題
    debugPrint('📋 所有任務標題:');
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final title = task['title'] ?? 'NO_TITLE';
      final id = task['id'] ?? 'NO_ID';
      debugPrint('  [$i] ID: $id, Title: "$title"');
    }

    final filteredTasks = tasks.where((task) {
      // 調試：顯示當前任務的完整數據
      debugPrint('🔍 檢查任務: ${task['id']}');
      debugPrint('  - 原始 title: "${task['title']}"');
      debugPrint('  - 原始 description: "${task['description']}"');
      debugPrint('  - 所有可用欄位: ${task.keys.toList()}');

      final rawQuery = chatProvider.searchQuery.trim();
      final hasSearchQuery = rawQuery.isNotEmpty;

      final title = (task['title'] ?? '').toString();
      final description = (task['description'] ?? '').toString();
      final location = (task['location'] ?? '').toString();
      final language = (task['language_requirement'] ?? '').toString();
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

      // 搜尋：多欄位匹配
      bool matchQuery = true;
      if (hasSearchQuery) {
        matchQuery = nTitle.contains(normalizedQuery) ||
            nDesc.contains(normalizedQuery) ||
            nLoc.contains(normalizedQuery) ||
            nLang.contains(normalizedQuery) ||
            nStatus.contains(normalizedQuery) ||
            nTags.contains(normalizedQuery);

        if (!matchQuery) {
          debugPrint('  ❌ 任務 "${task['title']}" 不符合搜尋條件 (多欄位)');
          return false;
        }
      }

      // 位置篩選
      final locationVal = (task['location'] ?? '').toString();
      // 若有搜尋關鍵字則忽略位置篩選，確保完整搜尋
      final matchLocation = hasSearchQuery ||
          chatProvider.selectedLocations.isEmpty ||
          chatProvider.selectedLocations.contains(locationVal);
      if (!matchLocation) {
        debugPrint('  ❌ 任務 "${task['title']}" 位置 "$locationVal" 不符合篩選條件');
        return false;
      }

      // 狀態篩選
      final status = _displayStatus(task);
      final matchStatus = chatProvider.selectedStatuses.isEmpty ||
          chatProvider.selectedStatuses.contains(status);
      if (!matchStatus) {
        debugPrint('  ❌ 任務 "${task['title']}" 狀態 "$status" 不符合篩選條件');
        return false;
      }

      debugPrint('  ✅ 任務 "${task['title']}" 通過所有篩選條件');
      return true;
    }).toList();

    debugPrint('🔍 [Posted Tasks] 篩選完成: ${filteredTasks.length} 個任務');
    return filteredTasks;
  }

  /// 排序任務列表
  List<Map<String, dynamic>> _sortTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    debugPrint('🔄 [Posted Tasks] 開始排序任務: ${tasks.length} 個任務');
    debugPrint('  - 排序方式: ${chatProvider.currentSortBy}');
    debugPrint('  - 排序方向: ${chatProvider.sortAscending ? "升序" : "降序"}');

    final sortedTasks = List<Map<String, dynamic>>.from(tasks);

    sortedTasks.sort((a, b) {
      int comparison = 0;

      switch (chatProvider.currentSortBy) {
        case 'status_order':
          final soA = (a['sort_order'] as num?)?.toInt() ?? 999;
          final soB = (b['sort_order'] as num?)?.toInt() ?? 999;
          if (soA != soB) {
            comparison = soA.compareTo(soB);
            break;
          }
          // 次序：updated_at DESC
          final timeA =
              DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
          final timeB =
              DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
          comparison = timeB.compareTo(timeA);
          break;
        case 'updated_time':
          final timeA =
              DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
          final timeB =
              DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
          comparison = timeA.compareTo(timeB);
          break;

        case 'applicant_count':
          final countA =
              (_applicationsByTask[a['id']?.toString()] ?? []).length;
          final countB =
              (_applicationsByTask[b['id']?.toString()] ?? []).length;
          comparison = countA.compareTo(countB);
          break;

        case 'status_code':
          final statusA = a['status_code'] ?? '';
          final statusB = b['status_code'] ?? '';
          comparison = statusA.compareTo(statusB);
          break;

        default:
          comparison = 0;
      }

      final finalComparison =
          chatProvider.sortAscending ? comparison : -comparison;

      // 調試排序結果
      if (finalComparison != 0) {
        final aTitle = a['title'] ?? 'Unknown';
        final bTitle = b['title'] ?? 'Unknown';
        debugPrint(
            '  🔄 排序: "$aTitle" ${finalComparison > 0 ? ">" : "<"} "$bTitle"');
      }

      return finalComparison;
    });

    debugPrint('🔄 [Posted Tasks] 排序完成');
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

  /// 正規化搜尋文本 - 移除特殊字符並轉為小寫
  String _normalizeSearchText(String text) {
    if (text.isEmpty) return '';

    // 更寬鬆的正規化，保留更多字符
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\-\(\)\.\,\:\;\!\?]'), '') // 保留更多標點符號
        .replaceAll(RegExp(r'\s+'), ' ') // 將多個空格替換為單個空格
        .trim();

    debugPrint('🔍 正規化搜尋文本: "$text" -> "$normalized"');
    return normalized;
  }

  // (removed) 舊的測試搜尋匹配函式已整合至多欄位搜尋邏輯

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        debugPrint('🔄 [Posted Tasks] 下拉重新整理開始');
        try {
          // 清除快取數據
          final chatProvider = context.read<ChatListProvider>();
          await chatProvider.cacheManager.forceRefresh();

          // 清除本地快取
          _applicationsByTask.clear();
          _expandedTaskIds.clear();

          // 重新載入未讀數據
          await _ensureUnreadDataLoaded();

          // 刷新分頁數據
          _pagingController.refresh();

          debugPrint('✅ [Posted Tasks] 下拉重新整理完成');
        } catch (e) {
          debugPrint('❌ [Posted Tasks] 下拉重新整理失敗: $e');
        }
      },
      child: Stack(
        children: [
          PagedListView<int, Map<String, dynamic>>(
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
          // Scroll to top button
          _buildScrollToTopButton(),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final taskId = task['id'].toString();
    final applicants = _applicationsByTask[taskId] ?? [];

    // 新的聚合API直接返回應徵者資料，不需要轉換
    final applierChatItems = applicants
        .map((applicant) => {
              'id':
                  'app_${applicant['application_id'] ?? applicant['user_id']}',
              'taskId': taskId,
              'name': applicant['applier_name'] ?? 'Anonymous',
              'avatar': applicant['applier_avatar'],
              'rating': applicant['avg_rating'] ?? 0.0,
              'reviewsCount': applicant['review_count'] ?? 0,
              'questionReply': applicant['cover_letter'] ?? '',
              'sentMessages': [
                applicant['first_message_snippet'] ?? 'Applied for this task'
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

    // debugPrint('🔍 [Posted Tasks] 建構任務卡片 $taskId，應徵者數量: ${applierChatItems.length}');

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
                                  child: Text(
                                    task['title'] ?? 'Untitled Task',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: null,
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                                // Emoji 狀態列（popular > new）
                                Builder(builder: (_) {
                                  final isPopular = TaskCardUtils.isPopularTask(
                                      task, _applicationsByTask);
                                  final isNew = TaskCardUtils.isNewTask(task);
                                  final String? emoji =
                                      isPopular ? '🔥' : (isNew ? '🌱' : null);
                                  return emoji == null
                                      ? const SizedBox.shrink()
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(emoji,
                                                style: const TextStyle(
                                                    fontSize: 16)),
                                            const SizedBox(width: 4),
                                          ],
                                        );
                                }),
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
                          Builder(builder: (_) {
                            final hasUnread = visibleAppliers.any((ap) {
                              final roomId = ap['chat_room_id']?.toString();
                              if (roomId == null || roomId.isEmpty)
                                return false;
                              final cnt = _unreadByRoom[roomId] ?? 0;
                              return cnt > 0;
                            });
                            // 向 Provider 回報當前分頁是否有未讀（避免 build 期間 setState）
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              try {
                                context
                                    .read<ChatListProvider>()
                                    .setTabHasUnread(0, hasUnread);
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
                          }),
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
          : Center(
              child: SizedBox(
                width: 120,
                child: OutlinedButton.icon(
                  onPressed: () => _showTaskInfoDialog(task),
                  icon: Icon(Icons.info_outline,
                      size: 16, color: colorScheme.primary),
                  label: Text('Info',
                      style:
                          TextStyle(fontSize: 12, color: colorScheme.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colorScheme.primary),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
            ),
    );
  }

  /// 建構帶有錯誤回退的頭像
  Widget _buildAvatarWithFallback(
    String? avatarPath,
    String? name, {
    double radius = 20,
    double fontSize = 14,
  }) {
    return _AvatarWithFallback(
      avatarPath: avatarPath,
      name: name ?? 'Unknown',
      radius: radius,
      fontSize: fontSize,
    );
  }

  Widget _buildApplierCard(
      Map<String, dynamic> applier, String taskId, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
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
                  applier['name'] ?? 'Unknown name',
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
                  Icon(Icons.star, color: Colors.amber[600], size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '${applier['rating'] ?? 0.0}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    '(${applier['reviewsCount'] ?? 0})',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          subtitle: Text(
            applier['latest_message_snippet'] ??
                applier['first_message_snippet'] ??
                'No messages',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: // 未讀數字徽章（警示色）
              Builder(builder: (_) {
            final roomId = applier['chat_room_id']?.toString();
            final unread = roomId == null ? 0 : (_unreadByRoom[roomId] ?? 0);
            if (unread <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          }),
          onTap: () {
            final chatRoomId = applier['chat_room_id'];
            if (chatRoomId != null) {
              // 直接跳轉到聊天詳情頁面
              context.go('/chat/detail?room_id=$chatRoomId');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Chat room not available for ${applier['name']}')),
              );
            }
          },
        ),
      ),
    );
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
      desc: _buildTaskDescription(task),
      descTextStyle: TextStyle(
        fontSize: 14,
        color: theme.onSurface.withValues(alpha: 0.8),
        height: 1.4,
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
      context.go('/task/create', extra: task);
      return;
    }
    // 優先載入聚合資料再前往編輯
    TaskService()
        .fetchTaskEditData(taskId)
        .then((fullTask) => context.go('/task/create', extra: fullTask ?? task))
        .catchError((_) => context.go('/task/create', extra: task));
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

  /// 刪除任務（設置狀態為 canceled）
  void _deleteTask(Map<String, dynamic> task) async {
    try {
      final taskService = TaskService();
      await taskService.updateTaskStatus(
        task['id'].toString(),
        'canceled',
        statusId: 8,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted successfully')),
        );
        _pagingController.refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
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
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
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
            'Try adjusting your search or filters',
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

/// 帶有錯誤回退的頭像 Widget
class _AvatarWithFallback extends StatefulWidget {
  final String? avatarPath;
  final String name;
  final double radius;
  final double fontSize;

  const _AvatarWithFallback({
    required this.avatarPath,
    required this.name,
    required this.radius,
    required this.fontSize,
  });

  @override
  State<_AvatarWithFallback> createState() => _AvatarWithFallbackState();
}

class _AvatarWithFallbackState extends State<_AvatarWithFallback> {
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
          debugPrint('🔴 Avatar load error (cached): $avatarPath');
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

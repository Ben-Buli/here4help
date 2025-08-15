import 'package:flutter/material.dart';
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

/// My Works 分頁組件
/// 從原 ChatListPage 中抽取的 My Works 相關功能
class MyWorksWidget extends StatefulWidget {
  const MyWorksWidget({super.key});

  @override
  State<MyWorksWidget> createState() => _MyWorksWidgetState();
}

class _MyWorksWidgetState extends State<MyWorksWidget> {
  static const int _pageSize = 10;
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((offset) {
      _fetchMyWorksPage(offset);
    });

    // 監聽 ChatListProvider 的篩選條件變化（僅針對當前tab）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatListProvider>();
      chatProvider.addListener(_handleProviderChanges);
    });
  }

  void _handleProviderChanges() {
    if (!mounted) return;

    try {
      final chatProvider = context.read<ChatListProvider>();
      // 只有當前是 My Works 分頁時才刷新
      if (chatProvider.currentTabIndex == 1) {
        _pagingController.refresh();
      }
    } catch (e) {
      // Context may not be available
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
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyWorksPage(int offset) async {
    try {
      final chatProvider = context.read<ChatListProvider>();
      final taskService = TaskService();
      final currentUserId = context.read<UserService>().currentUser?.id;

      if (currentUserId != null) {
        await taskService.loadMyApplications(currentUserId);
      }

      final all = _composeMyWorks(taskService, currentUserId);

      // 應用篩選和排序
      final filtered = _filterTasks(all, chatProvider);
      final sorted = _sortTasks(filtered, chatProvider);

      final start = offset;
      final end = (offset + _pageSize) > sorted.length
          ? sorted.length
          : (offset + _pageSize);
      final slice = sorted.sublist(start, end);
      final hasMore = end < sorted.length;

      if (!mounted) return;

      if (hasMore) {
        _pagingController.appendPage(slice, end);
      } else {
        _pagingController.appendLastPage(slice);
      }
    } catch (error) {
      if (mounted) {
        _pagingController.error = error;
      }
    }
  }

  /// 整理 My Works 清單：直接使用 API 返回的應徵數據
  List<Map<String, dynamic>> _composeMyWorks(
      TaskService service, int? currentUserId) {
    final apps = service.myApplications;

    // 如果沒有應徵數據，返回空列表
    if (apps.isEmpty) {
      return [];
    }

    // 直接使用 API 返回的應徵數據，轉換為任務格式
    return apps.map((app) {
      return {
        'id': app['id'],
        'title': app['title'],
        'description': app['description'],
        'reward_point': app['reward_point'],
        'location': app['location'],
        'task_date': app['task_date'],
        'language_requirement': app['language_requirement'],
        'status_code': app['client_status_code'] ?? app['status_code'],
        'status_display': app['client_status_display'] ?? app['status_display'],
        'creator_id': app['creator_id'],
        'creator_name': app['creator_name'],
        'creator_avatar': app['creator_avatar'],
        'applied_by_me': true,
        'application_id': app['application_id'],
        'application_status': app['application_status'],
        'application_created_at': app['application_created_at'],
        'application_updated_at': app['application_updated_at'],
      };
    }).toList();
  }

  /// 篩選任務列表
  List<Map<String, dynamic>> _filterTasks(
      List<Map<String, dynamic>> tasks, ChatListProvider chatProvider) {
    return tasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final query = chatProvider.searchQuery.toLowerCase();

      // 搜尋篩選
      final matchQuery = query.isEmpty || title.contains(query);

      // 位置篩選
      final location = (task['location'] ?? '').toString();
      final matchLocation = chatProvider.selectedLocations.isEmpty ||
          chatProvider.selectedLocations.contains(location);

      // 狀態篩選
      final status = _displayStatus(task);
      final matchStatus = chatProvider.selectedStatuses.isEmpty ||
          chatProvider.selectedStatuses.contains(status);

      return matchQuery && matchLocation && matchStatus;
    }).toList();
  }

  /// 排序任務列表
  List<Map<String, dynamic>> _sortTasks(
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

        case 'status_code':
          final statusA = a['status_code'] ?? '';
          final statusB = b['status_code'] ?? '';
          comparison = statusA.compareTo(statusB);
          break;

        default:
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
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;

    // 計算未讀訊息數量 (TODO: 實現真實計數)
    const unreadCount = 0;

    return Card(
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
              final taskId = task['id']?.toString() ?? '';
              final creatorId = (task['creator_id'] is int)
                  ? task['creator_id']
                  : int.tryParse('${task['creator_id']}') ?? 0;
              final participantId = (currentUserId is int)
                  ? currentUserId
                  : int.tryParse('$currentUserId') ?? 0;

              if (taskId.isEmpty || creatorId <= 0 || participantId <= 0) {
                debugPrint('❌ [My Works] ensure_room 參數不足');
                return;
              }

              try {
                final chatService = ChatService();
                final roomResult = await chatService.ensureRoom(
                  taskId: taskId,
                  creatorId: creatorId,
                  participantId: participantId,
                  type: 'application',
                );
                final roomData = roomResult['room'] ?? {};
                final String realRoomId = roomData['id']?.toString() ?? '';
                if (realRoomId.isEmpty) {
                  debugPrint('❌ [My Works] ensure_room 未取得 room_id');
                  return;
                }

                // 載入聊天室詳細數據
                debugPrint('🔍 [My Works] 載入聊天室數據，room_id: $realRoomId');
                final chatData =
                    await chatService.getChatDetailData(roomId: realRoomId);

                // 保存到本地儲存
                await ChatStorageService.savechatRoomData(
                  roomId: realRoomId,
                  room: chatData['room'] ?? {},
                  task: chatData['task'] ?? {},
                  userRole: chatData['user_role'] ?? 'participant',
                  chatPartnerInfo: chatData['chat_partner_info'],
                );

                // 設置為當前會話
                await ChatSessionManager.setCurrentChatSession(
                  roomId: realRoomId,
                  room: chatData['room'] ?? {},
                  task: chatData['task'] ?? {},
                  userRole: chatData['user_role'] ?? 'participant',
                  chatPartnerInfo: chatData['chat_partner_info'] ?? {},
                );

                // 導航到聊天室
                debugPrint('🔍 [My Works] 準備導航到聊天室，room_id: $realRoomId');
                context.go('/chat/detail?room_id=$realRoomId');
              } catch (e) {
                debugPrint('❌ [My Works] ensure_room 失敗: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('無法進入聊天室: $e')),
                  );
                }
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
                            // Emoji 狀態列
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (TaskCardUtils.isNewTask(task))
                                  const Text('🌱',
                                      style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                if (TaskCardUtils.isPopularTask(task, {}))
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                              ],
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
                      ],
                    ),
                  ),

                  // 右側：未讀徽章和箭頭
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
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
                            DateFormat('MM/dd').format(
                              DateTime.parse(task['task_date'] ??
                                  DateTime.now().toString()),
                            ),
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

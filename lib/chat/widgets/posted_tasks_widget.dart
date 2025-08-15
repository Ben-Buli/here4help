import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((offset) {
      _fetchPage(offset);
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
      // 只有當前是 Posted Tasks 分頁時才刷新
      if (chatProvider.currentTabIndex == 0) {
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
      if (chatProvider.selectedLocations.isNotEmpty) {
        filters ??= {};
        filters['location'] = chatProvider.selectedLocations.first;
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

      // 應用篩選和排序
      final filteredTasks = _filterTasks(result.tasks, chatProvider);
      final sortedTasks = _sortTasks(filteredTasks, chatProvider);

      // 修正分頁邏輯 - 統一處理，避免重複卡片
      final hasMoreData = result.hasMore && sortedTasks.length >= _pageSize;

      if (sortedTasks.isNotEmpty) {
        // 計算下一頁的正確 offset
        final nextPageKey = hasMoreData ? offset + _pageSize : null;

        if (nextPageKey != null) {
          _pagingController.appendPage(sortedTasks, nextPageKey);
        } else {
          _pagingController.appendLastPage(sortedTasks);
        }
      } else {
        // 沒有數據時，檢查是否為搜尋/篩選結果
        if (chatProvider.hasActiveFilters ||
            chatProvider.searchQuery.isNotEmpty) {
          _pagingController.appendLastPage([]);
        } else if (offset == 0) {
          // 第一頁就沒有數據
          _pagingController.appendLastPage([]);
        } else {
          // 後續頁面沒有更多數據
          _pagingController.appendLastPage([]);
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
    return RefreshIndicator(
      onRefresh: () async {
        final chatProvider = context.read<ChatListProvider>();
        await chatProvider.cacheManager.forceRefresh();
        _pagingController.refresh();
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
    const unreadCount = 0; // TODO: 實現未讀消息計數

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
                                // Emoji 狀態列
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (TaskCardUtils.isNewTask(task))
                                      const Text('🌱',
                                          style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    if (TaskCardUtils.isPopularTask(
                                        task, _applicationsByTask))
                                      const Text('🔥',
                                          style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                  ],
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

                      // 右側：應徵者數量和箭頭
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
                          if (unreadCount > 0) const SizedBox(height: 4),
                          if (visibleAppliers.isNotEmpty)
                            Text(
                              '${visibleAppliers.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (visibleAppliers.isNotEmpty)
                            const SizedBox(height: 2),
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
          leading: CircleAvatar(
            backgroundColor: TaskCardUtils.getAvatarColor(applier['name']),
            child: Text(
              TaskCardUtils.getInitials(applier['name']),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          title: Text(
            applier['name'] ?? 'Unknown name',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            applier['sentMessages']?[0] ?? 'No messages',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.amber[600], size: 14),
                  const SizedBox(width: 2),
                  Text('${applier['rating'] ?? 0.0}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              Text(
                '(${applier['reviewsCount'] ?? 0})',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
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
    context.go('/task/create', extra: {'editTask': task});
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

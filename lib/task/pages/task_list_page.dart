// task_list_page.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/task/services/language_service.dart';
import 'package:here4help/widgets/range_slider_widget.dart';
import 'package:here4help/widgets/multi_select_search_dropdown.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Map<String, dynamic>> tasks = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String searchQuery = '';

  // 新的篩選狀態變數
  Set<String> selectedLocations = {};
  Set<String> selectedLanguages = {};
  Set<String> selectedStatuses = {};

  // 排序狀態變數
  String _currentSortBy = 'updated_time';
  bool _sortAscending = false; // 預設 Z-A (降序)

  // 獎勵範圍篩選
  double? _minReward;
  double? _maxReward;

  // 收藏狀態
  Set<String> _favoriteTaskIds = <String>{};

  // 滾動控制器
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  List<Map<String, dynamic>> _languages = [];

  @override
  void initState() {
    super.initState();
    _loadGlobalTasks();
    _loadLanguages();
    _loadFavorites();

    // 監聽滾動事件
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 當頁面重新進入時，刷新任務列表
    _loadGlobalTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 載入收藏的任務
  Future<void> _loadFavorites() async {
    // TODO: 從本地存儲或API載入收藏的任務ID
    // 暫時使用空集合
    setState(() {
      _favoriteTaskIds = <String>{};
    });
  }

  /// 切換任務收藏狀態
  void _toggleFavorite(String taskId) {
    setState(() {
      if (_favoriteTaskIds.contains(taskId)) {
        _favoriteTaskIds.remove(taskId);
      } else {
        _favoriteTaskIds.add(taskId);
      }
    });
    // TODO: 保存到本地存儲或API
  }

  /// 滾動監聽
  void _onScroll() {
    if (_scrollController.offset >= 200 && !_showScrollToTop) {
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.offset < 200 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
    }
  }

  /// 滾動到頂部
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  /// 重置所有篩選條件
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      searchQuery = '';
      selectedLocations.clear();
      selectedLanguages.clear();
      selectedStatuses.clear();
      _currentSortBy = 'updated_time';
      _sortAscending = false;
      _minReward = 0;
      _maxReward = null;
    });
  }

  /// 檢查是否有活躍的篩選條件
  bool get _hasActiveFilters =>
      selectedLocations.isNotEmpty ||
      selectedLanguages.isNotEmpty ||
      selectedStatuses.isNotEmpty ||
      searchQuery.isNotEmpty ||
      _minReward != null ||
      _maxReward != null;

  /// 排序功能
  void _setSortOrder(String sortBy) {
    setState(() {
      if (_currentSortBy == sortBy) {
        // 如果點擊同一個排序選項，切換升序/降序
        _sortAscending = !_sortAscending;
      } else {
        // 如果點擊不同的排序選項，設為新選項並預設為升序
        _currentSortBy = sortBy;
        _sortAscending = true;
      }
    });
  }

  /// 排序任務列表
  List<Map<String, dynamic>> _sortTasks(List<Map<String, dynamic>> tasks) {
    final sortedTasks = List<Map<String, dynamic>>.from(tasks);

    sortedTasks.sort((a, b) {
      int comparison = 0;

      switch (_currentSortBy) {
        case 'updated_time':
          final timeA =
              DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
          final timeB =
              DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
          comparison = timeA.compareTo(timeB);
          break;

        case 'applicants':
          final countA = (a['applications'] as List<dynamic>?)?.length ?? 0;
          final countB = (b['applications'] as List<dynamic>?)?.length ?? 0;
          comparison = countA.compareTo(countB);
          break;

        case 'status':
          final statusA = a['status_display'] ?? a['status'] ?? '';
          final statusB = b['status_display'] ?? b['status'] ?? '';
          comparison = statusA.compareTo(statusB);
          break;

        default:
          comparison = 0;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sortedTasks;
  }

  /// 篩選任務列表
  List<Map<String, dynamic>> _filterTasks(List<Map<String, dynamic>> tasks) {
    return tasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      // 搜尋篩選：僅限任務標題名稱
      final matchQuery = query.isEmpty || title.contains(query);

      // 位置篩選
      final location = (task['location'] ?? '').toString();
      final matchLocation =
          selectedLocations.isEmpty || selectedLocations.contains(location);

      // 語言篩選
      final language = (task['language_requirement'] ?? '').toString();
      final matchLanguage =
          selectedLanguages.isEmpty || selectedLanguages.contains(language);

      // 狀態篩選
      final status = _displayStatus(task);
      final matchStatus =
          selectedStatuses.isEmpty || selectedStatuses.contains(status);

      // 獎勵範圍篩選
      final reward =
          double.tryParse((task['reward_point'] ?? '0').toString()) ?? 0.0;
      final matchMinReward = _minReward == null || reward >= _minReward!;
      final matchMaxReward = _maxReward == null || reward <= _maxReward!;

      return matchQuery &&
          matchLocation &&
          matchLanguage &&
          matchStatus &&
          matchMinReward &&
          matchMaxReward;
    }).toList();
  }

  /// 建構緊湊的排序選項（pill shape 膠囊形狀）
  Widget _buildCompactSortChip({
    required String label,
    required String sortBy,
    required IconData icon,
  }) {
    final isActive = _currentSortBy == sortBy;

    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _setSortOrder(sortBy),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? theme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? theme.primary
                      : theme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isActive ? theme.onPrimary : theme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? theme.onPrimary : theme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isActive
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.unfold_more,
                    size: 12,
                    color: isActive ? theme.onPrimary : theme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 建構 Scroll to Top 按鈕
  Widget _buildScrollToTopButton() {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;
        return AnimatedOpacity(
          opacity: _showScrollToTop ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: FloatingActionButton(
            backgroundColor: theme.primary,
            foregroundColor: theme.onPrimary,
            onPressed: _scrollToTop,
            child: const Icon(Icons.keyboard_arrow_up, size: 24),
          ),
        );
      },
    );
  }

  /// 顯示狀態
  String _displayStatus(Map<String, dynamic> task) {
    final dynamic display = task['status_display'];
    if (display != null && display is String && display.isNotEmpty) {
      return display;
    }
    final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
    return (codeOrLegacy ?? '').toString();
  }

  /// 判斷是否為新任務（發布未滿一週）
  bool _isNewTask(Map<String, dynamic> task) {
    try {
      final createdAt =
          DateTime.parse(task['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(createdAt);
      return difference.inDays < 7;
    } catch (e) {
      return false;
    }
  }

  /// 判斷是否為熱門任務（超過一位應徵者）
  bool _isPopularTask(Map<String, dynamic> task) {
    final applications = (task['applications'] as List<dynamic>?) ?? [];
    return applications.length > 1;
  }

  /// 獲取任務發布時間的距離描述
  String _getTimeAgo(Map<String, dynamic> task) {
    try {
      final createdAt =
          DateTime.parse(task['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      if (difference.inDays > 30) {
        return DateFormat('MM/dd').format(createdAt);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// 顯示檢舉對話框
  void _showReportDialog(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer<ThemeConfigManager>(
          builder: (context, themeManager, child) {
            final theme = themeManager.effectiveTheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: true,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // 拖拽指示器
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report Task',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Task: ${task['title'] ?? 'Untitled'}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            // 檢舉選項
                            const Text('Reason for report:'),
                            const SizedBox(height: 8),
                            // TODO: 實現檢舉選項列表
                            const Text('Report functionality coming soon...'),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO: 實現檢舉提交邏輯
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Report submitted')),
                                      );
                                    },
                                    child: const Text('Submit Report'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// 顯示篩選選項
  void _showFilterOptions() {
    // 獲取可用的選項
    final locationOptions = tasks
        .map((e) => (e['location'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final languageOptions = _languages
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();

    final statusOptions = tasks
        .map((e) => _displayStatus(e))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // 計算獎勵範圍
    final rewards = tasks
        .map((e) =>
            double.tryParse((e['reward_point'] ?? '0').toString()) ?? 0.0)
        .toList();
    final minReward = 0.0; // 固定最小值為 0
    final maxReward =
        rewards.isEmpty ? 10000.0 : rewards.reduce((a, b) => a > b ? a : b);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) {
        return Consumer<ThemeConfigManager>(
          builder: (context, themeManager, child) {
            final theme = themeManager.effectiveTheme;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location 多選下拉選單
                  MultiSelectSearchDropdown(
                    options: locationOptions,
                    selectedValues: selectedLocations,
                    onChanged: (values) {
                      setState(() {
                        selectedLocations = values;
                      });
                    },
                    label: 'Location',
                    hint: 'All locations',
                    searchHint: 'Search locations...',
                  ),

                  const SizedBox(height: 16),

                  // Language 多選下拉選單
                  MultiSelectSearchDropdown(
                    options: languageOptions,
                    selectedValues: selectedLanguages,
                    onChanged: (values) {
                      setState(() {
                        selectedLanguages = values;
                      });
                    },
                    label: 'Language',
                    hint: 'All languages',
                    searchHint: 'Search languages...',
                  ),

                  const SizedBox(height: 16),

                  // Status 多選下拉選單
                  MultiSelectSearchDropdown(
                    options: statusOptions,
                    selectedValues: selectedStatuses,
                    onChanged: (values) {
                      setState(() {
                        selectedStatuses = values;
                      });
                    },
                    label: 'Status',
                    hint: 'All statuses',
                    searchHint: 'Search statuses...',
                  ),

                  const SizedBox(height: 16),

                  // 獎勵範圍選擇器
                  RangeSliderWidget(
                    minValue: minReward,
                    maxValue: maxReward,
                    currentMin: _minReward,
                    currentMax: _maxReward,
                    onChanged: (min, max) {
                      setState(() {
                        _minReward = min;
                        _maxReward = max;
                      });
                    },
                    label: 'Reward Range',
                    minLabel: 'Min Reward',
                    maxLabel: 'Max Reward',
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _resetFilters();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              // 篩選條件已經在 onChanged 中應用
                            });
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadGlobalTasks() async {
    final taskService = TaskService();
    await taskService.loadTasks();
    // 載入我的應徵，供按鈕禁用判斷
    try {
      final currentUser =
          Provider.of<UserService>(context, listen: false).currentUser;
      if (currentUser != null) {
        await taskService.loadMyApplications(currentUser.id);
      }
    } catch (_) {}

    // 新增 unreadCount 計算邏輯
    for (final task in taskService.tasks) {
      final visibleAppliers = (task['appliers'] as List<dynamic>?)
              ?.where((ap) => ap['visible'] == true)
              .toList() ??
          [];

      for (final applier in visibleAppliers) {
        applier['unreadCount'] = calculateUnreadCount(applier, task);
      }

      final status = (task['status_display'] ?? task['status'] ?? '')
          .toString()
          .toLowerCase();
      if (status.toLowerCase() == 'open') {
        task['unreadCount'] = visibleAppliers
            .map((ap) => ap['unreadCount'] as int)
            .fold(0, (prev, element) => prev + element);
      } else if (status.toLowerCase() == 'pending confirmation') {
        task['unreadCount'] = 1; // Pending confirmation adds 1 unread count
      } else if (status.toLowerCase() == 'closed' ||
          status.toLowerCase() == 'cancelled') {
        task['unreadCount'] =
            0; // Closed or cancelled tasks have no unread count
      } else {
        task['unreadCount'] = 0;
      }
    }

    if (mounted) {
      setState(() {
        tasks = taskService.tasks;
      });
    }
  }

  Future<void> _loadLanguages() async {
    try {
      _languages = await LanguageService.getLanguages();
      setState(() {});
    } catch (_) {}
  }

  // 新增 unread_service 工具函式
  int calculateUnreadCount(
      Map<String, dynamic> applier, Map<String, dynamic> task) {
    final status = (task['status_display'] ?? task['status'] ?? '')
        .toString()
        .toLowerCase();

    if (status == 'pending confirmation') {
      return 1;
    }

    if (status != 'open') {
      return 0;
    }

    final questionApply = applier['questionApply'] ?? 0;
    final unreadMessages = (applier['messages'] != null)
        ? (applier['messages'] as List)
            .where((m) => m['isRead'] == false)
            .length
        : 0;

    return questionApply + unreadMessages;
  }

  /// 彈出任務詳情對話框
  void _showTaskDetailDialog(Map<String, dynamic> task) {
    final taskPrimaryLanguage = task['language_requirement'] ?? '-';
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.currentUser?.id;
    final taskService = TaskService();
    final String taskId = (task['id'] ?? '').toString();
    final bool isOwner = (task['creator_id']?.toString() ?? '') ==
        (currentUserId?.toString() ?? '');
    final bool alreadyApplied = taskService.myApplications.any((app) {
      final aid = (app['id'] ?? app['task_id']).toString();
      return aid == taskId;
    });
    final bool canApply = !isOwner && !alreadyApplied;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<ThemeConfigManager>(
          builder: (context, themeManager, child) {
            final theme = themeManager.effectiveTheme;
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: theme.surface,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            task['title'] ?? 'Task Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: theme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Task Description',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.onSurface)),
                        Text(task['description'] ?? 'No description.',
                            style: TextStyle(color: theme.onSurface)),
                        const SizedBox(height: 12),
                        Text('Application Question',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.onSurface)),
                        ...((task['application_question'] ?? '')
                            .toString()
                            .split('|')
                            .where((q) => q.trim().isNotEmpty)
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) => Text(
                                '${entry.key + 1}. ${entry.value.trim()}',
                                style: TextStyle(color: theme.onSurface)))
                            .toList()),
                        if ((task['application_question'] ?? '')
                            .toString()
                            .trim()
                            .isEmpty)
                          Text('No questions.',
                              style: TextStyle(color: theme.onSurface)),
                        const SizedBox(height: 12),
                        Text.rich(TextSpan(
                          children: [
                            TextSpan(
                                text: 'Reward: \n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.onSurface)),
                            TextSpan(
                                text:
                                    '💰 ${task['reward_point'] ?? task['salary'] ?? "0"}',
                                style: TextStyle(color: theme.onSurface)),
                          ],
                        )),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(
                          children: [
                            TextSpan(
                                text: 'Request Language: \n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.onSurface)),
                            TextSpan(
                                text: taskPrimaryLanguage,
                                style: TextStyle(color: theme.onSurface)),
                          ],
                        )),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(
                          children: [
                            TextSpan(
                                text: 'Location: \n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.onSurface)),
                            TextSpan(
                                text: task['location'] ?? '-',
                                style: TextStyle(color: theme.onSurface)),
                          ],
                        )),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(
                          children: [
                            TextSpan(
                                text: 'Task Date: \n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.onSurface)),
                            TextSpan(
                                text: task['task_date'] ?? '-',
                                style: TextStyle(color: theme.onSurface)),
                          ],
                        )),
                        const SizedBox(height: 8),
                        Text.rich(TextSpan(
                          children: [
                            TextSpan(
                                text: 'Posted by: \n',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.onSurface)),
                            TextSpan(
                                text:
                                    'UserName: ${task['creator_name'] ?? 'N/A'}${isOwner ? ' (You)' : ''}\n',
                                style: TextStyle(color: theme.onSurface)),
                            TextSpan(
                                text: 'Rating: ⭐️ 4.7 (18 reviews)',
                                style: TextStyle(color: theme.onSurface)),
                          ],
                        )),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                debugPrint('CLOSE button pressed');
                                if (Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              child: const Text('CLOSE'),
                            ),
                            ElevatedButton(
                              onPressed: canApply
                                  ? () async {
                                      final userService =
                                          Provider.of<UserService>(context,
                                              listen: false);
                                      await userService.ensureUserLoaded();

                                      final userId =
                                          userService.currentUser?.id;

                                      if (userId == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('User not logged in.')),
                                        );
                                        return;
                                      }

                                      debugPrint(
                                          'APPLY button pressed for userId: $userId');
                                      final data = {
                                        'userId': userId,
                                        'taskId': task['id'],
                                      };

                                      debugPrint(
                                          'Navigating to TaskApplyPage with data: $data');

                                      if (task['id'] != null) {
                                        if (Navigator.canPop(dialogContext)) {
                                          Navigator.pop(dialogContext);
                                        }
                                        context.push('/task/apply',
                                            extra: data);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Task ID not found. Please check.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                              child: Text(
                                isOwner
                                    ? 'POSTED BY YOU'
                                    : (alreadyApplied
                                        ? 'APPLIED'
                                        : 'APPLY NOW'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 應用篩選和排序
    final filteredTasks = _filterTasks(tasks);
    final sortedTasks = _sortTasks(filteredTasks);

    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;
        return Scaffold(
          backgroundColor: theme.background,
          body: Column(
            children: [
              // 搜尋欄 + 排序功能
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // 搜尋欄主體
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                      onEditingComplete: () {
                        FocusScope.of(context).unfocus();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search task titles...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    searchQuery = '';
                                  });
                                },
                                tooltip: 'Clear',
                              ),
                            IconButton(
                              icon: Icon(Icons.filter_list,
                                  color: _hasActiveFilters
                                      ? theme.primary
                                      : IconTheme.of(context).color),
                              tooltip: 'Filter options',
                              onPressed: _showFilterOptions,
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh, color: theme.primary),
                              tooltip: 'Reset',
                              onPressed: _resetFilters,
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // 排序選項區域
                    Container(
                      height: 32,
                      margin: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          // 更新時間排序
                          _buildCompactSortChip(
                            label: 'Time',
                            sortBy: 'updated_time',
                            icon: Icons.update,
                          ),
                          const SizedBox(width: 8),

                          // 應徵人數排序
                          _buildCompactSortChip(
                            label: 'Applicants',
                            sortBy: 'applicants',
                            icon: Icons.people,
                          ),
                          const SizedBox(width: 8),

                          // 任務狀態排序
                          _buildCompactSortChip(
                            label: 'Status',
                            sortBy: 'status',
                            icon: Icons.sort_by_alpha,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 任務列表
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 12,
                    bottom: 80, // 保留底部距離，避免被 scroll to top button 遮擋
                  ),
                  itemCount: sortedTasks.length,
                  itemBuilder: (context, index) {
                    final task = sortedTasks[index];
                    final taskId = task['id']?.toString() ?? '';
                    final isFavorite = _favoriteTaskIds.contains(taskId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _showTaskDetailDialog(task);
                        },
                        child: Stack(
                          children: [
                            Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 任務標題和操作按鈕
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 操作按鈕區域 - 只保留三個點選單
                                    PopupMenuButton<String>(
                                      icon:
                                          const Icon(Icons.more_vert, size: 20),
                                      onSelected: (value) {
                                        if (value == 'report') {
                                          _showReportDialog(task);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'report',
                                          child: Row(
                                            children: [
                                              Icon(Icons.flag_outlined),
                                              SizedBox(width: 8),
                                              Text('Report'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 任務資訊 - 按照截圖右邊的佈局
                                Row(
                                  children: [
                                    // 左側：Applicant、Location、Language
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Applicant
                                          Row(
                                            children: [
                                              Icon(Icons.person_outline,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  task['creator_name'] ??
                                                      'Unknown User',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Location
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  task['location'] ??
                                                      'Unknown Location',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Language
                                          Row(
                                            children: [
                                              Icon(Icons.chat_outlined,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  task['language_requirement'] ??
                                                      'No Requirement',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 右側：Date、Reward
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Date
                                          Row(
                                            children: [
                                              Icon(Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('MM/dd').format(
                                                  DateTime.parse(
                                                      task['task_date'] ??
                                                          DateTime.now()
                                                              .toString()),
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: theme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Reward
                                          Row(
                                            children: [
                                              Icon(
                                                  Icons
                                                      .monetization_on_outlined,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${task['reward_point'] ?? task['salary'] ?? 0}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: theme.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // New/Popular 狀態 + 時間距離戳記（合併顯示）
                                Row(
                                  children: [
                                    if (_isNewTask(task)) ...[
                                      const Icon(Icons.eco,
                                          size: 16, color: Colors.green),
                                      const SizedBox(width: 6),
                                      const Text('New',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green)),
                                      const SizedBox(width: 16),
                                    ] else if (_isPopularTask(task)) ...[
                                      const Icon(Icons.local_fire_department,
                                          size: 16, color: Colors.red),
                                      const SizedBox(width: 6),
                                      const Text('Popular',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.red)),
                                      const SizedBox(width: 16),
                                    ],
                                    const Icon(Icons.schedule,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getTimeAgo(task),
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 書籤按鈕 - 固定在右下角
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 22,
                                color: isFavorite ? Colors.amber : null,
                              ),
                              onPressed: () => _toggleFavorite(taskId),
                              tooltip: isFavorite
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                            ),
                          ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Scroll to top button
          floatingActionButton: _buildScrollToTopButton(),
        );
      },
    );
  }
}

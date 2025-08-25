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

import 'package:here4help/services/api/task_favorites_api.dart';
import 'package:here4help/services/api/task_reports_api.dart';

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
  String _currentSortBy = 'update';
  bool _sortAscending = false; // 預設 Z-A (降序)

  // 獎勵範圍篩選
  double? _minReward;
  double? _maxReward;

  // 收藏狀態
  Set<String> _favoriteTaskIds = <String>{};

  // 任務類型篩選 (radio group)
  String _taskTypeFilter = 'all'; // all, favorites, my_tasks

  // 臨時篩選狀態 (apply 前的選擇)
  String _tempTaskTypeFilter = 'all';
  String? _tempSelectedLocation;
  String? _tempSelectedLanguage;
  String? _tempSelectedStatus;

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
    try {
      // 從 API 載入收藏的任務ID
      final result = await TaskFavoritesApi.getFavorites(page: 1, perPage: 100);
      final favorites = result['favorites'] as List<dynamic>;

      setState(() {
        _favoriteTaskIds =
            favorites.map((favorite) => favorite['task_id'].toString()).toSet();
      });
    } catch (e) {
      // 如果載入失敗，使用空集合
      if (mounted) {
        setState(() {
          _favoriteTaskIds = <String>{};
        });
      }
    }
  }

  /// 切換任務收藏狀態
  Future<void> _toggleFavorite(String taskId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 檢查是否為自己的任務
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.currentUser?.id;
    final task = tasks.firstWhere((t) => t['id'] == taskId, orElse: () => {});
    final taskCreatorId = task['creator_id']?.toString();

    if (currentUserId?.toString() == taskCreatorId) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('You cannot favorite your own task'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 記錄原始狀態
    final wasOriginallyFavorited = _favoriteTaskIds.contains(taskId);

    // 先樂觀更新 UI
    setState(() {
      if (wasOriginallyFavorited) {
        _favoriteTaskIds.remove(taskId);
      } else {
        _favoriteTaskIds.add(taskId);
      }
    });

    try {
      if (wasOriginallyFavorited) {
        // 取消收藏
        await TaskFavoritesApi.removeFavorite(taskId: taskId);

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Unfavorited🥺'),
              duration: Duration(seconds: 1),
              backgroundColor: Color.fromARGB(255, 107, 113, 117),
            ),
          );
        }
      } else {
        // 添加收藏
        await TaskFavoritesApi.addFavorite(taskId: taskId);

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Collected!🥳'),
              duration: Duration(seconds: 1),
              backgroundColor: Color.fromARGB(255, 111, 84, 4),
            ),
          );
        }
      }
    } catch (e) {
      // API 操作失敗，恢復原始狀態
      setState(() {
        if (wasOriginallyFavorited) {
          _favoriteTaskIds.add(taskId);
        } else {
          _favoriteTaskIds.remove(taskId);
        }
      });

      // 顯示用戶友好的錯誤訊息
      String errorMessage;
      if (e.toString().contains('ClientException')) {
        errorMessage =
            'Network connection failed, please check your network status';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Please log in again and try again';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Task does not exist or has been deleted';
      } else if (e.toString().contains('already')) {
        errorMessage = wasOriginallyFavorited
            ? 'Task is already in the favorites list'
            : 'Task has been removed from favorites';
      } else {
        errorMessage = wasOriginallyFavorited
            ? 'Failed to remove from favorites, please try again later'
            : 'Failed to add to favorites, please try again later';
      }

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
      selectedLocations.clear();
      selectedLanguages.clear();
      selectedStatuses.clear();
      _currentSortBy = 'update';
      _sortAscending = false;
      _minReward = 0;
      _maxReward = null;
      _taskTypeFilter = 'all';
      _tempTaskTypeFilter = 'all';
      _tempSelectedLocation = null;
      _tempSelectedLanguage = null;
      _tempSelectedStatus = null;
    });
  }

  /// 重置搜尋
  void _resetSearch() {
    setState(() {
      _searchController.clear();
      searchQuery = '';
    });
  }

  /// 檢查是否有活躍的篩選條件
  bool get _hasActiveFilters =>
      selectedLocations.isNotEmpty ||
      selectedLanguages.isNotEmpty ||
      selectedStatuses.isNotEmpty ||
      _minReward != null ||
      _maxReward != null ||
      _taskTypeFilter != 'all';

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
        case 'update':
          final timeA =
              DateTime.parse(a['updated_at'] ?? DateTime.now().toString());
          final timeB =
              DateTime.parse(b['updated_at'] ?? DateTime.now().toString());
          comparison = timeA.compareTo(timeB);
          break;

        case 'task_time':
          final timeA =
              DateTime.parse(a['task_date'] ?? DateTime.now().toString());
          final timeB =
              DateTime.parse(b['task_date'] ?? DateTime.now().toString());
          comparison = timeA.compareTo(timeB);
          break;

        case 'popular':
          // 計算應徵人數 - 從 applications 或 appliers 陣列
          final countA = (a['applications'] as List<dynamic>?)?.length ??
              (a['appliers'] as List<dynamic>?)?.length ??
              0;
          final countB = (b['applications'] as List<dynamic>?)?.length ??
              (b['appliers'] as List<dynamic>?)?.length ??
              0;
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
      final language =
          ((task['language_requirement'] as String?)?.trim().isNotEmpty ??
                  false)
              ? (task['language_requirement'] as String).trim()
              : '-';
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

      // 任務類型篩選
      bool matchTaskType = true;
      final taskId = task['id']?.toString() ?? '';
      final taskCreatorId = task['creator_id']?.toString();

      if (_taskTypeFilter == 'favorites') {
        matchTaskType = _favoriteTaskIds.contains(taskId);
      } else if (_taskTypeFilter == 'my_tasks') {
        final userService = Provider.of<UserService>(context, listen: false);
        final currentUserId = userService.currentUser?.id.toString();
        matchTaskType = currentUserId == taskCreatorId;
      }

      return matchQuery &&
          matchLocation &&
          matchLanguage &&
          matchStatus &&
          matchMinReward &&
          matchMaxReward &&
          matchTaskType;
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
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _setSortOrder(sortBy),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
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
                    color: isActive
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
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
        return AnimatedOpacity(
          opacity: _showScrollToTop ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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

  /// 判斷是否為新任務（更新未滿一週）
  bool _isNewTask(Map<String, dynamic> task) {
    try {
      final updatedAt =
          DateTime.parse(task['updated_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(updatedAt);
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

  /// 獲取任務更新時間的距離描述
  String _getTimeAgo(Map<String, dynamic> task) {
    try {
      final updatedAt =
          DateTime.parse(task['updated_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(updatedAt);

      if (difference.inDays > 30) {
        return DateFormat('MM/dd').format(updatedAt);
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
  void _showReportDialog(Map<String, dynamic> task) async {
    final taskId = task['id']?.toString() ?? '';

    if (taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task ID not found')),
      );
      return;
    }

    // 檢查是否為自己的任務
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUserId = userService.currentUser?.id;
    final taskCreatorId = task['creator_id']?.toString();

    if (currentUserId?.toString() == taskCreatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot report your own task'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 先檢查是否已經檢舉過
    try {
      final reportStatus =
          await TaskReportsApi.checkReportStatus(taskId: taskId);
      final hasReported = reportStatus['has_reported'] ?? false;
      final existingReport = reportStatus['report'] as TaskReport?;

      if (!mounted) return;

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
                      color: Theme.of(context).colorScheme.surface,
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
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: hasReported && existingReport != null
                                ? _buildExistingReportView(
                                    task, existingReport, theme)
                                : _buildReportFormView(task, taskId, theme),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking report status: $e')),
        );
      }
    }
  }

  /// 構建已檢舉的顯示視圖
  Widget _buildExistingReportView(
      Map<String, dynamic> task, TaskReport report, dynamic theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Task: ${task['title'] ?? 'Untitled'}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have already reported this task!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Reason:', report.reasonDisplayText, theme),
              const SizedBox(height: 8),
              _buildInfoRow('Status:', report.statusDisplayText, theme),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Time:',
                  DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt),
                  theme),
              const SizedBox(height: 12),
              Text(
                'Description:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.description,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, dynamic theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  /// 構建檢舉表單視圖
  Widget _buildReportFormView(
      Map<String, dynamic> task, String taskId, dynamic theme) {
    return _ReportFormWidget(
      task: task,
      taskId: taskId,
      theme: theme,
      onSubmitted: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      },
    );
  }

  /// 顯示篩選選項
  void _showFilterOptions() {
    // 初始化臨時篩選狀態為當前狀態
    setState(() {
      _tempTaskTypeFilter = _taskTypeFilter;
      _tempSelectedLocation =
          selectedLocations.isNotEmpty ? selectedLocations.first : null;
      _tempSelectedLanguage =
          selectedLanguages.isNotEmpty ? selectedLanguages.first : null;
      _tempSelectedStatus =
          selectedStatuses.isNotEmpty ? selectedStatuses.first : null;
    });

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
    const minReward = 0.0; // 固定最小值為 0
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
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  height: MediaQuery.of(ctx).size.height * 0.8, // 限制最大高度
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 可滾動的篩選內容
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 任務類型篩選 (Radio Group)
                              Text(
                                'Task Type',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),

                              RadioListTile<String>(
                                title: const Text('All Tasks'),
                                value: 'all',
                                groupValue: _tempTaskTypeFilter,
                                onChanged: (value) {
                                  setModalState(() {
                                    _tempTaskTypeFilter = value ?? 'all';
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                              ),

                              RadioListTile<String>(
                                title: const Text('My Favorites'),
                                value: 'favorites',
                                groupValue: _tempTaskTypeFilter,
                                onChanged: (value) {
                                  setModalState(() {
                                    _tempTaskTypeFilter = value ?? 'all';
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                              ),

                              RadioListTile<String>(
                                title: const Text('My Tasks'),
                                value: 'my_tasks',
                                groupValue: _tempTaskTypeFilter,
                                onChanged: (value) {
                                  setModalState(() {
                                    _tempTaskTypeFilter = value ?? 'all';
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                              ),

                              const SizedBox(height: 24),

                              // Location 單選下拉選單
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _tempSelectedLocation,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                hint: const Text('All locations'),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All locations'),
                                  ),
                                  ...locationOptions.map(
                                      (location) => DropdownMenuItem<String>(
                                            value: location,
                                            child: Text(location),
                                          )),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    _tempSelectedLocation = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 16),

                              // Language 單選下拉選單
                              Text(
                                'Language',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _tempSelectedLanguage,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                hint: const Text('All languages'),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All languages'),
                                  ),
                                  ...languageOptions.map(
                                      (language) => DropdownMenuItem<String>(
                                            value: language,
                                            child: Text(language),
                                          )),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    _tempSelectedLanguage = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 16),

                              // Status 單選下拉選單
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _tempSelectedStatus,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                hint: const Text('All statuses'),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All statuses'),
                                  ),
                                  ...statusOptions
                                      .map((status) => DropdownMenuItem<String>(
                                            value: status,
                                            child: Text(status),
                                          )),
                                ],
                                onChanged: (value) {
                                  setModalState(() {
                                    _tempSelectedStatus = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 16),

                              // 獎勵範圍選擇器
                              RangeSliderWidget(
                                minValue: minReward,
                                maxValue: maxReward,
                                currentMin: _minReward,
                                currentMax: _maxReward,
                                onChanged: (min, max) {
                                  setModalState(() {
                                    _minReward = min;
                                    _maxReward = max;
                                  });
                                },
                                label: 'Reward Range',
                                minLabel: 'Min Reward',
                                maxLabel: 'Max Reward',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  _tempTaskTypeFilter = 'all';
                                  _tempSelectedLocation = null;
                                  _tempSelectedLanguage = null;
                                  _tempSelectedStatus = null;
                                  _minReward = null;
                                  _maxReward = null;
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // 重置搜尋
                                _resetSearch();

                                // 應用篩選條件
                                setState(() {
                                  _taskTypeFilter = _tempTaskTypeFilter;
                                  selectedLocations.clear();
                                  selectedLanguages.clear();
                                  selectedStatuses.clear();

                                  if (_tempSelectedLocation != null) {
                                    selectedLocations
                                        .add(_tempSelectedLocation!);
                                  }
                                  if (_tempSelectedLanguage != null) {
                                    selectedLanguages
                                        .add(_tempSelectedLanguage!);
                                  }
                                  if (_tempSelectedStatus != null) {
                                    selectedStatuses.add(_tempSelectedStatus!);
                                  }
                                });

                                Navigator.of(ctx).pop();
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

    // 檢查任務狀態是否為 open (status_id = 1)
    final taskStatusId = task['status_id']?.toString() ?? '';
    final isTaskOpen = taskStatusId == '1';

    final bool canApply = !isOwner && !alreadyApplied && isTaskOpen;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<ThemeConfigManager>(
          builder: (context, themeManager, child) {
            return Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50], // 整體灰白色背景
                    borderRadius: BorderRadius.circular(20),
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 標題區塊（主題色背景）
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Text(
                          task['title'] ?? 'Task Details',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      // 內容
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Task Description',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                              Text(task['description'] ?? 'No description.',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                              const SizedBox(height: 12),
                              Text('Application Question',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                              ...((task['application_question'] ?? '')
                                  .toString()
                                  .split('|')
                                  .where((q) => q.trim().isNotEmpty)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) => Text(
                                      '${entry.key + 1}. ${entry.value.trim()}',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)))
                                  .toList()),
                              if ((task['application_question'] ?? '')
                                  .toString()
                                  .trim()
                                  .isEmpty)
                                Text('No questions.',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                              const SizedBox(height: 12),
                              Text.rich(TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'Reward: \n',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  TextSpan(
                                      text:
                                          '💰 ${task['reward_point'] ?? task['salary'] ?? "0"}',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                ],
                              )),
                              const SizedBox(height: 8),
                              Text.rich(TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'Request Language: \n',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  TextSpan(
                                      text: ((task['language_requirement']
                                                      as String?)
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false)
                                          ? (task['language_requirement']
                                                  as String)
                                              .trim()
                                          : '-',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                ],
                              )),
                              const SizedBox(height: 8),
                              Text.rich(TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'Location: \n',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  TextSpan(
                                      text: task['location'] ?? '-',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                ],
                              )),
                              const SizedBox(height: 8),
                              Text.rich(TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'Task Date: \n',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  TextSpan(
                                      text: task['task_date'] ?? '-',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                ],
                              )),
                              const SizedBox(height: 8),
                              Text.rich(TextSpan(
                                children: [
                                  TextSpan(
                                      text: 'Posted by: \n',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  TextSpan(
                                      text:
                                          'UserName: ${task['creator_name'] ?? 'N/A'}${isOwner ? ' (You)' : ''}\n',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                  TextSpan(
                                      text: 'Rating: ⭐️ 4.7 (18 reviews)',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface)),
                                ],
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 權限說明文字
                      Consumer<UserService>(
                        builder: (context, userService, child) {
                          final userPermission =
                              userService.currentUser?.permission ?? 0;

                          // 優先檢查任務狀態
                          if (!isTaskOpen) {
                            return Container(
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline,
                                      color: Colors.grey.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This task recruitment has ended.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (userPermission == 0) {
                            return Container(
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You can apply for tasks after account verification is completed.',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (userPermission < 0) {
                            return Container(
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.block,
                                      color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You currently do not have posting permissions.',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // 底部按鈕
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                if (Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              child: const Text('CLOSE'),
                            ),
                            Consumer<UserService>(
                              builder: (context, userService, child) {
                                final userPermission =
                                    userService.currentUser?.permission ?? 0;
                                final canApplyWithPermission =
                                    canApply && userPermission > 0;

                                return ElevatedButton(
                                  onPressed: canApplyWithPermission
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
                                                  content: Text(
                                                      'User not logged in.')),
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
                                            if (Navigator.canPop(
                                                dialogContext)) {
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
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ));
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
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
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
                          // 當搜尋時重設篩選條件
                          if (value.isNotEmpty) {
                            _resetFilters();
                          }
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
                                      ? Theme.of(context).colorScheme.primary
                                      : IconTheme.of(context).color),
                              tooltip: 'Filter options',
                              onPressed: _showFilterOptions,
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh,
                                  color: Theme.of(context).colorScheme.primary),
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
                            label: 'Update',
                            sortBy: 'update',
                            icon: Icons.update,
                          ),
                          const SizedBox(width: 8),

                          // 任務時間排序
                          _buildCompactSortChip(
                            label: 'Task Time',
                            sortBy: 'task_time',
                            icon: Icons.schedule,
                          ),
                          const SizedBox(width: 8),

                          // 熱門程度排序（應徵人數）
                          _buildCompactSortChip(
                            label: 'Popular',
                            sortBy: 'popular',
                            icon: Icons.trending_up,
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      // trailing menu, no extra SizedBox/Align so it uses the same 16px card padding
                                      Consumer<UserService>(
                                        builder: (context, userService, child) {
                                          final userPermission = userService
                                                  .currentUser?.permission ??
                                              0;
                                          final currentUserId =
                                              userService.currentUser?.id;
                                          final taskCreatorId =
                                              task['creator_id']?.toString();
                                          final isOwnTask =
                                              currentUserId?.toString() ==
                                                  taskCreatorId;

                                          // 不顯示檢舉按鈕的條件：權限不足或是自己的任務
                                          if (userPermission <= 0 ||
                                              isOwnTask) {
                                            return const SizedBox.shrink();
                                          }

                                          return PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.more_vert,
                                                size: 20),
                                            onSelected: (value) {
                                              if (value == 'report') {
                                                _showReportDialog(task);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
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
                                          );
                                        },
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
                                                  child: Consumer<UserService>(
                                                    builder: (context,
                                                        userService, child) {
                                                      final currentUserId =
                                                          userService
                                                              .currentUser?.id;
                                                      final taskCreatorId =
                                                          task['creator_id']
                                                              ?.toString();
                                                      final isOwnTask =
                                                          currentUserId
                                                                  ?.toString() ==
                                                              taskCreatorId;
                                                      final creatorName = task[
                                                              'creator_name'] ??
                                                          'Unknown User';

                                                      return Text(
                                                        isOwnTask
                                                            ? '$creatorName (YOU)'
                                                            : creatorName,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          fontWeight: isOwnTask
                                                              ? FontWeight.w600
                                                              : FontWeight
                                                                  .normal,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      );
                                                    },
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
                                                        'No assigned',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
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
                                                    (task['language_requirement'] !=
                                                                null &&
                                                            task['language_requirement']
                                                                .toString()
                                                                .isNotEmpty)
                                                        ? task[
                                                            'language_requirement']
                                                        : '-',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
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
                                                            'No assigned'),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
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
                                                    '${NumberFormat('#,###').format(int.tryParse((task['reward_point'] ?? task['salary'] ?? '0').toString()) ?? 0)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
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
                                        Icon(Icons.eco,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 6),
                                        Text('New',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary)),
                                        const SizedBox(width: 16),
                                      ] else if (_isPopularTask(task)) ...[
                                        Icon(Icons.local_fire_department,
                                            size: 16,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                        const SizedBox(width: 6),
                                        Text('Popular',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary)),
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
                              right: 16,
                              bottom: 8,
                              child: Consumer<UserService>(
                                builder: (context, userService, child) {
                                  final userPermission =
                                      userService.currentUser?.permission ?? 0;
                                  final currentUserId =
                                      userService.currentUser?.id;
                                  final taskCreatorId =
                                      task['creator_id']?.toString();
                                  final isOwnTask = currentUserId?.toString() ==
                                      taskCreatorId;

                                  // 不顯示收藏按鈕的條件：權限不足或是自己的任務
                                  if (userPermission <= 0 || isOwnTask) {
                                    return const SizedBox.shrink();
                                  }

                                  return IconButton(
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      size: 22,
                                      color: isFavorite ? Colors.amber : null,
                                    ),
                                    onPressed: () async =>
                                        await _toggleFavorite(taskId),
                                    tooltip: isFavorite
                                        ? 'Remove from favorites'
                                        : 'Add to favorites',
                                  );
                                },
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

/// 檢舉表單組件
class _ReportFormWidget extends StatefulWidget {
  final Map<String, dynamic> task;
  final String taskId;
  final dynamic theme;
  final VoidCallback onSubmitted;

  const _ReportFormWidget({
    required this.task,
    required this.taskId,
    required this.theme,
    required this.onSubmitted,
  });

  @override
  State<_ReportFormWidget> createState() => _ReportFormWidgetState();
}

class _ReportFormWidgetState extends State<_ReportFormWidget> {
  String? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a reason and provide description')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await TaskReportsApi.submitReport(
        taskId: widget.taskId,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = TaskReportsApi.getReportReasons();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Task',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Task: ${widget.task['title'] ?? 'Untitled'}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Reason for report:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        // Radio 選項
        ...reasons.map((reason) => RadioListTile<String>(
              title: Text(
                reason['label']!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              value: reason['value']!,
              groupValue: _selectedReason,
              onChanged: (value) {
                setState(() {
                  _selectedReason = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            )),
        const SizedBox(height: 24),
        Text(
          'Description (required):',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Please provide details about the issue...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

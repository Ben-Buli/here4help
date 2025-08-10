// task_list_page.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
// import 'package:here4help/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/widgets/theme_aware_components.dart';
import 'package:here4help/task/services/language_service.dart';

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
  String? selectedLocation;
  String? selectedLanguage;
  String? selectedStatus; // 新增狀態篩選
  String sortBy = 'updated_at'; // 新增排序選項
  bool sortDesc = true; // 新增排序方向
  bool showMyTasksOnly = false; // 是否只顯示我的任務
  bool showAppliedOnly = false; // 是否只顯示已應徵任務
  // final TextEditingController _languageSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _languages = [];

  // 根據目前選擇的語言，取得可用的地點
  List<String> getAvailableLocations() {
    final filtered = tasks.where((task) {
      final language = (task['language_requirement'] ?? '').toString();
      final status =
          (task['status_display'] ?? task['status'] ?? '').toString();
      return (selectedLanguage == null || language == selectedLanguage) &&
          (selectedStatus == null ||
              status.toLowerCase() == selectedStatus!.toLowerCase());
    });
    return filtered
        .map((e) => (e['location'] ?? '').toString())
        .toSet()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // 根據目前選擇的地點，取得可用的語言
  List<String> getAvailableLanguages() {
    final filtered = tasks.where((task) {
      final location = (task['location'] ?? '').toString();
      final status =
          (task['status_display'] ?? task['status'] ?? '').toString();
      return (selectedLocation == null || location == selectedLocation) &&
          (selectedStatus == null ||
              status.toLowerCase() == selectedStatus!.toLowerCase());
    });
    return filtered
        .map((e) => (e['language_requirement'] ?? '').toString())
        .toSet()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // 取得可用的狀態選項
  List<String> getAvailableStatuses() {
    return tasks
        .map((e) => (e['status_display'] ?? e['status'] ?? '').toString())
        .toSet()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // 排序任務列表
  List<Map<String, dynamic>> sortTasks(List<Map<String, dynamic>> taskList) {
    taskList.sort((a, b) {
      // 首先按狀態排序：Open 優先（以顯示文字）
      final statusA =
          (a['status_display'] ?? a['status'] ?? '').toString().toLowerCase();
      final statusB =
          (b['status_display'] ?? b['status'] ?? '').toString().toLowerCase();

      if (statusA == 'open' && statusB != 'open') return -1;
      if (statusA != 'open' && statusB == 'open') return 1;

      // 然後按選擇的排序欄位排序
      if (sortBy == 'reward_point') {
        // 按獎勵點數排序
        final rewardA =
            double.tryParse((a['reward_point'] ?? '0').toString()) ?? 0.0;
        final rewardB =
            double.tryParse((b['reward_point'] ?? '0').toString()) ?? 0.0;

        if (sortDesc) {
          return rewardB.compareTo(rewardA); // 高到低
        } else {
          return rewardA.compareTo(rewardB); // 低到高
        }
      } else {
        // 按更新時間排序（預設）
        final updatedAtA = a['updated_at'] ?? a['created_at'] ?? '';
        final updatedAtB = b['updated_at'] ?? b['created_at'] ?? '';

        if (updatedAtA.isNotEmpty && updatedAtB.isNotEmpty) {
          DateTime? dateA;
          DateTime? dateB;

          // 嘗試解析日期
          try {
            dateA = DateTime.tryParse(updatedAtA);
          } catch (e) {
            dateA = null;
          }

          try {
            dateB = DateTime.tryParse(updatedAtB);
          } catch (e) {
            dateB = null;
          }

          // 如果解析失敗，使用當前時間
          dateA ??= DateTime.now();
          dateB ??= DateTime.now();

          if (sortDesc) {
            return dateB.compareTo(dateA); // 降序
          } else {
            return dateA.compareTo(dateB); // 升序
          }
        }
      }

      return 0;
    });

    return taskList;
  }

  // 過濾自己的任務
  List<Map<String, dynamic>> filterOwnTasks(
      List<Map<String, dynamic>> taskList) {
    final currentUser =
        Provider.of<UserService>(context, listen: false).currentUser;
    if (currentUser?.id != null) {
      return taskList.where((task) {
        final creatorId = task['creator_id']?.toString() ?? '';
        return creatorId != currentUser!.id.toString();
      }).toList();
    }
    return taskList;
  }

  @override
  void initState() {
    super.initState();
    _loadGlobalTasks();
    _loadLanguages();
    // 移除 search bar 自動 focus 功能
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
    super.dispose();
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

    setState(() {
      tasks = taskService.tasks;
    });
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

  /// 彈出篩選選單對話框
  void _showFilterDialog() {
    // 創建臨時變數來存儲 dialog 內的狀態
    bool tempShowMyTasksOnly = showMyTasksOnly;
    bool tempShowAppliedOnly = showAppliedOnly;
    String tempSortBy = sortBy;
    bool tempSortDesc = sortDesc;

    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return Consumer<ThemeConfigManager>(
            builder: (context, themeManager, child) {
              final theme = themeManager.effectiveTheme;
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Dialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    backgroundColor: theme.surface,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Filter Options',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: theme.onSurface,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        tempShowMyTasksOnly = false;
                                        tempShowAppliedOnly =
                                            false; // 預設都不勾選，顯示全部任務
                                        tempSortBy = 'updated_at';
                                        tempSortDesc = true;
                                      });
                                      // 不立即更新主頁面，關閉對話框
                                      Navigator.pop(dialogContext);
                                    },
                                    icon: Icon(Icons.clear,
                                        color: theme.onSurface),
                                    tooltip: 'Clear and Close',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Task Type Filter',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.onSurface)),
                              const SizedBox(height: 4),
                              CheckboxListTile(
                                value: tempShowAppliedOnly,
                                onChanged: (v) {
                                  setDialogState(() {
                                    tempShowAppliedOnly = v ?? false;
                                  });
                                },
                                title: Text('Show Applied Tasks',
                                    style: TextStyle(color: theme.onSurface)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                dense: true,
                              ),
                              CheckboxListTile(
                                value: tempShowMyTasksOnly,
                                onChanged: (v) {
                                  setDialogState(() {
                                    tempShowMyTasksOnly = v ?? false;
                                  });
                                },
                                title: Text('Show My Tasks',
                                    style: TextStyle(color: theme.onSurface)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                dense: true,
                              ),
                              const SizedBox(height: 8),
                              Text('Sort By',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.onSurface)),
                              const SizedBox(height: 8),
                              RadioListTile<String>(
                                value: 'updated_at',
                                groupValue: tempSortBy,
                                onChanged: (v) {
                                  setDialogState(
                                      () => tempSortBy = v ?? 'updated_at');
                                  // 不立即更新主頁面
                                },
                                title: const Text('Update Date'),
                              ),
                              RadioListTile<String>(
                                value: 'reward_point',
                                groupValue: tempSortBy,
                                onChanged: (v) {
                                  setDialogState(
                                      () => tempSortBy = v ?? 'updated_at');
                                  // 不立即更新主頁面
                                },
                                title: const Text('Reward Points'),
                              ),
                              const SizedBox(height: 8),
                              Text('Sort Direction',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.onSurface)),
                              const SizedBox(height: 8),
                              RadioListTile<bool>(
                                value: true,
                                groupValue: tempSortDesc,
                                onChanged: (v) {
                                  setDialogState(
                                      () => tempSortDesc = v ?? true);
                                  // 不立即更新主頁面
                                },
                                title: const Text('Descending'),
                              ),
                              RadioListTile<bool>(
                                value: false,
                                groupValue: tempSortDesc,
                                onChanged: (v) {
                                  setDialogState(
                                      () => tempSortDesc = v ?? false);
                                  // 不立即更新主頁面
                                },
                                title: const Text('Ascending'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        tempShowMyTasksOnly = false;
                                        tempShowAppliedOnly =
                                            false; // 預設都不勾選，顯示全部任務
                                        tempSortBy = 'updated_at';
                                        tempSortDesc = true;
                                      });
                                      // Reset 不立即應用，只重置臨時值
                                    },
                                    child: const Text('Reset'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      // Apply 按鈕：將臨時值應用到實際變數
                                      setState(() {
                                        showMyTasksOnly = tempShowMyTasksOnly;
                                        showAppliedOnly = tempShowAppliedOnly;
                                        sortBy = tempSortBy;
                                        sortDesc = tempSortDesc;
                                      });
                                      Navigator.pop(dialogContext);
                                    },
                                    child: const Text('Apply'),
                                  ),
                                ],
                              ),
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
        });
  }

  @override
  Widget build(BuildContext context) {
    // 取得根據篩選條件的可用選項
    final locations = getAvailableLocations();
    final languagesDb = [
      'All',
      ..._languages
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
    ];
    final statuses = getAvailableStatuses();

    final currentUserId = Provider.of<UserService>(context, listen: false)
        .currentUser
        ?.id
        .toString();
    final myAppliedIds = TaskService()
        .myApplications
        .map((e) => (e['task_id'] ?? e['id']).toString())
        .toSet();

    final filteredTasks = tasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final description = (task['description'] ?? '').toString().toLowerCase();
      final location = (task['location'] ?? '').toString();
      final language = (task['language_requirement'] ?? '').toString();
      final status = (task['status_display'] ?? task['status'] ?? '')
          .toString()
          .toLowerCase();
      final creatorId = task['creator_id']?.toString();
      final isMine = (currentUserId != null && creatorId == currentUserId);
      final applied = myAppliedIds.contains((task['id'] ?? '').toString());

      final matchQuery =
          title.contains(searchQuery) || description.contains(searchQuery);
      final matchLocation = selectedLocation == null ||
          selectedLocation == 'All' ||
          location == selectedLocation;
      final matchLanguage = selectedLanguage == null ||
          selectedLanguage == 'All' ||
          language == selectedLanguage;
      final matchStatus = selectedStatus == null ||
          selectedStatus == 'All' ||
          status == selectedStatus!.toLowerCase();
      // 新的篩選邏輯：都不勾選時顯示全部任務
      final matchMine = showMyTasksOnly ? isMine : true; // 勾選時只顯示我的，不勾選時顯示全部
      final matchApplied =
          showAppliedOnly ? applied : true; // 勾選時只顯示已應徵，不勾選時顯示全部

      return matchQuery &&
          matchLocation &&
          matchLanguage &&
          matchStatus &&
          matchMine &&
          matchApplied;
    }).toList();

    // 排序任務列表（呈現所有任務，不再過濾自己發布的）
    final sortedTasks = sortTasks(filteredTasks);

    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;
        return Container(
            color: theme.background,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle:
                          TextStyle(color: theme.onSurface.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search,
                          color: theme.onSurface.withOpacity(0.7)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: theme.onSurface.withOpacity(0.7)),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.surface.withOpacity(0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: theme.secondary.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: theme.secondary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.primary, width: 2),
                      ),
                    ),
                    style: TextStyle(color: theme.onSurface),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // 篩選按鈕
                      IconButton(
                        onPressed: () => _showFilterDialog(),
                        icon: const Icon(Icons.filter_list),
                        tooltip: 'Filter Options',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: Text('Location',
                              style: TextStyle(
                                  color: theme.onSurface.withOpacity(0.7))),
                          value: selectedLocation,
                          style: TextStyle(color: theme.onSurface),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.surface.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.secondary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.secondary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: theme.primary, width: 2),
                            ),
                          ),
                          items: locations
                              .map((loc) => DropdownMenuItem(
                                    value: loc,
                                    child: Text(loc,
                                        style:
                                            TextStyle(color: theme.onSurface)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLocation = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: Text('Language',
                              style: TextStyle(
                                  color: theme.onSurface.withOpacity(0.7))),
                          value: selectedLanguage,
                          style: TextStyle(color: theme.onSurface),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.surface.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.secondary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.secondary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: theme.primary, width: 2),
                            ),
                          ),
                          items: languagesDb
                              .map((lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang,
                                        style:
                                            TextStyle(color: theme.onSurface)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLanguage = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: Text('Status',
                              style: TextStyle(
                                  color: theme.onSurface.withOpacity(0.7))),
                          value: selectedStatus,
                          style: TextStyle(color: theme.onSurface),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.surface.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.secondary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: theme.secondary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: theme.primary, width: 2),
                            ),
                          ),
                          items: statuses
                              .map((status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status,
                                        style:
                                            TextStyle(color: theme.onSurface)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            searchQuery = '';
                            selectedLocation = null;
                            selectedLanguage = null;
                            selectedStatus = null;
                            showMyTasksOnly = false;
                            showAppliedOnly = false;
                            sortDesc = true;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, index) {
                      final task = sortedTasks[index];
                      final date = task['task_date'];
                      String dateLabel = '';
                      if (date != null && date.toString().isNotEmpty) {
                        try {
                          final parsedDate = DateTime.tryParse(date.toString());
                          if (parsedDate != null) {
                            dateLabel = DateFormat('MM/dd').format(parsedDate);
                          }
                        } catch (e) {
                          dateLabel = '';
                        }
                      }

                      final currentUserId =
                          Provider.of<UserService>(context, listen: false)
                              .currentUser
                              ?.id
                              .toString();
                      final isOwner = (task['creator_id']?.toString() ?? '') ==
                          (currentUserId ?? '');
                      final userNameBase =
                          task['creator_name']?.toString() ?? 'N/A Poster';
                      final userName =
                          isOwner ? '$userNameBase (You)' : userNameBase;
                      final title = task['title']?.toString() ?? '';
                      final location = task['location']?.toString() ?? '';
                      final rewardPoint =
                          task['reward_point']?.toString() ?? '0';
                      final languageRequirement =
                          task['language_requirement']?.toString() ?? '-';

                      return GestureDetector(
                        onTap: () => _showTaskDetailDialog(task),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.surface.withOpacity(0.9),
                            border: Border.all(
                                color: theme.secondary.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title.isNotEmpty
                                          ? title
                                          : 'Untitled Task',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.primary,
                                          fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.more_vert,
                                      size: 18, color: theme.onSurface),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 14,
                                      color: theme.onSurface.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      userName.isNotEmpty
                                          ? userName
                                          : 'Unknown User',
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.access_time,
                                      size: 14,
                                      color: theme.onSurface.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      dateLabel,
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14,
                                      color: theme.onSurface.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location.isNotEmpty
                                          ? location
                                          : 'No Location',
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.monetization_on_outlined,
                                      size: 14,
                                      color: theme.onSurface.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'NT\$$rewardPoint / hour',
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.chat_outlined,
                                      size: 14,
                                      color: theme.onSurface.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      languageRequirement,
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Popular",
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.schedule,
                                      size: 14,
                                      color: theme.onSurface.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "1 day ago",
                                      style: TextStyle(
                                          fontSize: 12, color: theme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const ThemeAwareIcon(
                                      icon: Icons.bookmark_border),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ));
      },
    );
  }
}

// home_page.dart
import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:here4help/chat/models/chat_room_model.dart';
import 'package:intl/intl.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/constants/task_status.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/services/data_preload_service.dart';
import 'package:provider/provider.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/user_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, this.initialTab = 0});

  final int initialTab; // 初始分頁：0 = Posted Tasks, 1 = My Works

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 移除 _taskFuture，不再使用 FutureBuilder
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String searchQuery = '';
  // 篩選狀態變數（nullable, 無選擇時為 null）
  String? selectedLocation;
  String? selectedHashtag;
  String? selectedStatus;
  // Tasker 篩選狀態
  bool taskerFilterEnabled = false;
  late TabController _tabController;
  static const int _pageSize = 10;
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 0);
  final PagingController<int, Map<String, dynamic>> _myWorksPagingController =
      PagingController(firstPageKey: 0);

  // 未讀通知占位（任務 26 會替換成實作）
  final NotificationService _notificationService =
      NotificationServicePlaceholder();
  Map<String, int> _unreadByTask = const {};
  Map<String, int> _unreadByRoom = const {};
  StreamSubscription<int>? _totalSub;
  StreamSubscription<Map<String, int>>? _taskSub;
  StreamSubscription<Map<String, int>>? _roomSub;

  // Posted Tasks 應徵者資料快取
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // 手風琴展開狀態管理
  final Set<String> _expandedTaskIds = <String>{};

  // My Works 分頁篩選狀態
  bool _showMyTasksOnly = false;
  bool _showAppliedOnly = true; // 預設開啟

  // 簡化的載入狀態
  bool _isLoading = true;
  String? _errorMessage;
  bool get _hasActiveFilters =>
      (selectedLocation != null && selectedLocation!.isNotEmpty) ||
      (selectedStatus != null && selectedStatus!.isNotEmpty) ||
      (searchQuery.isNotEmpty);

  /// 使用預載入服務初始化數據
  Future<void> _initializeWithPreload() async {
    if (!mounted) return;

    final preloadService = DataPreloadService();

    try {
      // 檢查數據是否已經預載入
      if (preloadService.isDataLoaded('chat_data')) {
        debugPrint('🚀 聊天數據已預載入，直接載入應徵者資料...');

        // 只需要載入應徵者數據
        await _loadApplicationsForPostedTasks();

        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        }
        debugPrint('⚡ 快速載入完成！');
      } else {
        debugPrint('🔄 數據未預載入，執行完整載入...');
        await _loadChatData();
      }
    } catch (e) {
      debugPrint('❌ 聊天數據初始化失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      searchQuery = '';
      selectedLocation = null;
      selectedHashtag = null;
      selectedStatus = null;
    });
    // 重新載入分頁
    _pagingController.refresh();
  }

  void _openFilterOptions({
    required List<String> locationOptions,
    required List<String> statusOptions,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        String tempLocation = selectedLocation ?? '';
        String tempStatus = selectedStatus ?? '';
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
              Text('Filter options', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempLocation.isEmpty ? null : tempLocation,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Location'),
                hint: const Text('Any'),
                items: locationOptions
                    .map(
                        (loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                    .toList(),
                onChanged: (val) => tempLocation = val ?? '',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tempStatus.isEmpty ? null : tempStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                hint: const Text('Any'),
                items: statusOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => tempStatus = val ?? '',
              ),
              const SizedBox(height: 16),
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
                        setState(() {
                          selectedLocation =
                              tempLocation.isEmpty ? null : tempLocation;
                          selectedStatus =
                              tempStatus.isEmpty ? null : tempStatus;
                        });
                        Navigator.of(ctx).pop();
                        _pagingController.refresh();
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
  }

  Future<void> _seedIfNeeded() async {
    try {
      // 僅開發模式才進行種子資料；避免 dead code 警告
      const bool isDev = true; // 可切換為 AppConfig.isDevelopment
      if (!isDev) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('has_seeded_chat') == true) return;
      await http.post(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/backend/api/tasks/generate-sample-data.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'count': _pageSize}),
      );
      await prefs.setBool('has_seeded_chat', true);
    } catch (_) {
      // 忽略種子錯誤以免影響正式流程
    }
  }

  Future<void> _fetchPage(int offset) async {
    await _seedIfNeeded();
    final service = TaskService();

    // Posted Tasks 只載入當前用戶發布的任務
    final userService = context.read<UserService>();
    final currentUserId = userService.currentUser?.id;

    Map<String, String>? filters;
    if (currentUserId != null) {
      filters = {'creator_id': currentUserId.toString()};
    }

    final result = await service.fetchTasksPage(
      limit: _pageSize,
      offset: offset,
      filters: filters,
    );

    if (!mounted) return;
    if (result.hasMore) {
      _pagingController.appendPage(result.tasks, offset + result.tasks.length);
    } else {
      _pagingController.appendLastPage(result.tasks);
    }
  }

  Future<void> _fetchMyWorksPage(int offset) async {
    final taskService = TaskService();
    final currentUserId = context.read<UserService>().currentUser?.id;
    if (currentUserId != null) {
      await taskService.loadMyApplications(currentUserId);
    }
    final all = _composeMyWorks(taskService, currentUserId);
    final filtered = all.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final location = (task['location'] ?? '').toString();
      final description = (task['description'] ?? '').toString().toLowerCase();
      final status = _displayStatus(task);
      final query = searchQuery.toLowerCase();
      final matchQuery = query.isEmpty ||
          title.contains(query) ||
          location.toLowerCase().contains(query) ||
          description.contains(query);
      final matchLocation =
          selectedLocation == null || selectedLocation == location;
      final matchStatus = selectedStatus == null || selectedStatus == status;
      return matchQuery && matchLocation && matchStatus;
    }).toList();

    final start = offset;
    final end = (offset + _pageSize) > filtered.length
        ? filtered.length
        : (offset + _pageSize);
    final slice = filtered.sublist(start, end);
    final hasMore = end < filtered.length;
    if (!mounted) return;
    if (hasMore) {
      _myWorksPagingController.appendPage(slice, end);
    } else {
      _myWorksPagingController.appendLastPage(slice);
    }
  }

  /// 同步載入所有聊天相關數據
  Future<void> _loadChatData() async {
    if (!mounted) return;

    try {
      debugPrint('🔄 開始同步載入聊天數據...');

      // 同步載入任務和狀態
      await Future.wait([
        TaskService().loadTasks(),
        TaskService().loadStatuses(),
      ]);
      debugPrint('✅ 任務列表載入完成');

      // 載入應徵者數據
      await _loadApplicationsForPostedTasks();
      debugPrint('✅ 應徵者資料載入完成');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      debugPrint('🎉 聊天數據載入完成！');
    } catch (e) {
      debugPrint('❌ 聊天數據載入失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // 使用預載入服務，如果數據已預載入則立即可用
    _initializeWithPreload();

    // 設定分頁監聽
    _pagingController.addPageRequestListener((offset) {
      _fetchPage(offset);
    });
    _myWorksPagingController.addPageRequestListener((offset) {
      _fetchMyWorksPage(offset);
    });

    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          taskerFilterEnabled = _tabController.index == 1;
          // 重設搜尋與篩選
          _searchController.clear();
          searchQuery = '';
          selectedLocation = null;
          selectedHashtag = null;
          selectedStatus = null;
        });
        // 切換分頁時同步刷新各自分頁控制器
        _pagingController.refresh();
        _myWorksPagingController.refresh();
      }
    });

    // 初始化未讀占位並訂閱
    _notificationService.init(userId: 'placeholder');
    _totalSub = _notificationService.observeTotalUnread().listen((v) {
      if (!mounted) return;
      // 目前未顯示總未讀，僅維持訂閱以後續擴充；不存入狀態避免未使用警告
    });
    _taskSub = _notificationService.observeUnreadByTask().listen((m) {
      if (!mounted) return;
      setState(() => _unreadByTask = m);
    });
    _roomSub = _notificationService.observeUnreadByRoom().listen((m) {
      if (!mounted) return;
      setState(() => _unreadByRoom = m);
    });

    // 添加應用生命週期監聽
    WidgetsBinding.instance.addObserver(this);
  }

  // 整理 My Works 清單：把 tasks 與 myApplications 合併，並標記 client 狀態
  List<Map<String, dynamic>> _composeMyWorks(
      TaskService service, int? currentUserId) {
    final allTasks = List<Map<String, dynamic>>.from(service.tasks);
    final apps = service.myApplications;
    final Set<String> appliedTaskIds =
        apps.map((e) => (e['id'] ?? e['task_id']).toString()).toSet();

    // 標記 applied_by_me 與覆蓋顯示狀態
    for (final t in allTasks) {
      final id = (t['id'] ?? '').toString();
      if (appliedTaskIds.contains(id)) {
        t['applied_by_me'] = true;
        // 來自 API 的 client 狀態優先
        final app = apps.firstWhere(
            (e) => (e['id'] == id) || (e['task_id']?.toString() == id),
            orElse: () => {});
        if (app.isNotEmpty) {
          t['status_display'] =
              app['client_status_display'] ?? t['status_display'];
          t['status_code'] = app['client_status_code'] ?? t['status_code'];
        }
      }
    }

    // My Works 準則：根據篩選狀態決定顯示內容
    return allTasks.where((t) {
      final acceptorIsMe = (t['acceptor_id']?.toString() ?? '') ==
          (currentUserId?.toString() ?? '');
      final appliedByMe = t['applied_by_me'] == true;
      
      // 根據篩選狀態決定是否顯示
      bool shouldShow = false;
      
      if (_showMyTasksOnly && _showAppliedOnly) {
        // 兩個都勾選：顯示全部
        shouldShow = acceptorIsMe || appliedByMe;
      } else if (_showMyTasksOnly) {
        // 只勾選我的任務：顯示被指派的任務
        shouldShow = acceptorIsMe;
      } else if (_showAppliedOnly) {
        // 只勾選已應徵：顯示我應徵過的任務
        shouldShow = appliedByMe;
      } else {
        // 都不勾選：顯示全部任務（不按任務類型過濾）
        shouldShow = true;
      }
      
      return shouldShow;
    }).toList();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _myWorksPagingController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _totalSub?.cancel();
    _taskSub?.cancel();
    _roomSub?.cancel();
    _notificationService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 當應用恢復前台時，重新載入數據
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 應用恢復前台，重新載入聊天數據');
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        _loadChatData();
      }
    }
  }

  String _displayStatus(Map<String, dynamic> task) {
    final dynamic display = task['status_display'];
    if (display != null && display is String && display.isNotEmpty) {
      return display;
    }
    final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
    final mapped = TaskStatus.statusString[codeOrLegacy] ?? codeOrLegacy;
    return (mapped ?? '').toString();
  }

  void _showTaskInfoDialog(Map<String, dynamic> task) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPostedTab = !taskerFilterEnabled;
    final displayStatus = _displayStatus(task);
    final canEditDelete = isPostedTab && displayStatus == 'Open';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: true,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.assignment_outlined,
                                      color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Task Info',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  Chip(
                                    label: Text(
                                      displayStatus,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: colorScheme
                                        .primaryContainer
                                        .withOpacity(0.25),
                                    side: BorderSide(
                                        color: colorScheme.primary
                                            .withOpacity(0.4)),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                  ),
                                ],
                              ),
                              if (canEditDelete) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        context.push('/task/create');
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(height: 2),
                                            Text('Edit',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () async {
                                        Navigator.of(context).pop();
                                        await _confirmAndDeleteTask(task);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete_outline,
                                                size: 18,
                                                color: Colors.redAccent),
                                            SizedBox(height: 2),
                                            Text('Delete',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            children: [
                              _infoRow(
                                  Icons.title, 'Title', task['title'] ?? 'N/A'),
                              _infoRow(Icons.person_outline, 'Poster',
                                  (task['creator_name'] ?? 'N/A').toString()),
                              _infoRow(Icons.place_outlined, 'Location',
                                  '${task['location']}'),
                              _infoRow(Icons.paid_outlined, 'Reward',
                                  '${task['reward_point'] ?? task['salary']}'),
                              _infoRow(
                                  Icons.event_outlined,
                                  'Date',
                                  DateFormat('yyyy-MM-dd').format(
                                      DateTime.parse(task['task_date']))),
                              _infoRow(Icons.language_outlined, 'Language',
                                  '${task['language_requirement']}'),
                              const SizedBox(height: 8),
                              const Divider(height: 16),
                              _infoMultilineRow(
                                Icons.description_outlined,
                                'Description',
                                (task['description'] ??
                                        'No description provided')
                                    .toString(),
                              ),
                              const SizedBox(height: 8),
                              _infoRow(
                                  Icons.schedule_outlined,
                                  'Created',
                                  _formatDateTimeString(
                                      task['created_at']?.toString())),
                              _infoRow(
                                  Icons.update,
                                  'Updated',
                                  _formatDateTimeString(
                                      task['updated_at']?.toString())),
                              const SizedBox(height: 16),
                              Center(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 4.0, horizontal: 8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close),
                                        SizedBox(height: 2),
                                        Text('Close',
                                            style: TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
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
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
              width: 88,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // 多行內容資訊列
  Widget _infoMultilineRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
              width: 88,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTimeString(String? input) {
    if (input == null || input.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(input);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return input;
    }
  }

  Future<void> _confirmAndDeleteTask(Map<String, dynamic> task) async {
    final confirm = await _showDoubleConfirmDialog(
        'Delete Task', 'Are you sure you want to delete this task?');
    if (confirm != true) return;

    // Loading 動畫（不要 await，否則會阻塞後續 pop）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Deleting...'),
          ],
        ),
      ),
    );

    // 模擬延遲與執行刪除
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      TaskService().tasks.removeWhere((t) => t['id'] == task['id']);
    });

    // 關閉 Loading 並顯示成功效果
    if (mounted) Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Deleted'),
          ],
        ),
      ),
    );
    // 自動關閉成功提示
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _showDoubleConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Deprecated: 目前未使用，若需狀態徽章樣式可再啟用
  Color _getStatusChipColor(String status, String type) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.getDisplayStatus(status);

    // Only return text color, ignore background.
    switch (displayStatus) {
      case 'Open':
        return Colors.blue[800]!;
      case 'In Progress':
        return Colors.orange[800]!;
      case 'Dispute':
        return Colors.red[800]!;
      case 'Pending Confirmation':
        return Colors.purple[800]!;
      case 'Completed':
        return Colors.grey[800]!;
      case 'Applying (Tasker)':
        return Colors.blue[800]!;
      case 'In Progress (Tasker)':
        return Colors.orange[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  // Deprecated: 目前未使用
  Color _getStatusChipBorderColor(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.getDisplayStatus(status);

    switch (displayStatus) {
      case 'Open':
        return Colors.blue[100]!;
      case 'In Progress':
        return Colors.orange[100]!;
      case 'Dispute':
        return Colors.red[100]!;
      case 'Pending Confirmation':
        return Colors.purple[100]!;
      case 'Completed':
        return Colors.grey[100]!;
      case 'Applying (Tasker)':
        return Colors.blue[100]!;
      case 'In Progress (Tasker)':
        return Colors.orange[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  bool _isCountdownStatus(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.getDisplayStatus(status);

    return displayStatus == TaskStatus.statusString['pending_confirmation'] ||
        displayStatus == TaskStatus.statusString['pending_confirmation_tasker'];
  }

  /// 根據狀態返回進度值和顏色
  Map<String, dynamic> _getProgressData(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    const int colorRates = 200;
    switch (displayStatus) {
      case 'Open':
        return {'progress': 0.0, 'color': Colors.blue[colorRates]!};
      case 'In Progress':
        return {'progress': 0.25, 'color': Colors.orange[colorRates]!};
      case 'Pending Confirmation':
        return {'progress': 0.5, 'color': Colors.purple[colorRates]!};
      case 'Completed':
        return {'progress': 1.0, 'color': Colors.lightGreen[colorRates]!};
      case 'Dispute':
        return {'progress': 0.75, 'color': Colors.brown[colorRates]!};
      case 'Applying (Tasker)':
        return {'progress': 0.0, 'color': Colors.lightGreenAccent[colorRates]!};
      case 'In Progress (Tasker)':
        return {'progress': 0.25, 'color': Colors.orange[colorRates]!};
      case 'Completed (Tasker)':
        return {'progress': 1.0, 'color': Colors.green[colorRates]!};
      case 'Rejected (Tasker)':
        return {'progress': 1.0, 'color': Colors.blueGrey[colorRates]!};
      default:
        return {
          'progress': null,
          'color': Colors.lightBlue[colorRates]!
        }; // 其他狀態
    }
  }

  // Deprecated: 目前未使用（保留作為未來進度條樣式的範本）
  Widget _taskCardWithProgressBar(Map<String, dynamic> task) {
    final String displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'];
    final color = progressData['color'] ?? Colors.grey[600]!; // ignore: unused_local_variable

    return InkWell(
      onTap: () => _showTaskInfoDialog(task),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        clipBehavior: Clip.hardEdge,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              if (progress != null) ...[
                // 進度條
                SizedBox(
                  height: 30, // 確保容器高度足夠
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      LinearProgressIndicator(
                        value: _getProgressData(displayStatus)['progress'],
                        backgroundColor: Colors.grey[300],
                        color: _getProgressData(displayStatus)['color'],
                        minHeight: 20,
                      ),
                      Text(
                        _getProgressLabel(displayStatus),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                // 顯示 Label 或 Chip
                Chip(
                  label: Text(displayStatus),
                  backgroundColor: Colors.transparent,
                  labelStyle: const TextStyle(color: Colors.red),
                  side: const BorderSide(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskCardWithapplierChatItems(
      Map<String, dynamic> task, List<Map<String, dynamic>> applierChatItems) {
    // applierChatItems with isHidden == true are filtered out
    final visibleapplierChatItems =
        applierChatItems.where((ap) => ap['isHidden'] != true).toList();
    final taskUnreadCount = _unreadByTask[task['id']] ?? 0;

    Widget cardContent = Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => _showTaskInfoDialog(task),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            clipBehavior: Clip.hardEdge,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isCountdownStatus(_displayStatus(task))) ...[
                    _buildCountdownTimer(task),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task['title'] ?? 'N/A',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: null,
                          softWrap: true,
                        ),
                      ),
                      // Emoji 狀態列
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 新任務圖標（發布未滿一週）
                          if (_isNewTask(task)) 
                            const Text('🌱', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          // 熱門圖標（超過一位應徵者）
                          if (_isPopularTask(task)) 
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          // 收藏圖標（當前使用者已收藏）
                          if (_isFavoritedTask(task)) 
                            const Text('❤️', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  // 格狀排版的 task 資訊（上下欄對齊、左右有間隔，無背景色與圓角）- new layout
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16, color: Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('${task['location']}')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💰'),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(
                                          '${task['reward_point'] ?? task['salary']}')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('📅'),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat('yyyy-MM-dd').format(
                                          DateTime.parse(task['task_date'])),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('🌐'),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(
                                          '${task['language_requirement']}')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      // 顯示進度條
                      SizedBox(
                        height: 30, // 確保容器高度足夠
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            LinearProgressIndicator(
                              value: _getProgressData(
                                  _displayStatus(task))['progress'],
                              backgroundColor: Colors.grey[300],
                              color: _getProgressData(
                                  _displayStatus(task))['color'],
                              minHeight: 20,
                            ),
                            Text(
                              _getProgressLabel(_displayStatus(task)),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...visibleapplierChatItems.map(
                    (applierChatItem) => Slidable(
                      key: ValueKey(applierChatItem['id']),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) {
                              setState(() {
                                visibleapplierChatItems.remove(applierChatItem);
                                visibleapplierChatItems.insert(
                                    0, applierChatItem);
                                applierChatItems.remove(applierChatItem);
                                applierChatItems.insert(0, applierChatItem);
                              });
                              Slidable.of(context)?.close();
                            },
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.black,
                            icon: Icons.push_pin,
                            label: 'Pin',
                          ),
                          SlidableAction(
                            onPressed: (_) {
                              setState(() {
                                applierChatItem['isMuted'] =
                                    !(applierChatItem['isMuted'] ?? false);
                              });
                              Slidable.of(context)?.close();
                            },
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.black,
                            icon: applierChatItem['isMuted'] == true
                                ? Icons.volume_up
                                : Icons.volume_off,
                            label: 'Mute',
                          ),
                        ],
                      ),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: _buildApplierEndActions(
                            context, task, applierChatItem),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Card(
                            clipBehavior: Clip.hardEdge,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _getAvatarColor(applierChatItem['name']),
                                child: Text(
                                  _getInitials(applierChatItem['name']),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      applierChatItem['name'],
                                      maxLines: null,
                                      softWrap: true,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                  if (applierChatItem['isMuted'] == true) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.volume_off, size: 16),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                applierChatItem['sentMessages'][0],
                                maxLines: null,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star,
                                          color:
                                              Color.fromARGB(255, 255, 187, 0),
                                          size: 16),
                                      Text('${applierChatItem['rating']}',
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  Text('(${applierChatItem['reviewsCount']})',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              onTap: () async {
                                // 1) 計算基礎資訊
                                const userRole = 'creator';
                                final String taskId =
                                    task['id']?.toString() ?? '';
                                final int? posterId =
                                    (task['creator_id'] is int)
                                        ? task['creator_id']
                                        : int.tryParse('${task['creator_id']}');
                                final int? applicantId =
                                    (applierChatItem['user_id'] is int)
                                        ? applierChatItem['user_id']
                                        : int.tryParse(
                                            '${applierChatItem['user_id']}');

                                // Debug 資料值
                                debugPrint(
                                    '🔍 點擊應徵者卡片 - taskId: $taskId, posterId: $posterId, applicantId: $applicantId');
                                debugPrint('🔍 task keys: ${task.keys}');
                                debugPrint(
                                    '🔍 applierChatItem keys: ${applierChatItem.keys}');
                                debugPrint(
                                    '🔍 task[creator_id]: ${task['creator_id']} (${task['creator_id'].runtimeType})');
                                debugPrint(
                                    '🔍 applierChatItem[user_id]: ${applierChatItem['user_id']} (${applierChatItem['user_id'].runtimeType})');

                                if (taskId.isEmpty ||
                                    posterId == null ||
                                    applicantId == null) {
                                  debugPrint(
                                      '❌ 進入聊天室缺少必要參數: taskId/posterId/applicantId');
                                  return;
                                }

                                // 2) 透過後端 ensure_room 取得資料庫的真實 BIGINT room_id
                                final chatService = ChatService();
                                final roomResult = await chatService.ensureRoom(
                                  taskId: taskId,
                                  creatorId: posterId,
                                  participantId: applicantId,
                                );
                                final roomData = roomResult['room'] ?? {};
                                final String realRoomId =
                                    roomData['id']?.toString() ?? '';
                                if (realRoomId.isEmpty) {
                                  debugPrint('❌ 無法取得真實 room_id');
                                  return;
                                }

                                // 3) 準備聊天夥伴資訊與 room payload（使用真實 room_id）
                                final partnerName = applierChatItem['name'] ??
                                    applierChatItem['participant_name'] ??
                                    'Applicant';
                                final partnerAvatar =
                                    applierChatItem['avatar'] ??
                                        applierChatItem['participant_avatar'];
                                final chatPartnerInfo = {
                                  'id': applierChatItem['user_id'] ??
                                      applierChatItem['participant_id'],
                                  'name': partnerName,
                                  'avatar': (partnerAvatar != null &&
                                          partnerAvatar
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                      ? partnerAvatar
                                      : null, // 使用 null 讓 UI 層顯示首字母頭像
                                  'role': 'participant',
                                };

                                final roomPayload = {
                                  ...applierChatItem,
                                  'id': roomData['id'],
                                  'roomId': realRoomId,
                                  'taskId': taskId,
                                  'task_id': taskId,
                                  'creator_id': posterId,
                                  'participant_id': applicantId,
                                  'participant_avatar':
                                      applierChatItem['participant_avatar'] ??
                                          applierChatItem['avatar'],
                                };

                                // 4) 保存持久化數據並設置當前會話（使用真實 room_id 作為 key）
                                await ChatStorageService.savechatRoomData(
                                  roomId: realRoomId,
                                  room: roomPayload,
                                  task: task,
                                  userRole: userRole,
                                  chatPartnerInfo: chatPartnerInfo,
                                );
                                await ChatSessionManager.setCurrentChatSession(
                                  roomId: realRoomId,
                                  room: roomPayload,
                                  task: task,
                                  userRole: userRole,
                                  chatPartnerInfo: chatPartnerInfo,
                                  sourceTab: 'posted-tasks',
                                );

                                // 5) 產生正確 URL 並導頁
                                final chatUrl =
                                    ChatStorageService.generateChatUrl(
                                  roomId: realRoomId,
                                  taskId: taskId,
                                );
                                final data = {
                                  'room': roomPayload,
                                  'task': task,
                                  'userRole': userRole,
                                  'chatPartnerInfo': chatPartnerInfo,
                                };

                                debugPrint('🔍 [Posted Tasks] 準備導航到聊天室');
                                debugPrint(
                                    '🔍 [Posted Tasks] chatUrl: $chatUrl');
                                debugPrint(
                                    '🔍 [Posted Tasks] extra data: $data');

                                context.go(chatUrl, extra: data);
                              },
                            ),
                          ),
                          if (((_unreadByRoom[applierChatItem['id']] ?? 0)) > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_unreadByRoom[applierChatItem['id']] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 總未讀徽章（右上角）
        if (taskUnreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Center(
                child: Text(
                  '$taskUnreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    // 外層左右滑動移除：直接返回卡片內容（點擊卡片顯示懸浮視窗）
    return cardContent;
  }

  /// 倒數計時器：Pending Confirmation 狀態下顯示，倒數7天（以 updated_at 起算），結束時自動設為 Completed
  Widget _buildCountdownTimer(Map<String, dynamic> task) {
    return _CountdownTimerWidget(
      task: task,
      onCountdownComplete: () {
        setState(() {
          // Convert database status to display status for comparison
          final displayStatus =
              TaskStatus.statusString[task['status']] ?? task['status'];

          if (displayStatus ==
              TaskStatus.statusString['pending_confirmation']) {
            task['status'] = 'completed'; // Use database status
          } else if (displayStatus ==
              TaskStatus.statusString['pending_confirmation_tasker']) {
            task['status'] = 'completed_tasker'; // Use database status
          }
        });
      },
    );
  }

  /// My Works 分頁的緊湊倒數計時器
  Widget _buildCompactCountdownTimer(Map<String, dynamic> task) {
    return _CompactCountdownTimerWidget(
      task: task,
      onCountdownComplete: () {
        setState(() {
          // Convert database status to display status for comparison
          final displayStatus =
              TaskStatus.statusString[task['status']] ?? task['status'];

          if (displayStatus ==
              TaskStatus.statusString['pending_confirmation']) {
            task['status'] = 'completed'; // Use database status
          } else if (displayStatus ==
              TaskStatus.statusString['pending_confirmation_tasker']) {
            task['status'] = 'completed_tasker'; // Use database status
          }
        });
      },
    );
  }

  String _getProgressLabel(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    final progressData = _getProgressData(status);
    final progress = progressData['progress'];
    if (displayStatus == 'Rejected') {
      return displayStatus; // 不顯示百分比
    }
    if (progress == null) {
      return displayStatus; // 非進度條狀態僅顯示狀態名稱
    }
    final percentage = (progress * 100).toInt();
    return '$displayStatus ($percentage%)';
  }

  @override
  Widget build(BuildContext context) {
    final taskService = TaskService();
    final statusOrder = {
      'Open': 0,
      'In Progress': 1,
      'Pending Confirmation': 2,
      'Dispute': 3,
      'Completed': 4,
    };

    // 如果正在載入，顯示 loading
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading chat data...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // 如果有錯誤，顯示錯誤
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading data'),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadChatData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // 載入完成後的正常 UI
    final tasks = taskService.tasks;
    tasks.sort((a, b) {
      // Convert database status to display status for sorting
      final displayStatusA =
          (a['status_display'] ?? a['status']) as String? ?? '';
      final displayStatusB =
          (b['status_display'] ?? b['status']) as String? ?? '';

      final statusA = statusOrder[displayStatusA] ?? 99;
      final statusB = statusOrder[displayStatusB] ?? 99;
      if (statusA != statusB) {
        return statusA.compareTo(statusB);
      }
      return (DateTime.parse(b['task_date']))
          .compareTo(DateTime.parse(a['task_date']));
    });

    final filteredTasksForDropdown = tasks;
    final locationOptions = filteredTasksForDropdown
        .map((e) => (e['location'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    // 從後端 `task_statuses` 取狀態顯示名稱
    final service = TaskService();
    final statusOptions = service.statuses
        .map((e) => (e['display_name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return DefaultTabController(
      length: 2,
      initialIndex: taskerFilterEnabled ? 1 : 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              indicatorPadding: EdgeInsets.zero,
              tabs: [
                const Tab(text: 'Posted Tasks'),
                Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('My Works'),
                      Text(
                        '${_myWorksPagingController.itemList?.length ?? 0}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // My Works 分頁篩選選項
          if (_tabController.index == 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Show My Tasks', style: TextStyle(fontSize: 12)),
                      value: _showMyTasksOnly,
                      onChanged: (value) {
                        setState(() {
                          _showMyTasksOnly = value ?? false;
                        });
                        _myWorksPagingController.refresh();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Show Applied Tasks', style: TextStyle(fontSize: 12)),
                      value: _showAppliedOnly,
                      onChanged: (value) {
                        setState(() {
                          _showAppliedOnly = value ?? false;
                        });
                        _myWorksPagingController.refresh();
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 搜尋欄
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Search bar + inline actions
                Expanded(
                  child: TextField(
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
                      hintText: 'Search...',
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
                            onPressed: () {
                              _openFilterOptions(
                                locationOptions: locationOptions,
                                statusOptions: statusOptions,
                              );
                            },
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
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostedTasksPaged(),
                _buildMyWorksPaged(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(bool taskerEnabled) {
    final taskService = TaskService();
    // currentUserId 僅在下方分支條件中使用
    final currentUserId = context
        .read<UserService>()
        .currentUser
        ?.id; // ignore: unused_local_variable
    if (taskerEnabled && currentUserId != null) {
      // 確保載入我的應徵
      taskService.loadMyApplications(currentUserId);
    }
    final statusOrder = {
      'Open': 0,
      'In Progress': 1,
      'Pending Confirmation': 2,
      'Dispute': 3,
      'Completed': 4,
    };
    final tasks = taskerEnabled
        ? _composeMyWorks(taskService, currentUserId)
        : taskService.tasks;
    tasks.sort((a, b) {
      // Convert database status to display status for sorting
      final displayStatusA =
          (a['status_display'] ?? a['status']) as String? ?? '';
      final displayStatusB =
          (b['status_display'] ?? b['status']) as String? ?? '';

      final statusA = statusOrder[displayStatusA] ?? 99;
      final statusB = statusOrder[displayStatusB] ?? 99;
      if (statusA != statusB) {
        return statusA.compareTo(statusB);
      }
      return (DateTime.parse(b['task_date']))
          .compareTo(DateTime.parse(a['task_date']));
    });
    final filteredTasks = tasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final location = (task['location'] ?? '').toString();
      // final hashtags = (task['hashtags'] as List<dynamic>? ?? [])
      //     .map((h) => h.toString())
      //     .toList();
      final status = _displayStatus(task);
      final description = (task['description'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      final matchQuery = query.isEmpty ||
          title.contains(query) ||
          location.toLowerCase().contains(query) ||
          description.contains(query);
      final matchLocation =
          selectedLocation == null || selectedLocation == location;
      final displayStatus = status;
      final matchStatus =
          selectedStatus == null || selectedStatus == displayStatus;
      // My Works：接受者是我，或我有應徵紀錄
      final isMyWork = taskerEnabled
          ? ((task['acceptor_id']?.toString() == currentUserId?.toString()) ||
              (task['applied_by_me'] == true))
          : (task['creator_id']?.toString() != currentUserId?.toString());
      final matchTasker = taskerEnabled ? isMyWork : !isMyWork;
      return matchQuery && matchLocation && matchStatus && matchTasker;
    }).toList();
    return SlidableAutoCloseBehavior(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: filteredTasks.map((task) {
          final taskId = task['id'].toString();

          // 判斷是否為 Posted Tasks 模式
          final isPostedTasksTab = _tabController.index == 0;
          final userService = context.read<UserService>();
          final currentUserId = userService.currentUser?.id;
          final isMyTask = currentUserId != null &&
              (task['creator_id'] == currentUserId ||
                  task['creator_id']?.toString() == currentUserId.toString());

          List<Map<String, dynamic>> applierChatItems;

          if (isPostedTasksTab && isMyTask) {
            // Posted Tasks: 使用真實應徵者資料
            final applications = _applicationsByTask[taskId] ?? [];
            applierChatItems =
                _convertApplicationsToApplierChatItems(applications);
          } else {
            // My Works 或非我的任務: 使用 demo 資料（暫時）
            applierChatItems = chatRoomModel
                .where((applierChatItem) =>
                    applierChatItem['taskId'] == task['id'])
                .toList();
          }

          // My Works 分頁使用特殊的聊天室列表設計
          if (taskerEnabled) {
            return _buildMyWorksChatRoomItem(task, applierChatItems);
          } else {
            return _taskCardWithapplierChatItems(task, applierChatItems);
          }
        }).toList(),
      ),
    );
  }

  // Posted Tasks 分頁 + 保留原卡 UI
  Widget _buildPostedTasksPaged() {
    return RefreshIndicator(
      onRefresh: () async => _pagingController.refresh(),
      child: PagedListView<int, Map<String, dynamic>>(
        padding: const EdgeInsets.all(12),
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
          itemBuilder: (context, task, index) {
            // Posted Tasks 分頁：所有任務都是當前用戶發布的任務
            final taskId = task['id'].toString();
            final applications = _applicationsByTask[taskId] ?? [];
            final applierChatItems =
                _convertApplicationsToApplierChatItems(applications);

            return _buildPostedTasksCardWithAccordion(task, applierChatItems);
          },
          firstPageProgressIndicatorBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
          newPageProgressIndicatorBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
          noItemsFoundIndicatorBuilder: (context) =>
              const Center(child: Text('No tasks found')),
        ),
      ),
    );
  }

  Widget _buildMyWorksPaged() {
    return RefreshIndicator(
      onRefresh: () async => _myWorksPagingController.refresh(),
      child: PagedListView<int, Map<String, dynamic>>(
        padding: const EdgeInsets.all(12),
        pagingController: _myWorksPagingController,
        builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
          itemBuilder: (context, task, index) {
            final applierChatItems = chatRoomModel
                .where((room) => room['taskId'] == task['id'])
                .toList();
            return _buildMyWorksChatRoomItem(task, applierChatItems);
          },
          firstPageProgressIndicatorBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
          newPageProgressIndicatorBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
          noItemsFoundIndicatorBuilder: (context) =>
              const Center(child: Text('No tasks found')),
        ),
      ),
    );
  }

  /// 載入所有我發布任務的應徵者資料
  Future<void> _loadApplicationsForPostedTasks() async {
    final userService = context.read<UserService>();
    final currentUserId = userService.currentUser?.id;
    if (currentUserId == null) return;

    final taskService = TaskService();

    // 確保任務已經載入
    if (taskService.tasks.isEmpty) {
      debugPrint('Tasks not loaded yet, waiting...');
      await taskService.loadTasks();
    }

    final myPostedTasks = taskService.tasks.where((task) {
      final creatorId = task['creator_id'];
      return creatorId == currentUserId ||
          creatorId?.toString() == currentUserId.toString();
    }).toList();

    debugPrint(
        'Found ${myPostedTasks.length} posted tasks for user $currentUserId');

    for (final task in myPostedTasks) {
      try {
        final applications =
            await taskService.loadApplicationsByTask(task['id'].toString());
        _applicationsByTask[task['id'].toString()] = applications;
        debugPrint(
            'Loaded ${applications.length} applications for task ${task['id']}');
      } catch (e) {
        debugPrint('Failed to load applications for task ${task['id']}: $e');
      }
    }

    // 觸發 UI 更新
    if (mounted) {
      setState(() {});
    }
  }

  /// 指派應徵者
  Future<void> _approveApplication(
      Map<String, dynamic> task, Map<String, dynamic> applierChatItem) async {
    try {
      final userService = context.read<UserService>();
      final currentUserId = userService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      final taskId = task['id'].toString();
      final userId = applierChatItem['user_id'];

      if (userId == null) {
        throw Exception('Invalid applier user ID');
      }

      // 顯示載入對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Approving application...'),
            ],
          ),
        ),
      );

      final result = await TaskService().approveApplication(
        taskId: taskId,
        userId: userId,
        posterId: currentUserId,
      );

      if (mounted) Navigator.of(context).pop(); // 關閉載入對話框

      // 更新本地快取
      setState(() {
        // 更新任務狀態
        task['status_id'] = result['status_id'];
        task['status_code'] = result['status_code'];
        task['status_display'] = result['status_display'];
        task['acceptor_id'] = userId;

        // 更新應徵者狀態
        applierChatItem['application_status'] = 'accepted';

        // 更新其他應徵者為 rejected
        final taskApplications = _applicationsByTask[taskId] ?? [];
        for (final app in taskApplications) {
          if (app['user_id'] != userId) {
            app['application_status'] = 'rejected';
          }
        }
      });

      // 重新載入該任務的應徵者資料
      _loadApplicationsForPostedTasks();

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 關閉載入對話框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 拒絕應徵者
  Future<void> _rejectApplication(
      Map<String, dynamic> task, Map<String, dynamic> applierChatItem) async {
    try {
      final userService = context.read<UserService>();
      final currentUserId = userService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not logged in');
      }

      final taskId = task['id'].toString();
      final userId = applierChatItem['user_id'];

      if (userId == null) {
        throw Exception('Invalid applier user ID');
      }

      // 顯示確認對話框
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject Application'),
          content: Text(
              'Are you sure you want to reject ${applierChatItem['name']}\'s application?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // 顯示載入對話框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Rejecting application...'),
            ],
          ),
        ),
      );

      await TaskService().rejectApplication(
        taskId: taskId,
        userId: userId,
        posterId: currentUserId,
      );

      if (mounted) Navigator.of(context).pop(); // 關閉載入對話框

      // 更新本地快取
      setState(() {
        applierChatItem['application_status'] = 'rejected';
      });

      // 顯示成功訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 關閉載入對話框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 將應徵者資料轉換為聊天室格式
  List<Map<String, dynamic>> _convertApplicationsToApplierChatItems(
      List<Map<String, dynamic>> applications) {
    return applications.map((app) {
      debugPrint('🔍 轉換應徵者資料: ${app.keys}');
      debugPrint(
          '🔍 應徵者名稱: ${app['applier_name']}, 頭像: ${app['applier_avatar']}');

      return {
        'id': 'app_${app['application_id'] ?? app['user_id']}',
        'taskId': app['task_id'],
        'name': app['applier_name'] ?? 'Anonymous',
        'avatar': app['applier_avatar'], // 對應後端的 u.avatar_url AS applier_avatar
        'participant_avatar': app['applier_avatar'], // 備用字段
        'participant_avatar_url': app['applier_avatar'], // 備用字段
        'rating': 4.0, // 預設評分，未來可從 API 取得
        'reviewsCount': 0, // 預設評論數，未來可從 API 取得
        'questionReply': app['cover_letter'] ?? '',
        'sentMessages': [app['cover_letter'] ?? 'Applied for this task'],
        'user_id': app['user_id'],
        'participant_id': app['user_id'], // 備用字段
        'application_id': app['application_id'],
        'application_status': app['application_status'] ?? 'applied',
        'answers_json': app['answers_json'],
        'created_at': app['created_at'],
        'isMuted': false,
        'isHidden': false,
      };
    }).toList();
  }

  /// 獲取聊天對象信息
  Map<String, dynamic> _getChatPartnerInfo(
      Map<String, dynamic> task, String userRole,
      [Map<String, dynamic>? room]) {
    final currentUserId = context.read<UserService>().currentUser?.id;

    debugPrint(
        '🔍 _getChatPartnerInfo - userRole: $userRole, currentUserId: $currentUserId');
    debugPrint('🔍 _getChatPartnerInfo - task keys: ${task.keys}');
    debugPrint('🔍 _getChatPartnerInfo - room keys: ${room?.keys}');

    if (userRole == 'creator') {
      // 當前用戶是創建者，聊天對象是參與者
      if (room != null && room.isNotEmpty) {
        final dynamic id = room['user_id'] ?? room['participant_id'];
        final String name =
            room['name'] ?? room['participant_name'] ?? 'Applicant';
        // 不使用預設圖，改用首字母圓形頭像
        String? avatar;
        final List<dynamic> avatarCandidates = [
          room['participant_avatar_url'], // 從 ensure_room 返回
          room['participant_avatar'], // 從 ensure_room 返回
          (room['other_user'] is Map)
              ? (room['other_user'] as Map)['avatar']
              : null, // 從 get_rooms 返回
          room['avatar'], // 通用字段
          task['participant_avatar_url'], // 任務數據
          task['participant_avatar'], // 任務數據
          task['acceptor_avatar_url'], // 接受者數據
          task['acceptor_avatar'], // 接受者數據
        ];
        for (final c in avatarCandidates) {
          if (c != null && c.toString().isNotEmpty) {
            avatar = c.toString();
            break;
          }
        }

        return {
          'id': id?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      } else {
        // 沒有聊天室，從任務數據推導
        final String name = task['participant_name'] ?? 'Applicant';
        String? avatar = task['participant_avatar_url'] ??
            task['participant_avatar'] ??
            task['acceptor_avatar_url'] ??
            task['acceptor_avatar'];

        return {
          'id': task['participant_id']?.toString() ??
              task['acceptor_id']?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      }
    } else {
      // 當前用戶是參與者，聊天對象是創建者
      if (room != null && room.isNotEmpty) {
        final dynamic id = room['creator_id'];
        final String name = room['creator_name'] ?? 'Task Creator';
        String? avatar = room['creator_avatar_url'] ?? room['creator_avatar'];

        return {
          'id': id?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      } else {
        // 沒有聊天室，從任務數據推導
        final String name = task['creator_name'] ?? 'Task Creator';
        String? avatar = task['creator_avatar_url'] ?? task['creator_avatar'];

        return {
          'id': task['creator_id']?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      }
    }
  }

  /// 判斷是否為新任務（發布未滿一週）
  bool _isNewTask(Map<String, dynamic> task) {
    try {
      final createdAt = DateTime.parse(task['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(createdAt);
      return difference.inDays < 7;
    } catch (e) {
      return false;
    }
  }

  /// 判斷是否為熱門任務（超過一位應徵者）
  bool _isPopularTask(Map<String, dynamic> task) {
    final applications = _applicationsByTask[task['id']?.toString()] ?? [];
    return applications.length > 1;
  }

  /// 判斷是否為已收藏任務
  bool _isFavoritedTask(Map<String, dynamic> task) {
    // TODO: 實現收藏功能後，從收藏服務檢查
    return false;
  }

  /// 獲取任務發布時間的距離描述
  String _getTimeAgo(Map<String, dynamic> task) {
    try {
      final createdAt = DateTime.parse(task['created_at'] ?? DateTime.now().toString());
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
}

// 根據 id 產生一致的顏色
Color _getAvatarColor(String id) {
  const int avtartBgColorLevel = 400;
  // 使用 id 的 hashCode 來產生顏色
  final colors = [
    Colors.deepOrangeAccent[avtartBgColorLevel]!,
    Colors.lightGreen[avtartBgColorLevel]!,
    Colors.blue[avtartBgColorLevel]!,
    Colors.orange[avtartBgColorLevel]!,
    Colors.purple[avtartBgColorLevel]!,
    Colors.teal[avtartBgColorLevel]!,
    Colors.indigo[avtartBgColorLevel]!,
    Colors.brown[avtartBgColorLevel]!,
    Colors.cyan[avtartBgColorLevel]!,
    Colors.orangeAccent[avtartBgColorLevel]!,
    Colors.deepPurple[avtartBgColorLevel]!,
    Colors.lime[avtartBgColorLevel]!,
    Colors.pinkAccent[avtartBgColorLevel]!,
    Colors.amber[avtartBgColorLevel]!,
  ];
  final index = id.hashCode.abs() % colors.length;
  return colors[index];
}

// 取得名字的首個字母
String _getInitials(String name) {
  if (name.isEmpty) return '';
  return name.trim().substring(0, 1).toUpperCase();
}

// 倒數計時器 Widget
class _CountdownTimerWidget extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onCountdownComplete;
  const _CountdownTimerWidget(
      {required this.task, required this.onCountdownComplete});

  @override
  State<_CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<_CountdownTimerWidget> {
  late Duration _remaining;
  late DateTime _endTime;
  late DateTime _startTime;
  bool _completed = false;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = _startTime.add(const Duration(days: 7));
    _remaining = _endTime.difference(DateTime.now());
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    final remain = _endTime.difference(now);
    if (remain <= Duration.zero && !_completed) {
      _completed = true;
      widget.onCountdownComplete();
      _ticker.stop();
      setState(() {
        _remaining = Duration.zero;
      });
    } else if (!_completed) {
      setState(() {
        _remaining = remain > Duration.zero ? remain : Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    int totalSeconds = d.inSeconds;
    int days = totalSeconds ~/ (24 * 3600);
    int hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${days.toString().padLeft(2, '0')}:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 6),
          const Text('Confirm within: ',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              )),
          const SizedBox(width: 6),
          const Icon(Icons.timer, color: Colors.purple, size: 18),
          Text(
            _remaining > Duration.zero
                ? _formatDuration(_remaining)
                : '00:00:00:00',
            style: const TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// 輕量 Ticker，避免引入 flutter/scheduler.dart
typedef TickerCallback = void Function(Duration elapsed);

class Ticker {
  final TickerCallback onTick;
  late DateTime _start;
  bool _active = false;
  Duration _elapsed = Duration.zero;
  Ticker(this.onTick);
  void start() {
    _start = DateTime.now();
    _active = true;
    _tick();
  }

  void _tick() async {
    while (_active) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_active) break;
      _elapsed = DateTime.now().difference(_start);
      onTick(_elapsed);
    }
  }

  void stop() {
    _active = false;
  }

  void dispose() {
    stop();
  }
  // 根據 task 狀態和 applierChatItem 動態產生 endActionPane 的按鈕
}

extension _ChatListPageStateApplierEndActions on _ChatListPageState {
  // 根據 task 狀態和 applierChatItem 動態產生 endActionPane 的按鈕
  List<Widget> _buildApplierEndActions(BuildContext context,
      Map<String, dynamic> task, Map<String, dynamic> applierChatItem) {
    // Convert database status to display status for comparison
    final displayStatus =
        TaskStatus.statusString[task['status']] ?? task['status'];
    List<Widget> actions = [];

    void addButton(String label, Color color, VoidCallback onTap,
        {IconData? icon}) {
      actions.add(
        Flexible(
          child: GestureDetector(
            onTap: () {
              onTap();
              Slidable.of(context)?.close();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: Colors.black),
                    const SizedBox(height: 4),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (displayStatus == 'Open') {
      // 檢查是否為真實應徵者（有 application_id）
      final isRealApplication = applierChatItem['application_id'] != null;
      final applicationStatus = applierChatItem['application_status'];

      if (isRealApplication && applicationStatus == 'applied') {
        // 真實應徵者：顯示 Approve/Reject 按鈕
        addButton('Approve', Colors.green[200]!, () async {
          await _approveApplication(task, applierChatItem);
        }, icon: Icons.check);

        addButton('Reject', Colors.red[200]!, () async {
          await _rejectApplication(task, applierChatItem);
        }, icon: Icons.close);
      } else {
        // Demo 資料或其他狀態：顯示原本按鈕
        addButton('Read', Colors.blue[100]!, () {
          _notificationService.markRoomRead(
            roomId: applierChatItem['id'],
            upToMessageId: 'latest',
          );
        });
        addButton('Hide', Colors.orange[100]!, () {
          applierChatItem['isHidden'] = true;
        });
        addButton('Delete', Colors.red[100]!, () async {
          final confirm = await _showDoubleConfirmDialog(
              'Delete applierChatItem',
              'Are you sure you want to delete this applierChatItem?');
          if (confirm == true) {
            applierChatItem['isHidden'] = true;
          }
        });
      }
    } else if (displayStatus == 'In Progress' ||
        displayStatus == 'Dispute' ||
        displayStatus == 'Completed') {
      addButton('Read', Colors.blue[100]!, () {
        _notificationService.markRoomRead(
          roomId: applierChatItem['id'],
          upToMessageId: 'latest',
        );
      });
    } else if (displayStatus == 'Pending Confirmation') {
      addButton('Confirm', Colors.green[100]!, () {
        TaskService().updateTaskStatus(
          task['id'],
          'completed',
          statusCode: 'completed',
        ); // Use database status
        task['status'] = 'completed'; // Use database status
      });
    }

    return actions;
  }

  /// Posted Tasks 分頁的任務卡片（使用 My Works 風格 + 手風琴功能）
  Widget _buildPostedTasksCardWithAccordion(
      Map<String, dynamic> task, List<Map<String, dynamic>> applierChatItems) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;
    final taskId = task['id'].toString();
    final isExpanded = _expandedTaskIds.contains(taskId);

    // 過濾可見的應徵者
    final visibleAppliers =
        applierChatItems.where((ap) => ap['isHidden'] != true).toList();
    final unreadCount = _unreadByTask[task['id']] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        // 如果當前已展開，則收合
                        _expandedTaskIds.remove(taskId);
                      } else {
                        // 如果當前未展開，則收合所有其他卡片，只展開當前卡片
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
                                    // 新任務圖標（發布未滿一週）
                                    if (_isNewTask(task)) 
                                      const Text('🌱', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    // 熱門圖標（超過一位應徵者）
                                    if (_isPopularTask(task)) 
                                      const Text('🔥', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                    // 收藏圖標（當前使用者已收藏）
                                    if (_isFavoritedTask(task)) 
                                      const Text('❤️', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // 任務狀態和發布者
                            Row(
                              children: [
                                // 狀態標籤
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
                                const SizedBox(width: 8),
                                // 發布者名稱（主題配色）
                                Flexible(
                                  child: Text(
                                    'by ${task['creator_name'] ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.secondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            
                            // 任務資訊 2x2 格局
                            Container(
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
                                            Icon(Icons.attach_money,
                                                size: 12,
                                                color: Colors.grey[600]),
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
                                            Icon(Icons.location_on,
                                                size: 12,
                                                color: Colors.grey[500]),
                                            const SizedBox(width: 2),
                                            Flexible(
                                              child: Text(
                                                task['location'] ??
                                                    'Unknown Location',
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
                                                size: 12,
                                                color: Colors.grey[500]),
                                            const SizedBox(width: 2),
                                            Text(
                                              DateFormat('MM/dd').format(
                                                DateTime.parse(
                                                    task['task_date'] ??
                                                        DateTime.now()
                                                            .toString()),
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.primary,
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
                                                    'No Requirement',
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 右側：應徵者數量和箭頭（視覺指示）
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
                          // 只在有應徵者時顯示數量
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
                          // 手風琴箭頭圖標（會旋轉）
                          AnimatedRotation(
                            turns: isExpanded ? 0.25 : 0.0, // 向下或向右
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

              // 手風琴展開內容：應徵者卡片
              if (isExpanded) ...[
                // Action Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                label: Text(
                                  'Info',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                  ),
                                ),
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
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Edit feature coming soon')),
                                  );
                                },
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                label: Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colorScheme.primary),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Favorite 按鈕
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // TODO: 實現收藏功能
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Favorite feature coming soon')),
                                  );
                                },
                                icon: Icon(
                                  Icons.favorite_border,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                label: Text(
                                  'Favorite',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: colorScheme.primary),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Delete 按鈕
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: Text(
                                          'Are you sure you want to delete task "${task['title']}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Delete feature coming soon')),
                                            );
                                          },
                                          child: const Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                label: Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          // 非 Open 狀態時，只顯示居中的 Info 按鈕
                          child: SizedBox(
                            width: 120,
                            child: OutlinedButton.icon(
                              onPressed: () => _showTaskInfoDialog(task),
                              icon: Icon(Icons.info_outline,
                                  size: 16, color: colorScheme.primary),
                              label: Text(
                                'Info',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colorScheme.primary),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                            ),
                          ),
                        ),
                      ),

                // 應徵者卡片列表
                if (visibleAppliers.isNotEmpty)
                  ...visibleAppliers.map((applier) => Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side:
                                BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: _getAvatarColor(applier['name']),
                              child: Text(
                                _getInitials(applier['name']),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                            title: Text(
                              applier['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              applier['sentMessages']?[0] ?? 'No messages',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
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
                                    Icon(Icons.star,
                                        color: Colors.amber[600], size: 14),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${applier['rating'] ?? 0.0}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                Text(
                                  '(${applier['reviewsCount'] ?? 0})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              // TODO: Navigate to chat room
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Chat with ${applier['name']}')),
                              );
                            },
                          ),
                        ),
                      ))
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No applicants',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),

          // 倒數計時懸浮在右上角
          if (_isCountdownStatus(displayStatus))
            Positioned(
              top: -8,
              right: -8,
              child: _buildCompactCountdownTimer(task),
            ),
        ],
      ),
    );
  }

  /// My Works 分頁的聊天室列表項目
  Widget _buildMyWorksChatRoomItem(
      Map<String, dynamic> task, List<Map<String, dynamic>> applierChatItems) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;

    // 計算未讀訊息數量
    final unreadCount = applierChatItems.isNotEmpty
        ? (_unreadByRoom[applierChatItems.first['id']] ?? 0)
        : 0;

    // 房間 ID 在下方使用時以就地變數處理

    // 確定當前用戶在聊天室中的角色
    final currentUserId = context.read<UserService>().currentUser?.id;
    final isCreator =
        task['creator_id']?.toString() == currentUserId?.toString();
    final userRole = isCreator ? 'creator' : 'participant';

    // 獲取聊天對象信息
    final room = applierChatItems.isNotEmpty ? applierChatItems.first : null;
    final chatPartnerInfo = _getChatPartnerInfo(task, userRole, room);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: () async {
              if (applierChatItems.isNotEmpty) {
                final room = applierChatItems.first;
                final roomId = room['id']?.toString() ?? 'unknown';
                // 儲存持久化資料並設置當前會話（My Works）
                await ChatStorageService.savechatRoomData(
                  roomId: roomId,
                  room: room,
                  task: task,
                  userRole: userRole,
                  chatPartnerInfo: chatPartnerInfo,
                );
                await ChatSessionManager.setCurrentChatSession(
                  roomId: roomId,
                  room: room,
                  task: task,
                  userRole: userRole,
                  chatPartnerInfo: chatPartnerInfo,
                  sourceTab: 'my-works', // 記錄來源分頁
                );
                // 使用帶參數 URL，避免 appBarBuilder 拿不到 extra
                final chatUrl = ChatStorageService.generateChatUrl(
                  roomId: roomId,
                  taskId: task['id']?.toString(),
                );
                final extraData = {
                  'room': room,
                  'task': task,
                  'userRole': userRole,
                  'chatPartnerInfo': chatPartnerInfo,
                };

                debugPrint('🔍 [My Works] 準備導航到聊天室');
                debugPrint('🔍 [My Works] chatUrl: $chatUrl');
                debugPrint('🔍 [My Works] extra data: $extraData');

                context.go(chatUrl, extra: extraData);
              } else {
                // 沒有現成房間資料：回退為 ensure_room 建立/取得真實 BIGINT room_id 後導頁
                try {
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

                  final fallbackRoomPayload = {
                    'id': roomData['id'],
                    'roomId': realRoomId,
                    'taskId': taskId,
                    'task_id': taskId,
                    'creator_id': creatorId,
                    'participant_id': participantId,
                  };

                  await ChatStorageService.savechatRoomData(
                    roomId: realRoomId,
                    room: fallbackRoomPayload,
                    task: task,
                    userRole: userRole,
                    chatPartnerInfo: chatPartnerInfo,
                  );
                  await ChatSessionManager.setCurrentChatSession(
                    roomId: realRoomId,
                    room: fallbackRoomPayload,
                    task: task,
                    userRole: userRole,
                    chatPartnerInfo: chatPartnerInfo,
                    sourceTab: 'my-works',
                  );

                  final chatUrl = ChatStorageService.generateChatUrl(
                    roomId: realRoomId,
                    taskId: taskId,
                  );

                  final extraData = {
                    'room': fallbackRoomPayload,
                    'task': task,
                    'userRole': userRole,
                    'chatPartnerInfo': chatPartnerInfo,
                  };

                  debugPrint('🔁 [My Works] ensure_room 後導航到聊天室');
                  debugPrint('🔁 [My Works] chatUrl: $chatUrl');
                  context.go(chatUrl, extra: extraData);
                } catch (e) {
                  debugPrint('❌ [My Works] ensure_room 失敗: $e');
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
                                // 新任務圖標（發布未滿一週）
                                if (_isNewTask(task)) 
                                  const Text('🌱', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                // 熱門圖標（超過一位應徵者）
                                if (_isPopularTask(task)) 
                                  const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                // 收藏圖標（當前使用者已收藏）
                                if (_isFavoritedTask(task)) 
                                  const Text('❤️', style: TextStyle(fontSize: 16)),
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
                            color: baseColor.withOpacity(0.1),
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

                        // 任務資訊 2x2 格局：位置、日期、獎勵、語言
                        Container(
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
                                            task['location'] ?? '未知地點',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
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
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
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
                                            task['language_requirement'] ?? '不限',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
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
                        const SizedBox(height: 4),
                        // 時間距離戳記
                        Text(
                          _getTimeAgo(task),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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
          if (_isCountdownStatus(displayStatus))
            Positioned(
              top: -8,
              right: -8,
              child: _buildCompactCountdownTimer(task),
            ),
        ],
      ),
    );
  }

  /// 獲取聊天對象信息
  Map<String, dynamic> _getChatPartnerInfo(
      Map<String, dynamic> task, String userRole,
      [Map<String, dynamic>? room]) {
    final currentUserId = context.read<UserService>().currentUser?.id;

    debugPrint(
        '🔍 _getChatPartnerInfo - userRole: $userRole, currentUserId: $currentUserId');
    debugPrint('🔍 _getChatPartnerInfo - task keys: ${task.keys}');
    debugPrint('🔍 _getChatPartnerInfo - room keys: ${room?.keys}');

    if (userRole == 'creator') {
      // 當前用戶是創建者，聊天對象是參與者
      if (room != null && room.isNotEmpty) {
        final dynamic id = room['user_id'] ?? room['participant_id'];
        final String name =
            room['name'] ?? room['participant_name'] ?? 'Applicant';
        // 不使用預設圖，改用首字母圓形頭像
        String? avatar;
        final List<dynamic> avatarCandidates = [
          room['participant_avatar_url'], // 從 ensure_room 返回
          room['participant_avatar'], // 從 ensure_room 返回
          (room['other_user'] is Map)
              ? (room['other_user'] as Map)['avatar']
              : null, // 從 get_rooms 返回
          room['avatar'], // 通用字段
          task['participant_avatar_url'], // 任務數據
          task['participant_avatar'], // 任務數據
          task['acceptor_avatar_url'], // 接受者數據
          task['acceptor_avatar'], // 接受者數據
        ];
        for (final c in avatarCandidates) {
          if (c != null && c.toString().isNotEmpty) {
            avatar = c.toString();
            break;
          }
        }

        return {
          'id': id?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      } else {
        // 沒有聊天室，從任務數據推導
        final String name = task['participant_name'] ?? 'Applicant';
        String? avatar = task['participant_avatar_url'] ??
            task['participant_avatar'] ??
            task['acceptor_avatar_url'] ??
            task['acceptor_avatar'];

        return {
          'id': task['participant_id']?.toString() ??
              task['acceptor_id']?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      }
    } else {
      // 當前用戶是參與者，聊天對象是創建者
      if (room != null && room.isNotEmpty) {
        final dynamic id = room['creator_id'];
        final String name = room['creator_name'] ?? 'Task Creator';
        String? avatar = room['creator_avatar_url'] ?? room['creator_avatar'];

        return {
          'id': id?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      } else {
        // 沒有聊天室，從任務數據推導
        final String name = task['creator_name'] ?? 'Task Creator';
        String? avatar = task['creator_avatar_url'] ?? task['creator_avatar'];

        return {
          'id': task['creator_id']?.toString(),
          'name': name,
          'avatar': avatar ?? '',
        };
      }
    }
  }

  /// 判斷是否為新任務（發布未滿一週）
  bool _isNewTask(Map<String, dynamic> task) {
    try {
      final createdAt = DateTime.parse(task['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(createdAt);
      return difference.inDays < 7;
    } catch (e) {
      return false;
    }
  }

  /// 判斷是否為熱門任務（超過一位應徵者）
  bool _isPopularTask(Map<String, dynamic> task) {
    final applications = _applicationsByTask[task['id']?.toString()] ?? [];
    return applications.length > 1;
  }

  /// 判斷是否為已收藏任務
  bool _isFavoritedTask(Map<String, dynamic> task) {
    // TODO: 實現收藏功能後，從收藏服務檢查
    return false;
  }

  /// 獲取任務發布時間的距離描述
  String _getTimeAgo(Map<String, dynamic> task) {
    try {
      final createdAt = DateTime.parse(task['created_at'] ?? DateTime.now().toString());
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
}

/// 緊湊倒數計時器 Widget（用於 My Works 分頁）
class _CompactCountdownTimerWidget extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onCountdownComplete;
  const _CompactCountdownTimerWidget(
      {required this.task, required this.onCountdownComplete});

  @override
  State<_CompactCountdownTimerWidget> createState() =>
      _CompactCountdownTimerWidgetState();
}

class _CompactCountdownTimerWidgetState
    extends State<_CompactCountdownTimerWidget> {
  late Duration _remaining;
  late DateTime _endTime;
  late DateTime _startTime;
  bool _completed = false;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = _startTime.add(const Duration(days: 7));
    _remaining = _endTime.difference(DateTime.now());
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    final remain = _endTime.difference(now);
    if (remain <= Duration.zero && !_completed) {
      _completed = true;
      widget.onCountdownComplete();
      _ticker.stop();
      setState(() {
        _remaining = Duration.zero;
      });
    } else if (!_completed) {
      setState(() {
        _remaining = remain > Duration.zero ? remain : Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _formatCompactDuration(Duration d) {
    int totalSeconds = d.inSeconds;
    int days = totalSeconds ~/ (24 * 3600);
    int hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Colors.purple[600], size: 12),
          const SizedBox(width: 4),
          Text(
            _remaining > Duration.zero
                ? _formatCompactDuration(_remaining)
                : '00d 00:00:00',
            style: TextStyle(
              color: Colors.purple[600],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// 中空圓餅圖繪製器
class PieChartPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final double strokeWidth;

  PieChartPainter({
    required this.progress,
    required this.baseColor,
    this.strokeWidth = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 繪製背景圓圈（淺色）
    final backgroundPaint = Paint()
      ..color = baseColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 繪製進度圓弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // 從頂部開始
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

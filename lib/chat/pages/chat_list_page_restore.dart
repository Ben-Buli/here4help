// home_page.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:here4help/chat/models/chat_room_model.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:here4help/constants/task_status.dart';
import 'package:here4help/services/notification_service.dart';
// import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key, this.initialTab = 0});

  final int initialTab; // 初始分頁：0 = Posted Tasks, 1 = My Works

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with TickerProviderStateMixin {
  late Future<void> _taskFuture;
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

  // 未讀通知占位（任務 26 會替換成實作）
  NotificationService _notificationService = NotificationServicePlaceholder();
  Map<String, int> _unreadByTask = const {};
  Map<String, int> _unreadByRoom = const {};
  int _totalUnread = 0;
  StreamSubscription<int>? _totalSub;
  StreamSubscription<Map<String, int>>? _taskSub;
  StreamSubscription<Map<String, int>>? _roomSub;

  // Posted Tasks 應徵者資料快取
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // 手風琴功能
  String? _expandedTaskId;
  late AnimationController _expansionAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 聊天服務
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoadingRooms = false;

  @override
  void initState() {
    super.initState();
    taskerFilterEnabled = widget.initialTab == 1; // 初始化篩選狀態
    _taskFuture = Future.wait([
      TaskService().loadTasks(),
      TaskService().loadStatuses(),
      _loadApplicationsForPostedTasks(),
      _loadChatRooms(),
    ]);
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

    // 初始化手風琴動畫控制器
    _expansionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _expansionAnimationController, curve: Curves.easeInOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _expansionAnimationController,
                curve: Curves.easeInOut));
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
      }
    });

    // 初始化未讀服務：登入後切換為 Socket 實作
    _initUnreadService();
    final center = NotificationCenter();
    _totalSub = center.totalUnreadStream.listen((v) {
      if (!mounted) return;
      setState(() => _totalUnread = v);
    });
    _taskSub = center.byTaskStream.listen((m) {
      if (!mounted) return;
      setState(() => _unreadByTask = m);
    });
    _roomSub = center.byRoomStream.listen((m) {
      if (!mounted) return;
      setState(() => _unreadByRoom = m);
    });
  }

  int _countUnreadForTab(bool forMyWorks) {
    // 將 byRoom 的未讀統計映射到任務/房屬性
    // 資料模型中房 id 存在 applierChatItem['id'] 或 room['roomId']，此處用 _unreadByRoom 的 key 為 roomId
    // 我們粗略地依「是否屬於我的作品」來分流：
    // - Posted: 我是 creator（在 _composeMyWorks 外的列表）
    // - My Works: 我是 acceptor 或有應徵紀錄（_composeMyWorks 製作的列表）
    // 這裡用當前 UI 的已分流資料來源來估算，避免重查 API
    try {
      final service = TaskService();
      final userId =
          Provider.of<UserService>(context, listen: false).currentUser?.id;
      if (userId == null) return 0;
      isMyWorkTask(Map<String, dynamic> t) {
        final acceptorIsMe =
            (t['acceptor_id']?.toString() ?? '') == userId.toString();
        final appliedByMe = t['applied_by_me'] == true;
        return acceptorIsMe || appliedByMe;
      }

      final tasksAll = List<Map<String, dynamic>>.from(service.tasks);
      final myWorks = tasksAll
          .where(isMyWorkTask)
          .map((t) => (t['id'] ?? '').toString())
          .toSet();
      int sum = 0;
      _unreadByRoom.forEach((roomId, cnt) {
        // 從 roomId 解析 taskId（若符合我們的命名規格）
        // pattern: task_{taskId}_pair_
        String? taskId;
        final m = RegExp(r'^task_(.+?)_pair_').firstMatch(roomId);
        if (m != null) taskId = m.group(1);
        if (taskId == null || taskId.isEmpty) return;
        final inMyWorks = myWorks.contains(taskId);
        if (forMyWorks == inMyWorks) {
          sum += cnt;
        }
      });
      return sum;
    } catch (_) {
      return 0;
    }
  }

  String? _computeRoomIdForApplier(
      Map<String, dynamic> task, Map<String, dynamic> applier) {
    final taskId = (task['id'] ?? '').toString();
    final creatorId = (task['creator_id'] ?? '').toString();
    final applierId = (applier['user_id'] ?? '').toString();
    if (taskId.isEmpty || creatorId.isEmpty || applierId.isEmpty) return null;
    return 'task_${taskId}_pair_${creatorId}_$applierId';
  }

  Future<void> _initUnreadService() async {
    try {
      final token = await AuthService.getToken();
      final user = Provider.of<UserService>(context, listen: false).currentUser;
      if (token != null && user != null) {
        _notificationService = SocketNotificationService();
        await _notificationService.init(userId: user.id.toString());
        await NotificationCenter().use(_notificationService);
        await _notificationService.refreshSnapshot();
      } else {
        await _notificationService.init(userId: 'placeholder');
        await NotificationCenter().use(_notificationService);
      }
    } catch (_) {
      await _notificationService.init(userId: 'placeholder');
      await NotificationCenter().use(_notificationService);
    }
  }

  /// 載入聊天房間列表
  Future<void> _loadChatRooms() async {
    if (_isLoadingRooms) return;

    setState(() {
      _isLoadingRooms = true;
    });

    try {
      final result = await _chatService.getChatRooms();
      if (mounted) {
        setState(() {
          _chatRooms = List<Map<String, dynamic>>.from(result['rooms'] ?? []);
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
        });
      }
      print('載入聊天房間失敗: $e');
    }
  }

  // 整理 My Works 清單：我作為應徵者申請的任務
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

    // My Works 準則：我應徵過的任務（作為應徵者）
    return allTasks.where((t) {
      final appliedByMe = t['applied_by_me'] == true;
      return appliedByMe;
    }).toList();
  }

  // 整理 Posted Tasks 清單：我作為發布者發布的任務
  List<Map<String, dynamic>> _composePostedTasks(
      TaskService service, int? currentUserId) {
    final allTasks = List<Map<String, dynamic>>.from(service.tasks);

    // Posted Tasks 準則：我創建的任務（作為發布者）
    return allTasks.where((t) {
      final creatorIsMe = (t['creator_id']?.toString() ?? '') ==
          (currentUserId?.toString() ?? '');
      return creatorIsMe;
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expansionAnimationController.dispose(); // 新增：清理動畫控制器
    _searchController.dispose();
    _searchFocusNode.dispose();
    _totalSub?.cancel();
    _taskSub?.cancel();
    _roomSub?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  /// 手風琴展開/收合邏輯
  void _toggleTaskExpansion(String taskId) {
    setState(() {
      if (_expandedTaskId == taskId) {
        // 收合當前任務
        _expandedTaskId = null;
        _expansionAnimationController.reverse();
      } else {
        // 展開新任務，同時收合其他任務
        _expandedTaskId = taskId;
        _expansionAnimationController.forward();
      }
    });
  }

  /// 創建滑動動畫
  Animation<Offset> _createSlideAnimation() {
    return _slideAnimation;
  }

  /// 創建淡入動畫
  Animation<double> _createFadeAnimation() {
    return _fadeAnimation;
  }

  /// 獲取時間距離戳記 (1 day ago, 1 hour ago)
  String _getTimeAgo(String? createdAtString) {
    if (createdAtString == null || createdAtString.isEmpty) return '';

    try {
      final createdAt = DateTime.parse(createdAtString);
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      if (difference.inDays > 365) {
        return DateFormat('yyyy-MM-dd').format(createdAt);
      } else if (difference.inDays > 30) {
        return DateFormat('MM-dd').format(createdAt);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
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

  /// Returns the text color for status chip.
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

  /// 修改卡片內容，添加進度條（點擊卡片顯示懸浮視窗）
  Widget _taskCardWithProgressBar(Map<String, dynamic> task) {
    final String displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'];
    final color = progressData['color'];

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
                  Text(
                    task['title'] ?? 'N/A',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: null,
                    softWrap: true,
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
                  // 檢查是否為 Posted Tasks 且沒有應徵者
                  if (_tabController.index == 0 &&
                      _displayStatus(task) == 'Open' &&
                      visibleapplierChatItems.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No applications received yet',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                              onTap: () {
                                final data = {
                                  'room': {
                                    ...applierChatItem,
                                    'roomId': _computeRoomIdForApplier(
                                            task, applierChatItem) ??
                                        applierChatItem['id'],
                                    'taskId': task['id'],
                                  },
                                  'task': task,
                                };
                                context.push('/chat/detail', extra: data);
                              },
                            ),
                          ),
                          if (() {
                            final roomId = _computeRoomIdForApplier(
                                    task, applierChatItem) ??
                                applierChatItem['id'];
                            return (_unreadByRoom[roomId] ?? 0) > 0;
                          }())
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
                                  '${_unreadByRoom[_computeRoomIdForApplier(task, applierChatItem) ?? applierChatItem['id']] ?? 0}',
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

  /// 計算對比色，確保文字在背景上清晰可見
  Color _getContrastColor(Color backgroundColor) {
    // 計算亮度
    final luminance = backgroundColor.computeLuminance();
    // 如果背景較亮，使用深色文字；如果背景較暗，使用淺色文字
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  Widget _buildPostedTasksChatList() {
    final statusOrder = {
      'Open': 0,
      'In Progress': 1,
      'Pending Confirmation': 2,
      'Dispute': 3,
      'Completed': 4,
    };

    return FutureBuilder(
      future: _taskFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          final taskService = TaskService();
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
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: _TabWithBadge(
                        label: 'Posted Tasks',
                        count: _countUnreadForTab(false),
                      ),
                    ),
                    Tab(
                      child: _TabWithBadge(
                        label: 'My Works',
                        count: _countUnreadForTab(true),
                      ),
                    ),
                  ],
                ),
                // Removed or reduced vertical space above TabBar
                // const SizedBox(height: 8                ),
                // 只在 Posted Tasks 分頁顯示搜尋和篩選
                if (_tabController.index == 0) ...[
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Search bar
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
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedLocation,
                            hint: const Text('Location'),
                            underline: Container(height: 1, color: Colors.grey),
                            items: locationOptions.map((loc) {
                              return DropdownMenuItem(
                                  value: loc, child: Text(loc));
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedLocation = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Hashtag dropdown commented
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedStatus,
                            hint: const Text('Status'),
                            underline: Container(height: 1, color: Colors.grey),
                            items: statusOptions
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
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
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          tooltip: 'Reset Filters',
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              searchQuery = '';
                              selectedLocation = null;
                              selectedHashtag = null;
                              selectedStatus = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTaskList(false), // Posted Tasks
                      _buildMyWorksChatList(), // My Works - 聊天室列表
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildMyWorksChatList() {
    final taskService = TaskService();
    final currentUserId = context.read<UserService>().currentUser?.id;
    if (currentUserId != null) {
      // 確保載入我的應徵
      taskService.loadMyApplications(currentUserId);
    }

    final tasks = _composeMyWorks(taskService, currentUserId);

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '尚無聊天室',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '應徵任務後即可開始聊天',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final taskId = task['id'].toString();
        final creatorId = task['creator_id']?.toString() ?? '';
        final currentUserId =
            context.read<UserService>().currentUser?.id.toString() ?? '';

        // 計算聊天室 ID
        final roomId = 'task_${taskId}_pair_${creatorId}_$currentUserId';

        return _buildMyWorksChatRoomItem(task, roomId);
      },
    );
  }

  Widget _buildMyWorksChatRoomItem(Map<String, dynamic> task, String roomId) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;

    // 計算未讀訊息數量
    final unreadCount = _unreadByRoom[roomId] ?? 0;

    // 計算進度條顏色（水壺裝水效果）
    final progressColor = Color.lerp(
      baseColor.withOpacity(0.1), // 0% 時的淺色
      baseColor, // 100% 時的深色
      progress,
    )!;

    // 計算文字顏色（對比色）
    final textColor = _getContrastColor(progressColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: () {
          // 直接導航到聊天室
          context.push('/chat/detail', extra: {
            'room': {
              'roomId': roomId,
              'taskId': task['id'],
              'creatorId': task['creator_id'],
              'participantId': context.read<UserService>().currentUser?.id,
            },
            'task': task,
            'otherUser': {
              'id': task['creator_id'],
              'name': task['creator_name'] ?? '任務發布者',
              'avatar':
                  task['creator_avatar'] ?? 'assets/images/avatar/avatar-1.png',
            },
          });
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
                    Text(
                      task['title'] ?? '未命名任務',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 任務狀態和獎勵
                    Row(
                      children: [
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
                        const SizedBox(width: 8),
                        Icon(Icons.attach_money,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 2),
                        Text(
                          '${task['reward_point'] ?? task['salary'] ?? 0}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 四個任務資訊欄位：位置、日期、發布者、語言要求
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            task['location'] ?? '未知地點',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          DateFormat('MM/dd').format(
                            DateTime.parse(
                                task['task_date'] ?? DateTime.now().toString()),
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // 發布者和語言要求
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            task['creator_name'] ?? '未知發布者',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.language, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text(
                          task['language_requirement'] ?? '不限',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),

                    // 倒數計時（如果是 Pending Confirmation 狀態）
                    if (_isCountdownStatus(displayStatus)) ...[
                      const SizedBox(height: 4),
                      _buildCountdownTimer(task),
                    ],
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
    );
  }

  Widget _buildTaskList(bool taskerEnabled) {
    final taskService = TaskService();
    final currentUserId = context.read<UserService>().currentUser?.id;
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
        : _composePostedTasks(taskService, currentUserId);
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
      final hashtags = (task['hashtags'] as List<dynamic>? ?? [])
          .map((h) => h.toString())
          .toList();
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
      // 篩選邏輯已經在 _composeMyWorks 和 _composePostedTasks 中處理
      const matchTasker = true;
      return matchQuery && matchLocation && matchStatus && matchTasker;
    }).toList();
    return SlidableAutoCloseBehavior(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: filteredTasks.map((task) {
          final taskId = task['id'].toString();
          final isPostedTasksTab = _tabController.index == 0;
          final userService = context.read<UserService>();
          final currentUserId = userService.currentUser?.id;

          List<Map<String, dynamic>> applierChatItems;

          if (isPostedTasksTab) {
            // Posted Tasks: 任務發布者視角 - 顯示應徵者
            final applications = _applicationsByTask[taskId] ?? [];
            applierChatItems =
                _convertApplicationsToApplierChatItems(applications);
          } else {
            // My Works: 任務應徵者視角 - 顯示自己的應徵者卡片
            final isMyApplication = task['applied_by_me'] == true;
            if (isMyApplication) {
              // 為自己創建一個應徵者卡片
              applierChatItems = [
                {
                  'id': 'my_application_$taskId',
                  'taskId': taskId,
                  'name': userService.currentUser?.name ?? 'Me',
                  'rating': 4.0,
                  'reviewsCount': 0,
                  'questionReply': 'My application for this task',
                  'sentMessages': ['I applied for this task'],
                  'user_id': currentUserId,
                  'application_status': 'applied',
                  'isMyApplication': true,
                }
              ];
            } else {
              applierChatItems = [];
            }
          }

          return _taskCardWithapplierChatItems(task, applierChatItems);
        }).toList(),
      ),
    );
  }

  /// 載入所有我發布任務的應徵者資料
  Future<void> _loadApplicationsForPostedTasks() async {
    final userService = context.read<UserService>();
    final currentUserId = userService.currentUser?.id;
    if (currentUserId == null) return;

    final taskService = TaskService();
    final myPostedTasks = taskService.tasks.where((task) {
      final creatorId = task['creator_id'];
      return creatorId == currentUserId ||
          creatorId?.toString() == currentUserId.toString();
    }).toList();

    for (final task in myPostedTasks) {
      try {
        final applications =
            await taskService.loadApplicationsByTask(task['id'].toString());
        _applicationsByTask[task['id'].toString()] = applications;
      } catch (e) {
        debugPrint('Failed to load applications for task ${task['id']}: $e');
      }
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
      return {
        'id': 'app_${app['application_id'] ?? app['user_id']}',
        'taskId': app['task_id'],
        'name': app['applier_name'] ?? 'Anonymous',
        'rating': 4.0, // 預設評分，未來可從 API 取得
        'reviewsCount': 0, // 預設評論數，未來可從 API 取得
        'questionReply': app['cover_letter'] ?? '',
        'sentMessages': [app['cover_letter'] ?? 'Applied for this task'],
        'user_id': app['user_id'],
        'application_id': app['application_id'],
        'application_status': app['application_status'] ?? 'applied',
        'answers_json': app['answers_json'],
        'created_at': app['created_at'],
        'isMuted': false,
        'isHidden': false,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyWorksChatList(),
          _buildPostedTasksChatList(),
        ],
      ),
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;
  const _TabWithBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ]
      ],
    );
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
}

/// 中空圓餅圖畫家
class PieChartPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final double strokeWidth;

  const PieChartPainter({
    required this.progress,
    required this.baseColor,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // 背景圓
    final backgroundPaint = Paint()
      ..color = baseColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 進度圓弧
    final progressPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2; // 從12點鐘方向開始
    final sweepAngle = 2 * 3.14159 * progress; // 進度角度

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

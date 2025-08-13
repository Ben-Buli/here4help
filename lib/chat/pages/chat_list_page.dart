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

import 'package:here4help/services/notification_service.dart';
// import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/task_status_service.dart';

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
      print('🔄 開始載入聊天房間...');
      final result = await _chatService.getChatRooms();
      print('✅ 聊天房間載入成功: ${result['rooms']?.length ?? 0} 個房間');
      if (mounted) {
        setState(() {
          _chatRooms = List<Map<String, dynamic>>.from(result['rooms'] ?? []);
          _isLoadingRooms = false;
        });
        print('📋 已更新聊天房間狀態，總計: ${_chatRooms.length} 個房間');
      }
    } catch (e) {
      print('❌ 載入聊天房間失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
          _chatRooms = []; // 確保重置為空列表
        });
      }
    }
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

    // 使用新的TaskStatusService
    final statusService = context.read<TaskStatusService>();
    final dynamic identifier =
        task['status_id'] ?? task['status_code'] ?? task['status'];
    return statusService.getDisplayName(identifier);
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

  bool _isCountdownStatus(String status) {
    // 使用新的TaskStatusService檢查是否為等待確認狀態
    final statusService = context.read<TaskStatusService>();
    final statusModel = statusService.getByCode(status);

    return statusModel?.code == 'pending_confirmation';
  }

  /// 根據狀態返回進度值和顏色
  Map<String, dynamic> _getProgressData(String status) {
    // 使用新的TaskStatusService
    final statusService = context.read<TaskStatusService>();
    final colorScheme = Theme.of(context).colorScheme;

    // 獲取進度比例
    final progress = statusService.getProgressRatio(status);

    // 獲取狀態樣式
    final statusStyle = statusService.getStatusStyle(status, colorScheme);

    return {
      'progress': progress,
      'color': statusStyle.foregroundColor,
    };
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
                              'No applications received yet. Applicants will appear here once they apply for this task.',
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
          // 使用新的TaskStatusService檢查狀態
          final statusService = context.read<TaskStatusService>();
          final currentStatus = task['status'] ?? task['status_code'];
          final statusModel = statusService.getByCode(currentStatus);

          if (statusModel?.code == 'pending_confirmation') {
            task['status'] = 'completed';
            task['status_code'] = 'completed';
          }
        });
      },
    );
  }

  String _getProgressLabel(String status) {
    // 使用新的TaskStatusService獲取顯示名稱
    final statusService = context.read<TaskStatusService>();
    final displayStatus = statusService.getDisplayName(status);

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

  /// 構建 Posted Tasks 的手風琴樣式列表（基於 tasks 表）
  Widget _buildPostedTasksChatList() {
    final statusOrder = {
      'Open': 0,
      'In Progress': 1,
      'Pending Confirmation': 2,
      'Dispute': 3,
      'Completed': 4,
    };

    final currentUserId = context.read<UserService>().currentUser?.id;
    final taskService = TaskService();

    print('🔍 Posted Tasks 檢查: 當前用戶ID = $currentUserId');
    print('📋 TaskService 總任務數: ${taskService.tasks.length}');

    // 確保載入任務數據
    if (currentUserId != null) {
      taskService.loadTasks();
      print('📥 已觸發 loadTasks');
    }

    // 從 tasks 表開始，找出我創建的所有任務
    print('🔍 當前用戶ID類型: ${currentUserId.runtimeType}, 值: $currentUserId');

    final myPostedTasks = taskService.tasks.where((task) {
      final creatorId = task['creator_id']?.toString() ?? '';
      final currentUserIdStr = currentUserId?.toString() ?? '';
      final isMyTask = creatorId == currentUserIdStr;

      print(
          '🔍 檢查任務 ${task['id']}: creator_id="$creatorId" vs current_user="$currentUserIdStr" => $isMyTask');

      if (isMyTask) {
        print('✅ 找到我創建的任務: ${task['id']} - ${task['title']}');
      }
      return isMyTask;
    }).toList();

    print('📊 Posted Tasks 統計: ${myPostedTasks.length} 個我創建的任務');
    print('🔍 TaskService 所有任務: ${taskService.tasks.length} 個');

    if (taskService.tasks.isNotEmpty) {
      print(
          '🔍 前5個任務的創建者: ${taskService.tasks.take(5).map((t) => '${t['id']}: creator=${t['creator_id']}(${t['creator_id'].runtimeType})').join(', ')}');
    }

    // 為每個任務查找對應的應徵者和聊天室資訊
    final tasksWithApplicationInfo = myPostedTasks.map((task) {
      final taskId = task['id']?.toString() ?? '';

      // 查找該任務的聊天室（如果有應徵者）
      final taskRooms = _chatRooms.where((room) {
        return room['task_id']?.toString() == taskId;
      }).toList();

      // 查找該任務的應徵者資訊
      final applications = _applicationsByTask[taskId] ?? [];

      print(
          '💼 任務 $taskId (${task['title']}): ${taskRooms.length} 個聊天室, ${applications.length} 個應徵者');

      // 使用 tasks 表作為主要資料來源
      return {
        // 主要任務資訊（從 tasks 表）
        'id': task['id'],
        'title': task['title'] ?? 'Untitled Task',
        'description': task['description'] ?? '',
        'creator_id': task['creator_id'],
        'creator_name': task['creator_name'] ?? 'Unknown Creator',
        'creator_avatar': task['creator_avatar'],
        'status_id': task['status_id'],
        'status_display': task['status_display'],
        'status_code': task['status_code'],
        'task_date': task['task_date'],
        'created_at': task['created_at'],
        'location': task['location'] ?? 'Unknown',
        'language_requirement': task['language_requirement'] ?? 'Any',
        'reward_point': task['reward_point'] ?? task['salary'] ?? 0,
        // 應徵者和聊天室相關資訊
        'rooms': taskRooms,
        'applications': applications,
        'has_applicants': taskRooms.isNotEmpty || applications.isNotEmpty,
      };
    }).toList();

    // 排序
    tasksWithApplicationInfo.sort((a, b) {
      final displayStatusA = _displayStatus(a);
      final displayStatusB = _displayStatus(b);

      final statusA = statusOrder[displayStatusA] ?? 99;
      final statusB = statusOrder[displayStatusB] ?? 99;
      if (statusA != statusB) {
        return statusA.compareTo(statusB);
      }
      return (DateTime.parse(b['task_date']))
          .compareTo(DateTime.parse(a['task_date']));
    });

    // 篩選邏輯
    print(
        '🔍 篩選條件: searchQuery="$searchQuery", selectedLocation="$selectedLocation", selectedStatus="$selectedStatus"');

    final filteredTasks = tasksWithApplicationInfo.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final location = (task['location'] ?? '').toString();
      final status = _displayStatus(task);
      final description = (task['description'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      final matchQuery = query.isEmpty ||
          title.contains(query) ||
          location.toLowerCase().contains(query) ||
          description.contains(query);
      final matchLocation =
          selectedLocation == null || selectedLocation == location;
      final matchStatus = selectedStatus == null || selectedStatus == status;

      final shouldInclude = matchQuery && matchLocation && matchStatus;

      if (!shouldInclude) {
        print(
            '❌ 任務 ${task['id']} 被篩選掉: matchQuery=$matchQuery, matchLocation=$matchLocation, matchStatus=$matchStatus');
      }

      return shouldInclude;
    }).toList();

    print('📊 篩選後任務數: ${filteredTasks.length}');

    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '尚無已發布的任務',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊 + 按鈕開始發布你的第一個任務',
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
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildCompactTaskCard(task);
      },
    );
  }

  /// 構建 My Works 的手風琴樣式列表（基於應徵記錄 + 聊天室）
  Widget _buildMyWorksChatList() {
    final statusOrder = {
      'Open': 0,
      'In Progress': 1,
      'Pending Confirmation': 2,
      'Dispute': 3,
      'Completed': 4,
    };

    final currentUserId = context.read<UserService>().currentUser?.id;
    final taskService = TaskService();

    print('🔍 My Works 檢查: 當前用戶ID = $currentUserId');

    // 確保載入我的應徵記錄
    if (currentUserId != null) {
      taskService.loadMyApplications(currentUserId);
      print('📥 已觸發 loadMyApplications');
    }

    // 從應徵記錄開始，找出我應徵過的所有任務
    final myApplications = taskService.myApplications;

    // 調試：檢查應徵記錄的結構
    if (myApplications.isNotEmpty) {
      print('🔍 第一個應徵記錄的鍵: ${myApplications.first.keys.toList()}');
      print('🔍 第一個應徵記錄內容: ${myApplications.first}');
    }

    // 嘗試不同的鍵名來獲取 task_id
    final myAppliedTaskIds = myApplications
        .map((app) {
          final taskId = app['task_id']?.toString() ??
              app['id']?.toString() ??
              app['taskId']?.toString() ??
              '';
          if (taskId.isNotEmpty) {
            final sourceKey = app.keys.firstWhere(
                (k) => app[k]?.toString() == taskId,
                orElse: () => 'unknown');
            print('✅ 找到任務ID: $taskId (來源欄位: $sourceKey)');
          } else {
            print('❌ 無法從應徵記錄取得任務ID，可用欄位: ${app.keys.toList()}');
          }
          return taskId;
        })
        .where((id) => id.isNotEmpty)
        .toSet();

    print(
        '📊 My Works - 應徵記錄: ${myApplications.length} 個應徵，任務 IDs: ${myAppliedTaskIds.join(', ')}');

    // 從 chat_rooms 找出我作為 participant 的聊天室
    final myParticipantRooms = _chatRooms.where((room) {
      final participantId = room['participant_id']?.toString() ?? '';
      return participantId == currentUserId?.toString();
    }).toList();

    print('📊 My Works - 聊天室: ${myParticipantRooms.length} 個我參與的聊天室');

    // 如果應徵記錄沒有任務ID，嘗試從聊天室獲取
    if (myAppliedTaskIds.isEmpty && myParticipantRooms.isNotEmpty) {
      print('⚠️ 應徵記錄沒有任務ID，嘗試從聊天室獲取');
      final roomTaskIds = myParticipantRooms
          .map((room) => room['task_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      myAppliedTaskIds.addAll(roomTaskIds);
      print('📋 從聊天室獲得任務IDs: ${roomTaskIds.join(', ')}');
    }

    // 基於應徵記錄構建任務列表
    final tasksWithWorkInfo = <Map<String, dynamic>>[];

    // 為每個我應徵過的任務構建資訊
    for (final taskId in myAppliedTaskIds) {
      if (taskId.isEmpty) continue;

      // 查找對應的任務詳細資訊
      final detailedTask = taskService.tasks.firstWhere(
        (task) => task['id']?.toString() == taskId,
        orElse: () => <String, dynamic>{},
      );

      // 查找我的應徵資訊
      final myApplication = myApplications.firstWhere(
        (app) => app['task_id']?.toString() == taskId,
        orElse: () => <String, dynamic>{},
      );

      // 查找對應的聊天室
      final correspondingRoom = myParticipantRooms.firstWhere(
        (room) => room['task_id']?.toString() == taskId,
        orElse: () => <String, dynamic>{},
      );

      print(
          '💼 任務 $taskId (${detailedTask['title'] ?? myApplication['task_title'] ?? 'Unknown'}): 應徵狀態 ${myApplication['client_status_display'] ?? 'Unknown'}, 聊天室 ${correspondingRoom['room_id'] ?? 'None'}');

      // 使用 tasks 表作為主要資料來源，但優先使用應徵者的狀態
      tasksWithWorkInfo.add({
        // 主要任務資訊（從 tasks 表）
        'id': detailedTask['id'] ?? taskId,
        'title': detailedTask['title'] ??
            myApplication['task_title'] ??
            correspondingRoom['task_title'] ??
            'Untitled Task',
        'description': detailedTask['description'] ??
            myApplication['task_description'] ??
            correspondingRoom['task_description'] ??
            '',
        'creator_id': detailedTask['creator_id'] ??
            myApplication['creator_id'] ??
            correspondingRoom['creator_id'],
        'creator_name': detailedTask['creator_name'] ??
            myApplication['creator_name'] ??
            correspondingRoom['creator_name'] ??
            'Unknown Creator',
        'creator_avatar': detailedTask['creator_avatar'] ??
            myApplication['creator_avatar'] ??
            correspondingRoom['creator_avatar'],
        'task_date': detailedTask['task_date'] ??
            myApplication['task_date'] ??
            correspondingRoom['room_created_at'],
        'created_at': detailedTask['created_at'] ??
            myApplication['created_at'] ??
            correspondingRoom['room_created_at'],
        'location':
            detailedTask['location'] ?? myApplication['location'] ?? 'Unknown',
        'language_requirement': detailedTask['language_requirement'] ??
            myApplication['language_requirement'] ??
            'Any',
        'reward_point': detailedTask['reward_point'] ??
            detailedTask['salary'] ??
            myApplication['reward_point'] ??
            0,
        // 應徵者視角的狀態（優先使用我的應徵狀態）
        'status_id': myApplication['status_id'] ?? detailedTask['status_id'],
        'status_display': myApplication['client_status_display'] ??
            myApplication['status_display'] ??
            detailedTask['status_display'],
        'status_code': myApplication['client_status_code'] ??
            myApplication['status_code'] ??
            detailedTask['status_code'],
        // 聊天室相關資訊
        'room_id': correspondingRoom['room_id'],
        'last_message': correspondingRoom['last_message'],
        'last_message_time': correspondingRoom['last_message_time'],
        'unread_count': correspondingRoom['unread_count'] ?? 0,
        // 應徵者資訊
        'application': myApplication,
        'applied_by_me': true,
      });
    }

    // 排序
    tasksWithWorkInfo.sort((a, b) {
      final displayStatusA = _displayStatus(a);
      final displayStatusB = _displayStatus(b);

      final statusA = statusOrder[displayStatusA] ?? 99;
      final statusB = statusOrder[displayStatusB] ?? 99;
      if (statusA != statusB) {
        return statusA.compareTo(statusB);
      }
      return (DateTime.parse(
              b['task_date'] ?? DateTime.now().toIso8601String()))
          .compareTo(DateTime.parse(
              a['task_date'] ?? DateTime.now().toIso8601String()));
    });

    print('📊 My Works - 構建任務數: ${tasksWithWorkInfo.length}');

    // 篩選邏輯
    final filteredTasks = tasksWithWorkInfo.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final location = (task['location'] ?? '').toString();
      final status = _displayStatus(task);
      final description = (task['description'] ?? '').toString().toLowerCase();
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

    print('📊 My Works - 篩選後任務數: ${filteredTasks.length}');

    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '尚無應徵的任務',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '應徵任務後即可在這裡查看進度',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // 使用與 Posted Tasks 相同的卡片佈局
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildCompactTaskCard(task);
      },
    );
  }

  Future<void> _confirmAndDeleteTask(Map<String, dynamic> task) async {
    final confirm = await _showDoubleConfirmDialog(
        'Delete Task', 'Are you sure you want to delete this task?');
    if (confirm != true) return;

    // Loading 動畫
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

  /// 檢查是否有活躍的篩選條件
  bool get _hasActiveFilters =>
      (selectedLocation != null && selectedLocation!.isNotEmpty) ||
      (selectedStatus != null && selectedStatus!.isNotEmpty) ||
      (searchQuery.isNotEmpty);

  /// 顯示篩選對話框
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final taskService = TaskService();
            final tasks = taskService.tasks;

            // 獲取篩選選項
            final locationOptions = tasks
                .map((e) => (e['location'] ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            final statusOptions = taskService.statuses
                .map((e) => (e['display_name'] ?? '').toString())
                .where((e) => e.isNotEmpty)
                .toList();

            return AlertDialog(
              title: const Text('Filter Options'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Location filter
                    DropdownButtonFormField<String>(
                      value: selectedLocation,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All Locations')),
                        ...locationOptions.map((loc) => DropdownMenuItem(
                              value: loc,
                              child: Text(loc),
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLocation = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Status filter
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All Statuses')),
                        ...statusOptions.map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      // 篩選狀態已經在對話框中更新
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _taskFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('載入任務和聊天室資料...'),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          print('❌ FutureBuilder 錯誤: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('載入失敗: ${snapshot.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _taskFuture = Future.wait([
                          TaskService().loadTasks(),
                          TaskService().loadStatuses(),
                          _loadApplicationsForPostedTasks(),
                          _loadChatRooms(),
                        ]);
                      });
                    },
                    child: Text('重試'),
                  ),
                ],
              ),
            ),
          );
        } else {
          print('✅ FutureBuilder 完成，聊天室數量: ${_chatRooms.length}');
          final taskService = TaskService();
          final tasks = taskService.tasks;

          // 排序任務
          final statusOrder = {
            'Open': 0,
            'In Progress': 1,
            'Pending Confirmation': 2,
            'Dispute': 3,
            'Completed': 4,
          };

          tasks.sort((a, b) {
            final displayStatusA = _displayStatus(a);
            final displayStatusB = _displayStatus(b);

            final statusA = statusOrder[displayStatusA] ?? 99;
            final statusB = statusOrder[displayStatusB] ?? 99;
            if (statusA != statusB) {
              return statusA.compareTo(statusB);
            }
            return (DateTime.parse(b['task_date']))
                .compareTo(DateTime.parse(a['task_date']));
          });

          return DefaultTabController(
            length: 2,
            initialIndex: widget.initialTab,
            child: Scaffold(
              body: Column(
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
                  // 兩個分頁都顯示搜尋欄（與 task_list_page.dart 相同風格）
                  Padding(
                    padding: const EdgeInsets.all(12.0),
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
                            // Clear search button (only show when text is not empty)
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
                            // Filter button (only for Posted Tasks tab)
                            if (_tabController.index == 0)
                              IconButton(
                                icon: Icon(
                                  Icons.filter_list,
                                  color: _hasActiveFilters
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                                tooltip: 'Filter Options',
                                onPressed: () => _showFilterDialog(),
                              ),
                            // Reset button (only for Posted Tasks tab)
                            if (_tabController.index == 0)
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Reset Filters & Reload Data',
                                onPressed: () async {
                                  setState(() {
                                    _searchController.clear();
                                    searchQuery = '';
                                    selectedLocation = null;
                                    selectedHashtag = null;
                                    selectedStatus = null;
                                  });
                                  // 強制重新載入聊天室資料
                                  print('🔄 用戶點擊刷新，重新載入聊天室資料...');
                                  await _loadChatRooms();
                                  print('✅ 聊天室資料重載完成');
                                },
                              ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostedTasksChatList(), // Posted Tasks - 手風琴風格
                        _buildMyWorksChatList(), // My Works - 聊天室列表
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10),
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
    // 使用新的TaskStatusService獲取顯示狀態
    final statusService = context.read<TaskStatusService>();
    final displayStatus =
        statusService.getDisplayName(task['status'] ?? task['status_code']);
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

extension _ChatListPageStateHandFoldingMethods on _ChatListPageState {
  /// 構建緊湊任務卡片（手風琴式）
  Widget _buildCompactTaskCard(Map<String, dynamic> task) {
    final taskId = task['id'].toString();
    final isExpanded = _expandedTaskId == taskId;
    final displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;
    final theme = Theme.of(context).colorScheme;

    // 檢測當前分頁：true = My Works, false = Posted Tasks
    final isMyWorksTab = _tabController.index == 1;

    // 應徵者邏輯（僅 Posted Tasks 需要）
    List<Map<String, dynamic>> allApplicants = [];
    int applicantCount = 0;

    if (!isMyWorksTab) {
      // Posted Tasks：獲取應徵者數據
      final rooms = List<Map<String, dynamic>>.from(task['rooms'] ?? []);
      final applications =
          List<Map<String, dynamic>>.from(task['applications'] ?? []);

      // 從聊天室資料構建應徵者資訊
      for (final room in rooms) {
        allApplicants.add({
          'id': room['participant_id'],
          'user_id': room['participant_id'],
          'name': room['participant_name'] ?? 'Anonymous',
          'avatar_url': room['participant_avatar'],
          'rating': 4.5,
          'review_count': 12,
          'questionReply': room['last_message'] ?? 'Applied for this task',
          'sentMessages':
              room['last_message'] != null ? [room['last_message']] : [],
          'room_id': room['room_id'],
          'application_status': 'applied',
          'unread_count': room['unread_count'] ?? 0,
        });
      }

      // 如果有其他應徵者資訊但沒有聊天室，也加入
      for (final application in applications) {
        final existingApplicant = allApplicants.any((a) =>
            a['user_id']?.toString() == application['user_id']?.toString());
        if (!existingApplicant) {
          allApplicants.add({
            'id': application['user_id'],
            'user_id': application['user_id'],
            'name': application['name'] ?? 'Anonymous',
            'avatar_url': application['avatar_url'],
            'rating': 4.5,
            'review_count': 12,
            'questionReply':
                application['cover_letter'] ?? 'Applied for this task',
            'sentMessages': [],
            'room_id': null,
            'application_status': application['status'] ?? 'applied',
            'unread_count': 0,
          });
        }
      }
      applicantCount = allApplicants.length;
    }

    // 計算是否為 Open 狀態（不顯示應徵者統計）
    final isOpen = displayStatus == 'Open' || task['status'] == '1';

    // 時間距離戳記
    final timeAgo = _getTimeAgo(task['created_at']);

    // Emoji Bar 邏輯（僅 Posted Tasks 需要）
    final createdAt = DateTime.tryParse(task['created_at'] ?? '');
    final isNewTask =
        createdAt != null && DateTime.now().difference(createdAt).inDays < 7;
    final isPopular = applicantCount >= 2;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Column(
        children: [
          // 主任務卡片
          InkWell(
            onTap: () {
              if (isMyWorksTab) {
                // My Works：點擊直接進入聊天室
                _goToChatDetailFromMyWork(task);
              } else {
                // Posted Tasks：展開/收合任務
                _toggleTaskExpansion(taskId);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主要佈局：百分比 ｜ 其他任務資訊
                  Row(
                    children: [
                      // 左側：百分比圓圈區域
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: _buildProgressIndicator(
                            task, displayStatus, progress, baseColor),
                      ),
                      const SizedBox(width: 16),
                      // 右側：其他任務資訊區塊（包含標題、狀態、2x2資訊）
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 任務標題（省略符號處理）
                            Text(
                              task['title'] ?? 'Untitled Task',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // 狀態標籤和倒數計時/空位行
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: baseColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: baseColor.withOpacity(0.3)),
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
                                // 根據分頁顯示不同內容
                                if (isMyWorksTab)
                                  // My Works：顯示創建者名稱
                                  Expanded(
                                    child: Text(
                                      task['creator_name'] ?? 'Unknown Creator',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                else if (_isCountdownStatus(displayStatus))
                                  // Posted Tasks + Pending Confirmation：顯示倒數計時文字
                                  Expanded(
                                    child: _buildCompactCountdownText(task),
                                  )
                                else
                                  // Posted Tasks + 其他狀態：保持空白
                                  const Expanded(child: SizedBox()),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 2x2 任務資訊組區塊
                            Container(
                              padding:
                                  const EdgeInsets.only(right: 16), // 右側保持空間
                              child: Column(
                                children: [
                                  // 第一行：日期和金額
                                  Row(
                                    children: [
                                      // 日期
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                DateFormat('MM/dd').format(
                                                    DateTime.parse(
                                                        task['task_date'])),
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700]),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // 獎勵
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.attach_money,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${task['reward_point'] ?? task['salary'] ?? 0}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700]),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // 第二行：位置和語言
                                  Row(
                                    children: [
                                      // 位置
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                task['location'] ?? 'Unknown',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700]),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // 語言要求
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.language,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                task['language_requirement'] ??
                                                    'Any',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700]),
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
                      // 右側：箭頭
                      SizedBox(
                        width: 40,
                        child: isMyWorksTab
                            ? Icon(
                                Icons.chat_bubble_outline,
                                color: theme.primary,
                                size: 24,
                              )
                            : AnimatedRotation(
                                turns: isExpanded ? 0.25 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                              ),
                      ),
                    ],
                  ),

                  // 時間距離戳記和 Emoji 圖標
                  if (timeAgo.isNotEmpty || isNewTask || isPopular) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Emoji icons + 時間戳記
                        if (isNewTask) ...[
                          const Icon(Icons.eco, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                        ],
                        if (isPopular) ...[
                          const Icon(Icons.local_fire_department,
                              size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                        ],
                        if (timeAgo.isNotEmpty)
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                  ],

                  // 應徵者統計（僅在非 Open 狀態顯示）
                  if (!isOpen && applicantCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Applicants($applicantCount)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 展開內容（僅 Posted Tasks 顯示）
          if (isExpanded && !isMyWorksTab) ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: SlideTransition(
                position: _createSlideAnimation(),
                child: FadeTransition(
                  opacity: _createFadeAnimation(),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      // Action Bar
                      _buildTaskActionBar(task),
                      // 應徵者區域
                      _buildApplierSection(task, allApplicants),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 構建百分比指示器
  Widget _buildProgressIndicator(Map<String, dynamic> task,
      String displayStatus, double progress, Color baseColor) {
    // Pending Confirmation: 顯示倒數計時
    if (_isCountdownStatus(displayStatus)) {
      return _buildCompactCountdownTimer(task);
    }

    // Dispute: 顯示 Report 圖標
    if (displayStatus == 'Dispute') {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.1),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Icon(
          Icons.report_outlined,
          color: Colors.red,
          size: 20,
        ),
      );
    }

    // 其他狀態：顯示百分比圓圈
    return CustomPaint(
      painter: PieChartPainter(
        progress: progress,
        baseColor: baseColor,
        strokeWidth: 3,
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
    );
  }

  /// 構建緊湊版倒數計時器
  Widget _buildCompactCountdownTimer(Map<String, dynamic> task) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.purple.withOpacity(0.1),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: const Icon(
        Icons.timer,
        color: Colors.purple,
        size: 20,
      ),
    );
  }

  /// 構建緊湊版倒數計時文字（用於替換使用者名稱位置）
  Widget _buildCompactCountdownText(Map<String, dynamic> task) {
    return _CompactCountdownTextWidget(task: task);
  }

  /// 從 My Works 進入聊天室詳情
  void _goToChatDetailFromMyWork(Map<String, dynamic> task) {
    final currentUserId = context.read<UserService>().currentUser?.id;
    final roomId = task['room_id'];

    if (roomId != null && currentUserId != null) {
      // 直接使用聊天室 ID 導航
      context.push('/chat/detail', extra: {
        'room': {
          'roomId': roomId,
          'taskId': task['id'],
          'creatorId': task['creator_id'],
          'participantId': currentUserId,
        },
        'task': task,
        'otherUser': {
          'id': task['creator_id'],
          'name': task['creator_name'] ?? '任務發布者',
          'avatar':
              task['creator_avatar'] ?? 'assets/images/avatar/avatar-1.png',
        },
      });
    } else {
      // 如果沒有聊天室 ID，計算聊天室 ID
      final creatorId = task['creator_id']?.toString() ?? '';
      final calculatedRoomId =
          'task_${task['id']}_pair_${creatorId}_$currentUserId';

      context.push('/chat/detail', extra: {
        'room': {
          'roomId': calculatedRoomId,
          'taskId': task['id'],
          'creatorId': task['creator_id'],
          'participantId': currentUserId,
        },
        'task': task,
        'otherUser': {
          'id': task['creator_id'],
          'name': task['creator_name'] ?? '任務發布者',
          'avatar':
              task['creator_avatar'] ?? 'assets/images/avatar/avatar-1.png',
        },
      });
    }
  }

  /// 構建任務操作欄
  Widget _buildTaskActionBar(Map<String, dynamic> task) {
    final displayStatus = _displayStatus(task);
    final canEditDelete = displayStatus == 'Open';
    final theme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Actions 圖標
          Icon(Icons.chevron_right, size: 18, color: theme.primary),
          const SizedBox(width: 8),
          // 按鈕列表
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Info 按鈕
                  _buildActionButton(
                    'Info',
                    Icons.info_outline,
                    theme.primary,
                    () => _showTaskInfoDialog(task),
                  ),
                  if (canEditDelete) ...[
                    const SizedBox(width: 8),
                    // Edit 按鈕 - 使用橙色主題配色
                    _buildActionButton(
                      'Edit',
                      Icons.edit_outlined,
                      Colors.amber[700] ?? theme.primary,
                      () {
                        context.push('/task/create');
                      },
                    ),
                    const SizedBox(width: 8),
                    // Delete 按鈕 - 使用紅色主題配色
                    _buildActionButton(
                      'Delete',
                      Icons.delete_outline,
                      theme.error,
                      () async {
                        await _confirmAndDeleteTask(task);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 構建操作按鈕
  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 構建應徵者區域
  Widget _buildApplierSection(
      Map<String, dynamic> task, List<Map<String, dynamic>> applications) {
    if (applications.isEmpty) {
      // 無應徵者佔位
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_search_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No applications received yet. Applicants will appear here once they apply for this task.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 應徵者列表
    final applierChatItems =
        _convertApplicationsToApplierChatItems(applications);
    return Column(
      children:
          applierChatItems.map((app) => _buildApplierCard(task, app)).toList(),
    );
  }

  /// 構建應徵者卡片（平面列表樣式）
  Widget _buildApplierCard(
      Map<String, dynamic> task, Map<String, dynamic> app) {
    final theme = Theme.of(context).colorScheme;
    final userName = app['name'] ?? 'Anonymous';
    final avatarUrl = app['avatar_url'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tileColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: theme.outline.withOpacity(0.2)),
        ),
        leading: _buildApplierAvatar(userName, avatarUrl, theme),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: userName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text:
                    '. ⭐️ ${app['rating'] ?? 4.0}(${app['review_count'] ?? 16} comments)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        subtitle: Text(
          app['questionReply'] ??
              app['sentMessages']?[0] ??
              'Applied for this task',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        onTap: () {
          // 使用聊天室的真實 room_id
          final roomId = app['room_id'] ?? task['room_id'] ?? app['id'];
          context.push('/chat/detail', extra: {
            'room': {
              'roomId': roomId,
              'taskId': task['id'],
            },
            'task': task,
          });
        },
      ),
    );
  }

  /// 構建應徵者頭像
  Widget _buildApplierAvatar(
      String userName, String? avatarUrl, ColorScheme theme) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // 有頭像：直接使用 ClipOval 包裹 Image.network，不使用 CircleAvatar 避免重複容器
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            // 加載中顯示文字頭像
            return _buildTextAvatar(userName, theme);
          },
          errorBuilder: (context, error, stackTrace) {
            // 圖片載入失敗：顯示文字頭像
            return _buildTextAvatar(userName, theme);
          },
        ),
      );
    } else {
      // 無頭像：顯示文字頭像
      return _buildTextAvatar(userName, theme);
    }
  }

  /// 構建文字頭像
  Widget _buildTextAvatar(String userName, ColorScheme theme) {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final backgroundColor = _getAvatarColorFromTheme(userName, theme);

    return CircleAvatar(
      radius: 20,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          color: theme.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  /// 根據主題獲取頭像顏色
  Color _getAvatarColorFromTheme(String name, ColorScheme theme) {
    final colors = [
      theme.primary,
      theme.secondary,
      theme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
    ];
    final index = name.hashCode.abs() % colors.length;
    return colors[index];
  }

  void _showTaskInfoDialog(Map<String, dynamic> task) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayStatus = _displayStatus(task);

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
                                    label: Text(displayStatus,
                                        style: const TextStyle(fontSize: 11)),
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
                                      .toString()),
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
}

// 緊湊版倒數計時文字 Widget（用於替換使用者名稱位置）
class _CompactCountdownTextWidget extends StatefulWidget {
  final Map<String, dynamic> task;
  const _CompactCountdownTextWidget({required this.task});

  @override
  State<_CompactCountdownTextWidget> createState() =>
      _CompactCountdownTextWidgetState();
}

class _CompactCountdownTextWidgetState
    extends State<_CompactCountdownTextWidget> {
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

    if (days > 0) {
      return '${days}d ${hours}h left';
    } else {
      int minutes = (totalSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m left';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.timer,
          size: 14,
          color: Colors.purple[600],
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _remaining > Duration.zero
                ? _formatCompactDuration(_remaining)
                : 'Expired',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple[600],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

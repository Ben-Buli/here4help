// home_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:here4help/chat/models/chat_room_model.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/optimized_chat_service.dart';
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
  // 排序相關變數
  String _sortBy = 'updated_at'; // 預設按更新時間排序
  bool _sortDescending = true; // 預設降序（最新的在前）

  late TabController _tabController;

  // 未讀通知占位（任務 26 會替換成實作）
  NotificationService _notificationService = NotificationServicePlaceholder();
  Map<String, int> _unreadByTask = const {};
  Map<String, int> _unreadByRoom = const {};
  StreamSubscription<int>? _totalSub;
  StreamSubscription<Map<String, int>>? _taskSub;
  StreamSubscription<Map<String, int>>? _roomSub;

  // Posted Tasks 應徵者資料快取
  final Map<String, List<Map<String, dynamic>>> _applicationsByTask = {};

  // 手風琴功能 - 使用ValueNotifier避免setState
  final ValueNotifier<String?> _expandedTaskIdNotifier =
      ValueNotifier<String?>(null);
  // 動畫使用 AnimatedContainer 和 AnimatedScale 實現

  // 聊天服務
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoadingRooms = false;

  @override
  void initState() {
    super.initState();
    taskerFilterEnabled = widget.initialTab == 1; // 初始化篩選狀態

    // 檢查 URL 參數中的 tab 值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUrlTabParameter();
    });

    _taskFuture = Future.wait([
      TaskService().loadTasks(),
      TaskService().loadStatuses(),
      _loadApplicationsForPostedTasks(),
      _loadChatRooms(),
    ]);
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

    // 手風琴動畫現在使用 AnimatedContainer 和 AnimatedScale 實現
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        final newFilterEnabled = _tabController.index == 1;
        // 只在狀態真正改變時才調用setState
        if (taskerFilterEnabled != newFilterEnabled ||
            searchQuery.isNotEmpty ||
            selectedLocation != null ||
            selectedHashtag != null ||
            selectedStatus != null) {
          setState(() {
            taskerFilterEnabled = newFilterEnabled;
            // 重設搜尋與篩選
            _searchController.clear();
            searchQuery = '';
            selectedLocation = null;
            selectedHashtag = null;
            selectedStatus = null;
          });
        }
      }
    });

    // 初始化未讀服務：登入後切換為 Socket 實作
    _initUnreadService();
    final center = NotificationCenter();
    _totalSub = center.totalUnreadStream.listen((v) {
      if (!mounted) return;
      // _totalUnread 已移除，保留監聽器為將來擴展預留
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

  /// 檢查 URL 參數中的 tab 值
  void _checkUrlTabParameter() {
    try {
      final uri = Uri.parse(GoRouterState.of(context).uri.toString());
      final tabParam = uri.queryParameters['tab'];
      if (tabParam != null) {
        final tabIndex = int.tryParse(tabParam);
        if (tabIndex != null && tabIndex >= 0 && tabIndex < 2) {
          // 如果 URL 中的 tab 與當前不同，切換到指定分頁
          if (_tabController.index != tabIndex) {
            _tabController.animateTo(tabIndex);
            setState(() {
              taskerFilterEnabled = tabIndex == 1;
            });
            debugPrint('🔄 根據 URL 參數切換到分頁: $tabIndex');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ 檢查 URL 參數失敗: $e');
    }
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    _expandedTaskIdNotifier.dispose(); // 清理ValueNotifier
    _totalSub?.cancel();
    _taskSub?.cancel();
    _roomSub?.cancel();
    _notificationService.dispose();
    super.dispose();
  }

  /// 簡化的展開/收合邏輯 - 不使用setState，避免整頁重建
  void _toggleTaskExpansion(String taskId) {
    // 使用ValueNotifier直接更新狀態，不觸發setState
    final currentExpanded = _expandedTaskIdNotifier.value;
    final newExpandedId = currentExpanded == taskId ? null : taskId;
    if (currentExpanded != newExpandedId) {
      _expandedTaskIdNotifier.value = newExpandedId;
      print('🎛️ 任務卡片 $taskId ${newExpandedId != null ? "展開" : "收合"} - 無須重建整頁');
    }
  }

  // 動畫已簡化，移除複雜的動畫widgets避免閃爍

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

  /// 構建 Posted Tasks 的手風琴樣式列表（使用聚合API）
  Widget _buildPostedTasksChatList() {
    final statusOrder = {
      'Open': 0,
      'In Progress': 1,
      'Pending Confirmation': 2,
      'Dispute': 3,
      'Completed': 4,
    };

    final currentUserId = context.read<UserService>().currentUser?.id;

    print('🔍 Posted Tasks 檢查: 當前用戶ID = $currentUserId');

    // 檢查是否有用戶ID
    if (currentUserId == null) {
      return Center(
        child: Text(
          '請先登入以查看您的發布任務',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    // 使用聚合API獲取發布任務及應徵者
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: OptimizedChatService().getPostedTasksWithApplicants(
        userId: currentUserId,
        limit: 50,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '載入發布任務失敗',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        final myPostedTasks = snapshot.data ?? [];
        print('✅ 聚合API獲取到 ${myPostedTasks.length} 個發布任務');

        return _buildPostedTasksContent(statusOrder, myPostedTasks);
      },
    );
  }

  /// 構建 Posted Tasks 內容
  Widget _buildPostedTasksContent(
    Map<String, int> statusOrder,
    List<Map<String, dynamic>> myPostedTasks,
  ) {
    print('📊 Posted Tasks 統計: ${myPostedTasks.length} 個我創建的任務（來自聚合API）');

    if (myPostedTasks.isNotEmpty) {
      print(
          '🔍 前3個任務示例: ${myPostedTasks.take(3).map((t) => '${t['id']}: ${t['title']} (${t['applicants_count']} 個應徵者)').join(', ')}');
    }

    // 轉換聚合API數據格式以兼容現有UI邏輯
    final tasksWithApplicationInfo = myPostedTasks.map((task) {
      final taskId = task['id']?.toString() ?? '';

      // 從聚合API數據中獲取應徵者資訊
      final applicants =
          List<Map<String, dynamic>>.from(task['applicants'] ?? []);

      // 轉換應徵者格式為聊天室格式
      final optimizedService = OptimizedChatService();
      final applications =
          optimizedService.convertToApplierChatItems(applicants);

      print('💼 任務 $taskId (${task['title']}): ${applicants.length} 個應徵者');

      // 保持與原有邏輯兼容的數據結構
      return {
        // 主要任務資訊（來自聚合API）
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
        'reward_point': task['reward_point'] ?? 0,
        // 應徵者相關資訊（來自聚合API）
        'applicants': applicants,
        'applications': applications,
        'applicants_count': task['applicants_count'] ?? applicants.length,
        'has_applicants': applicants.isNotEmpty,
        // 為兼容性保留rooms欄位
        'rooms': applications
            .where((app) => app['room_id'] != null)
            .map((app) => {
                  'room_id': app['room_id'],
                  'task_id': taskId,
                  'participant_id': app['user_id'],
                  'participant_name': app['name'],
                  'participant_avatar': app['avatar'],
                  'last_message': app['questionReply'],
                  'unread_count': app['unread_count'] ?? 0,
                })
            .toList(),
      };
    }).toList();

    // 排序
    tasksWithApplicationInfo.sort((a, b) {
      // 根據選擇的排序方式進行排序
      if (_sortBy == 'status') {
        // 按狀態排序
        final displayStatusA = _displayStatus(a);
        final displayStatusB = _displayStatus(b);
        final statusA = statusOrder[displayStatusA] ?? 99;
        final statusB = statusOrder[displayStatusB] ?? 99;

        if (statusA != statusB) {
          return _sortDescending
              ? statusB.compareTo(statusA)
              : statusA.compareTo(statusB);
        }
      }

      // 次要排序：按時間排序
      DateTime timeA, timeB;
      if (_sortBy == 'updated_at') {
        timeA = DateTime.tryParse(a['updated_at'] ?? a['created_at'] ?? '') ??
            DateTime.now();
        timeB = DateTime.tryParse(b['updated_at'] ?? b['created_at'] ?? '') ??
            DateTime.now();
      } else {
        timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      }

      return _sortDescending ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
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

    // 檢查是否有用戶ID
    if (currentUserId == null) {
      return Center(
        child: Text(
          '請先登入以查看您的應徵記錄',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    // 從應徵記錄開始，找出我應徵過的所有任務
    final myApplications = taskService.myApplications;

    // 如果應徵記錄為空，嘗試載入並返回 FutureBuilder
    if (myApplications.isEmpty) {
      return FutureBuilder<void>(
        future: taskService.loadMyApplications(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '載入應徵記錄失敗',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          // 重新構建，這次應該有數據了
          return _buildMyWorksContent(statusOrder, currentUserId, taskService);
        },
      );
    }

    return _buildMyWorksContent(statusOrder, currentUserId, taskService);
  }

  /// 構建 My Works 內容（從應徵記錄開始）
  Widget _buildMyWorksContent(
    Map<String, int> statusOrder,
    int currentUserId,
    TaskService taskService,
  ) {
    final myApplications = taskService.myApplications;

    // 調試：檢查應徵記錄的結構
    if (myApplications.isNotEmpty) {
      print('🔍 第一個應徵記錄的鍵: ${myApplications.first.keys.toList()}');
      print('🔍 第一個應徵記錄內容: ${myApplications.first}');
    } else {
      print('⚠️ 應徵記錄為空');
    }

    // 從應徵記錄中獲取task_id，根據後端API結構
    final myAppliedTaskIds = myApplications
        .map((app) {
          // 根據list_by_user.php API，任務ID應該在 'id' 欄位（來自tasks表）
          final taskId = app['id']?.toString() ?? '';
          if (taskId.isNotEmpty) {
            print('✅ 找到任務ID: $taskId');
            print(
                '📋 應徵狀態: ${app['client_status_display']} (${app['client_status_code']})');
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
      return participantId == currentUserId.toString();
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

      // 查找我的應徵資訊（根據任務ID）
      final myApplication = myApplications.firstWhere(
        (app) => app['id']?.toString() == taskId,
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
            detailedTask['status_display'] ??
            'Unknown',
        'status_code': myApplication['client_status_code'] ??
            myApplication['status_code'] ??
            detailedTask['status_code'] ??
            'unknown',
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
      // 根據選擇的排序方式進行排序
      if (_sortBy == 'status') {
        // 按狀態排序
        final displayStatusA = _displayStatus(a);
        final displayStatusB = _displayStatus(b);
        final statusA = statusOrder[displayStatusA] ?? 99;
        final statusB = statusOrder[displayStatusB] ?? 99;

        if (statusA != statusB) {
          return _sortDescending
              ? statusB.compareTo(statusA)
              : statusA.compareTo(statusB);
        }
      }

      // 次要排序：按時間排序
      DateTime timeA, timeB;
      if (_sortBy == 'updated_at') {
        timeA = DateTime.tryParse(a['updated_at'] ?? a['created_at'] ?? '') ??
            DateTime.now();
        timeB = DateTime.tryParse(b['updated_at'] ?? b['created_at'] ?? '') ??
            DateTime.now();
      } else {
        timeA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        timeB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
      }

      return _sortDescending ? timeB.compareTo(timeA) : timeA.compareTo(timeB);
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
        'questionReply': _buildCoverLetter(app['cover_letter']),
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

  /// 構建應徵者的應徵信內容
  String _buildCoverLetter(String? coverLetter) {
    return coverLetter?.trim() ?? '';
  }

  /// 檢查是否有活躍的篩選條件
  bool get _hasActiveFilters =>
      (selectedLocation != null && selectedLocation!.isNotEmpty) ||
      (selectedStatus != null && selectedStatus!.isNotEmpty) ||
      (searchQuery.isNotEmpty) ||
      (_sortBy != 'updated_at') ||
      (!_sortDescending);

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
              title: const Text('Filter & Sort Options'),
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
                    const SizedBox(height: 16),
                    // Sort by
                    DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: const InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'updated_at',
                          child: Text('Update Time'),
                        ),
                        DropdownMenuItem(
                          value: 'created_at',
                          child: Text('Create Time'),
                        ),
                        DropdownMenuItem(
                          value: 'status',
                          child: Text('Status'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          _sortBy = value ?? 'updated_at';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Sort order
                    Row(
                      children: [
                        const Text('Sort Order: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<bool>(
                            value: _sortDescending,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text('Descending (Newest First)'),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text('Ascending (Oldest First)'),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                _sortDescending = value ?? true;
                              });
                            },
                          ),
                        ),
                      ],
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
                      // 更新排序狀態
                      _sortBy = _sortBy;
                      _sortDescending = _sortDescending;
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
    // 調試：檢查build方法被調用的頻率
    print(
        '🔧 ChatListPage build 被調用 - 時間: ${DateTime.now().millisecondsSinceEpoch}');
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
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('載入失敗: ${snapshot.error}'),
                  const SizedBox(height: 16),
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
                    child: const Text('重試'),
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
                        // 使用防抖動，減少不必要的重建
                        final newQuery = value.toLowerCase();
                        if (searchQuery != newQuery) {
                          setState(() {
                            searchQuery = newQuery;
                          });
                        }
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
                                  // 只在真正需要清除時才調用setState
                                  if (_searchController.text.isNotEmpty ||
                                      searchQuery.isNotEmpty) {
                                    setState(() {
                                      _searchController.clear();
                                      searchQuery = '';
                                    });
                                  }
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
                                  // 檢查是否有篩選或排序條件
                                  final hasFilters =
                                      _searchController.text.isNotEmpty ||
                                          searchQuery.isNotEmpty ||
                                          selectedLocation != null ||
                                          selectedHashtag != null ||
                                          selectedStatus != null ||
                                          _sortBy != 'updated_at' ||
                                          !_sortDescending;

                                  if (hasFilters) {
                                    setState(() {
                                      _searchController.clear();
                                      searchQuery = '';
                                      selectedLocation = null;
                                      selectedHashtag = null;
                                      selectedStatus = null;
                                      _sortBy = 'updated_at';
                                      _sortDescending = true;
                                    });
                                  }
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
  /// 構建緊湊任務卡片（手風琴式） - 使用ValueNotifier避免setState重建
  Widget _buildCompactTaskCard(Map<String, dynamic> task) {
    final taskId = task['id'].toString();
    final displayStatus = _displayStatus(task);
    final progressData = _getProgressData(displayStatus);
    final progress = progressData['progress'] ?? 0.0;
    final baseColor = progressData['color'] ?? Colors.grey[600]!;
    final theme = Theme.of(context).colorScheme;

    // 檢測當前分頁：true = My Works, false = Posted Tasks
    final isMyWorksTab = _tabController.index == 1;

    // 應徵者邏輯（僅 Posted Tasks 需要）- 直接使用預處理的數據避免重新計算
    final allApplicants = !isMyWorksTab
        ? List<Map<String, dynamic>>.from(task['applications'] ?? [])
        : <Map<String, dynamic>>[];
    final applicantCount = allApplicants.length;

    // 時間距離戳記
    final timeAgo = _getTimeAgo(task['created_at']);

    // Emoji Bar 邏輯（僅 Posted Tasks 需要）
    final createdAt = DateTime.tryParse(task['created_at'] ?? '');
    final isNewTask =
        createdAt != null && DateTime.now().difference(createdAt).inDays < 7;
    final isPopular = applicantCount >= 2;

    // 使用ValueListenableBuilder來監聽展開狀態，避免整頁重建
    return ValueListenableBuilder<String?>(
      valueListenable: _expandedTaskIdNotifier,
      builder: (context, expandedTaskId, child) {
        final isExpanded = expandedTaskId == taskId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                                          task['creator_name'] ??
                                              'Unknown Creator',
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
                                  padding: const EdgeInsets.only(
                                      right: 16), // 右側保持空間
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
                                                        color:
                                                            Colors.grey[700]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                        color:
                                                            Colors.grey[700]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                    task['location'] ??
                                                        'Unknown',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.grey[700]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                        color:
                                                            Colors.grey[700]),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                // Emoji Bar + 時間戳記（在2x2任務資訊區塊下方）
                                if (timeAgo.isNotEmpty ||
                                    isNewTask ||
                                    isPopular) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Emoji icons + 時間戳記
                                      if (isNewTask) ...[
                                        const Icon(Icons.eco,
                                            size: 12, color: Colors.green),
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
                              ],
                            ),
                          ),
                          // 右側：arrow 圖標（簡化版）
                          SizedBox(
                            width: 40,
                            child: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.arrow_forward_ios,
                              color: theme.primary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      // 移除原本的時間距離戳記和 Emoji 圖標區塊（已移到2x2任務資訊區塊下方）

                      // 應徵者統計已移除
                    ],
                  ),
                ),
              ),

              // 展開內容（僅 Posted Tasks 顯示）- 簡化顯示邏輯
              if (isExpanded && !isMyWorksTab) ...[
                const Divider(height: 1),
                // Action Bar
                _buildTaskActionBar(task),
                // 應徵者區域
                _buildApplierSection(task, allApplicants),
              ],
            ],
          ),
        );
      }, // ValueListenableBuilder結束
    ); // return ValueListenableBuilder結束
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
  void _goToChatDetailFromMyWork(Map<String, dynamic> task) async {
    final currentUserId = context.read<UserService>().currentUser?.id;
    String? roomId = task['room_id']?.toString();
    final creatorId = task['creator_id'];

    // 確保房間存在（若無 roomId 或為舊格式則嘗試建立）
    if (currentUserId != null && (roomId == null || roomId.isEmpty)) {
      try {
        final ensured = await ChatService().ensureRoom(
          taskId: task['id'].toString(),
          creatorId:
              (creatorId is int) ? creatorId : int.tryParse('$creatorId') ?? 0,
          participantId: currentUserId,
          type: 'application',
        );
        final room = ensured['room'] as Map<String, dynamic>?;
        if (room != null && room['id'] != null) {
          roomId = room['id'].toString();
        }
      } catch (_) {}
    }

    // 後備：仍無 roomId 時使用舊格式（前端可照常使用，後端會拒絕未建立房間的讀取）
    if (roomId == null || roomId.isEmpty) {
      roomId = 'task_${task['id']}_pair_${creatorId}_$currentUserId';
    }

    // 建立 chatPartnerInfo（我的作品 => 對方為 creator）
    final chatPartnerInfo = {
      'id': creatorId?.toString(),
      'name': task['creator_name'] ?? 'Creator',
      'avatar': task['creator_avatar'] ?? 'assets/images/avatar/avatar-1.png',
    };

    // 產生 URL + 快存恢復資料
    final chatUrl = ChatStorageService.generateChatUrl(
      roomId: roomId,
      taskId: task['id']?.toString(),
    );
    await ChatStorageService.savechatRoomData(
      roomId: roomId,
      room: {
        'id': roomId,
        'roomId': roomId,
        'taskId': task['id'],
        'creatorId': creatorId,
        'participantId': currentUserId,
        'type': 'application',
        'creator_name': task['creator_name'],
        'creator_avatar': task['creator_avatar'],
      },
      task: task,
      userRole: 'participant',
      chatPartnerInfo: {
        'id': creatorId?.toString(),
        'name': task['creator_name'] ?? 'Creator',
        // 不預設圖片，交由詳情頁用文字頭像與主題配色處理
        'avatar': '',
      },
    );

    context.go(chatUrl, extra: {
      'room': {
        'id': roomId,
        'roomId': roomId,
        'taskId': task['id'],
        'creatorId': creatorId,
        'participantId': currentUserId,
        'type': 'application',
      },
      'task': task,
      'userRole': 'participant',
      'chatPartnerInfo': {
        'id': creatorId?.toString(),
        'name': task['creator_name'] ?? 'Creator',
        'avatar': task['creator_avatar'] ?? 'assets/images/avatar/avatar-1.png',
      },
    });
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
      Map<String, dynamic> task, List<Map<String, dynamic>> allApplicants) {
    if (allApplicants.isEmpty) {
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

    // 應徵者列表（直接使用已轉換的數據）
    return Column(
      children:
          allApplicants.map((app) => _buildApplierCard(task, app)).toList(),
    );
  }

  /// 構建應徵者卡片（平面列表樣式）
  Widget _buildApplierCard(
      Map<String, dynamic> task, Map<String, dynamic> app) {
    final theme = Theme.of(context).colorScheme;
    final userName = app['name'] ?? 'Anonymous';
    final avatarUrl = app['avatar'] ??
        app['participant_avatar'] ??
        app['participant_avatar_url'];

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
                    '. ⭐️ ${app['rating'] ?? 4.0}(${app['reviewsCount'] ?? app['review_count'] ?? 16} comments)',
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
        onTap: () async {
          // 使用聊天室的真實 room_id，並補齊必要的識別資訊
          final roomId = app['room_id'] ?? task['room_id'] ?? app['id'];
          final currentUserId = context.read<UserService>().currentUser?.id;
          // Posted Tasks 下，creatorId 應為當前登入者，participantId 取應徵者
          final creatorIdStr =
              (task['creator_id'] ?? currentUserId)?.toString();
          final participantIdStr =
              (app['participant_id'] ?? app['user_id'])?.toString();

          // 確保資料庫存在聊天室記錄（若不存在會自動建立）
          String ensuredRoomId = roomId?.toString() ?? '';
          try {
            if (creatorIdStr != null && participantIdStr != null) {
              final ensured = await ChatService().ensureRoom(
                taskId: task['id'].toString(),
                creatorId: int.tryParse(creatorIdStr) ?? 0,
                participantId: int.tryParse(participantIdStr) ?? 0,
                type: 'application',
              );
              final room = ensured['room'] as Map<String, dynamic>?;
              if (room != null && room['id'] != null) {
                ensuredRoomId = room['id'].toString();
              }
            }
          } catch (_) {}

          // 產生可分享/可回訪的 URL（同時保留 extra 完整 payload）
          final chatUrl = ChatStorageService.generateChatUrl(
            roomId: ensuredRoomId,
            taskId: task['id']?.toString(),
          );
          // 快取一份資料以便 ChatDetailWrapper/TitleWidget 回訪或重新整理時可恢復
          await ChatStorageService.savechatRoomData(
            roomId: ensuredRoomId,
            room: {
              'id': ensuredRoomId,
              'roomId': ensuredRoomId,
              'taskId': task['id'],
              'creatorId': creatorIdStr,
              'participantId': participantIdStr,
              'type': 'application',
              'participant_name': userName,
              'participant_avatar': avatarUrl,
            },
            task: task,
            userRole: 'creator',
            chatPartnerInfo: {
              'id': participantIdStr,
              'name': userName,
              // 不預設圖片，交由詳情頁用文字頭像與主題配色處理
              'avatar': '',
            },
          );

          // 構建應徵者的應徵信內容
          final coverLetter = _buildCoverLetter(
            app['cover_letter'],
          );

          context.go(chatUrl, extra: {
            'room': {
              'id': ensuredRoomId,
              'roomId': ensuredRoomId,
              'taskId': task['id'],
              'creatorId': creatorIdStr,
              'participantId': participantIdStr,
              'type': 'application',
              'coverLetter': coverLetter, // 應徵信（cover_letter）
              'answersJson': app['answers_json'], // 問題與回答（answers_json）
            },
            'task': task,
            'otherUser': {
              'id': participantIdStr,
              'name': userName,
              'avatar': avatarUrl ?? 'assets/images/avatar/avatar-1.png',
            },
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

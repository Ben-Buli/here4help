// home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:intl/intl.dart';
import 'package:here4help/constants/task_status.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _taskFuture = TaskService().loadTasks();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          taskerFilterEnabled = _tabController.index == 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showTaskInfoDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Task Info'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Title: ${task['title'] ?? 'N/A'}'),
                Text('Location: ${task['location']}'),
                Text('Salary: ${task['salary']}'),
                Text(
                    'Date: ${DateFormat('MM/dd').format(DateTime.parse(task['task_date']))}'),
                Text('Language Requirement: ${task['language_requirement']}'),
                Text(
                    'Hashtags: ${(task['hashtags'] as List<dynamic>).join(', ')}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
    final displayStatus = TaskStatus.getDisplayStatus(status);

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

  /// 修改卡片內容，添加進度條
  Widget _taskCardWithProgressBar(Map<String, dynamic> task) {
    final progressData = _getProgressData(task['status']);
    final progress = progressData['progress'];
    final color = progressData['color'];

    return Card(
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
                      value: _getProgressData(task['status'])['progress'],
                      backgroundColor: Colors.grey[300],
                      color: _getProgressData(task['status'])['color'],
                      minHeight: 20,
                    ),
                    Text(
                      _getProgressLabel(task['status']),
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
                label: Text(task['status']),
                backgroundColor: Colors.transparent,
                labelStyle: const TextStyle(color: Colors.red),
                side: const BorderSide(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskCardWithapplierChatItems(
      Map<String, dynamic> task, List<Map<String, dynamic>> applierChatItems) {
    // Calculate unreadCount: sum of all applierChatItems' unreadCount
    int taskUnreadCount = 0;
    // applierChatItems with isHidden == true are filtered out
    final visibleapplierChatItems =
        applierChatItems.where((item) => item['isHidden'] != true).toList();

    for (final item in visibleapplierChatItems) {
      taskUnreadCount += (item['unreadCount'] as int?) ?? 0;
    }

    return Card(
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
            if (taskUnreadCount > 0) ...[
              // 未讀訊息計數
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$taskUnreadCount unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 應徵者列表
            ...visibleapplierChatItems
                .map((item) => _buildApplierItem(item, task)),
          ],
        ),
      ),
    );
  }

  Widget _buildApplierItem(
      Map<String, dynamic> applier, Map<String, dynamic> task) {
    final unreadCount = applier['unreadCount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: applier['avatar_url'] != null
                ? NetworkImage(applier['avatar_url'])
                : null,
            child: applier['avatar_url'] == null
                ? Text(
                    (applier['name'] as String?)?.isNotEmpty == true
                        ? applier['name'][0].toUpperCase()
                        : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  applier['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Last message: ${applier['last_message'] ?? 'No messages'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getProgressLabel(String status) {
    final displayStatus = TaskStatus.getDisplayStatus(status);

    switch (displayStatus) {
      case 'Open':
        return 'Open';
      case 'In Progress':
        return 'In Progress';
      case 'Pending Confirmation':
        return 'Pending Confirmation';
      case 'Completed':
        return 'Completed';
      case 'Dispute':
        return 'Dispute';
      case 'Applying (Tasker)':
        return 'Applying (Tasker)';
      case 'In Progress (Tasker)':
        return 'In Progress (Tasker)';
      case 'Completed (Tasker)':
        return 'Completed (Tasker)';
      case 'Rejected (Tasker)':
        return 'Rejected (Tasker)';
      case 'Pending Confirmation (Tasker)':
        return 'Pending Confirmation (Tasker)';
      default:
        return displayStatus;
    }
  }

  /// 倒數計時器：Pending Confirmation 狀態下顯示，倒數7天（以 updated_at 起算），結束時自動設為 Completed
  Widget _buildCountdownTimer(Map<String, dynamic> task) {
    return _CountdownTimerWidget(
      task: task,
      onCountdownComplete: () {
        setState(() {
          // Convert database status to display status for comparison
          final displayStatus = TaskStatus.getDisplayStatus(task['status']);

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

  /// 根據狀態返回進度值和顏色
  Map<String, dynamic> _getProgressDataForTask(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.getDisplayStatus(status);

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

  /// 修改卡片內容，添加進度條
  Widget _taskCardWithProgressBarForTask(Map<String, dynamic> task) {
    final progressData = _getProgressDataForTask(task['status']);
    final progress = progressData['progress'];
    final color = progressData['color'];

    return Card(
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
                      value:
                          _getProgressDataForTask(task['status'])['progress'],
                      backgroundColor: Colors.grey[300],
                      color: _getProgressDataForTask(task['status'])['color'],
                      minHeight: 20,
                    ),
                    Text(
                      _getProgressLabel(task['status']),
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
                label: Text(task['status']),
                backgroundColor: Colors.transparent,
                labelStyle: const TextStyle(color: Colors.red),
                side: const BorderSide(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Map<String, dynamic>> tasks) {
    final filteredTasks = tasks.where((task) {
      final hashtags =
          (task['hashtags'] as List<dynamic>?)?.cast<String>() ?? [];
      final matchQuery = searchQuery.isEmpty ||
          task['title']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          task['description']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          hashtags.any(
              (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()));
      final matchLocation = selectedLocation == null ||
          task['location'].toString() == selectedLocation;
      final displayStatus = TaskStatus.getDisplayStatus(task['status']);
      final matchStatus =
          selectedStatus == null || displayStatus == selectedStatus;

      return matchQuery && matchLocation && matchStatus;
    }).toList();

    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    // 這裡實現任務卡片的UI
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(task['title'] ?? 'No Title'),
        subtitle: Text(task['description'] ?? 'No Description'),
        trailing: Text(TaskStatus.getDisplayStatus(task['status'])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat List'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Tasks'),
            Tab(text: 'Tasker Tasks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Tasks Tab
          FutureBuilder<void>(
            future: _taskFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final taskService = TaskService();
              final tasks = taskService.tasks;

              return _buildTaskList(tasks);
            },
          ),
          // Tasker Tasks Tab
          FutureBuilder<void>(
            future: _taskFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final taskService = TaskService();
              final tasks = taskService.tasks;

              return _buildTaskList(tasks);
            },
          ),
        ],
      ),
    );
  }
}

class _CountdownTimerWidget extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onCountdownComplete;

  const _CountdownTimerWidget({
    required this.task,
    required this.onCountdownComplete,
  });

  @override
  State<_CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<_CountdownTimerWidget>
    with TickerProviderStateMixin {
  late Ticker _ticker;
  late Duration _remainingTime;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  void _calculateRemainingTime() {
    final updatedAt = DateTime.tryParse(widget.task['updated_at'] ?? '');
    if (updatedAt != null) {
      final deadline = updatedAt.add(const Duration(days: 7));
      _remainingTime = deadline.difference(DateTime.now());

      if (_remainingTime.isNegative) {
        _remainingTime = Duration.zero;
        _isCompleted = true;
        widget.onCountdownComplete();
      }
    } else {
      _remainingTime = Duration.zero;
    }
  }

  void _startTimer() {
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    setState(() {
      _calculateRemainingTime();
    });

    if (_remainingTime.isNegative || _remainingTime.inSeconds <= 0) {
      if (!_isCompleted) {
        _isCompleted = true;
        widget.onCountdownComplete();
      }
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return const SizedBox.shrink();
    }

    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours % 24;
    final minutes = _remainingTime.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: Colors.orange[700], size: 16),
          const SizedBox(width: 8),
          Text(
            'Time remaining: ${days}d ${hours}h ${minutes}m',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

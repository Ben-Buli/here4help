// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:here4help/chat/models/chat_room_model.dart';
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
        applierChatItems.where((ap) => ap['isHidden'] != true).toList();
    for (final ap in visibleapplierChatItems) {
      ap['unreadCount'] ??= (ap['questionReply'] != '' ? 1 : 0) +
          (ap['sentMessages']?.length ?? 0);
      taskUnreadCount += (ap['unreadCount'] ?? 0) as int;
    }
    // Store unreadCount in task for badge
    task['unreadCount'] = taskUnreadCount;

    Widget cardContent = Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
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
                if (_isCountdownStatus(task['status'])) ...[
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
                                Expanded(child: Text('${task['salary']}')),
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
                  ],
                ),
                const SizedBox(height: 8),
                ...visibleapplierChatItems.map(
                  (applierChatItem) => SlidableAutoCloseBehavior(
                    child: Slidable(
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
                                  'room': applierChatItem,
                                  'task': task,
                                };
                                context.push('/chat/detail', extra: data);
                              },
                            ),
                          ),
                          if ((applierChatItem['unreadCount'] ?? 0) > 0)
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
                                  '${applierChatItem['unreadCount']}',
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
                ),
              ],
            ),
          ),
        ),
        // 總未讀徽章（右上角）
        if ((task['unreadCount'] ?? 0) > 0)
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
                  '${task['unreadCount']}',
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

    if (task['status'] == 'Open') {
      return SlidableAutoCloseBehavior(
        child: Slidable(
          key: ValueKey(task['id']),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    _showTaskInfoDialog(task);
                    Slidable.of(context)?.close();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await _showDoubleConfirmDialog(
                        'Delete Task',
                        'Are you sure you want to delete this task?');
                    if (confirm == true) {
                      setState(() {
                        TaskService()
                            .tasks
                            .removeWhere((t) => t['id'] == task['id']);
                      });
                    }
                    Slidable.of(context)?.close();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: cardContent,
        ),
      );
    } else {
      // For non-Open tasks, ensure consistent wrapping for future-proofing
      return SlidableAutoCloseBehavior(child: cardContent);
    }
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
    if (displayStatus == 'Rejected (Tasker)') {
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
      TaskStatus.statusString['open']!: 0,
      TaskStatus.statusString['in_progress']!: 1,
      TaskStatus.statusString['pending_confirmation']!: 2,
      TaskStatus.statusString['dispute']!: 3,
      TaskStatus.statusString['completed']!: 4,
    };

    return FutureBuilder(
      future: _taskFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          final tasks = taskService.tasks;
          tasks.sort((a, b) {
            // Convert database status to display status for sorting
            final displayStatusA =
                TaskStatus.statusString[a['status']] ?? a['status'];
            final displayStatusB =
                TaskStatus.statusString[b['status']] ?? b['status'];

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
          final statusOptions = filteredTasksForDropdown
              .map((e) => (e['status'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          return DefaultTabController(
            length: 2,
            initialIndex: taskerFilterEnabled ? 1 : 0,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Posted Tasks'),
                    Tab(text: 'My Works'),
                  ],
                ),
                // Removed or reduced vertical space above TabBar
                // const SizedBox(height: 8),
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
                          items: statusOptions.map((status) {
                            return DropdownMenuItem(
                                value: status, child: Text(status));
                          }).toList(),
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
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTaskList(false), // My Post
                      _buildTaskList(true), // My Task
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

  Widget _buildTaskList(bool taskerEnabled) {
    final taskService = TaskService();
    final statusOrder = {
      TaskStatus.statusString['open']!: 0,
      TaskStatus.statusString['in_progress']!: 1,
      TaskStatus.statusString['pending_confirmation']!: 2,
      TaskStatus.statusString['dispute']!: 3,
      TaskStatus.statusString['completed']!: 4,
    };
    final tasks = taskService.tasks;
    tasks.sort((a, b) {
      // Convert database status to display status for sorting
      final displayStatusA =
          TaskStatus.statusString[a['status']] ?? a['status'];
      final displayStatusB =
          TaskStatus.statusString[b['status']] ?? b['status'];

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
      final status = (task['status'] ?? '').toString();
      final description = (task['description'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      final matchQuery = query.isEmpty ||
          title.contains(query) ||
          location.toLowerCase().contains(query) ||
          description.contains(query);
      final matchLocation =
          selectedLocation == null || selectedLocation == location;
      // Convert database status to display status for filtering
      final displayStatus = TaskStatus.statusString[status] ?? status;
      final matchStatus =
          selectedStatus == null || selectedStatus == displayStatus;
      final matchTasker = taskerEnabled
          ? ((task['hashtags'] as List<dynamic>? ?? [])
              .map((e) => e.toString().toLowerCase())
              .contains('tasker'))
          : !((task['hashtags'] as List<dynamic>? ?? [])
              .map((e) => e.toString().toLowerCase())
              .contains('tasker'));
      return matchQuery && matchLocation && matchStatus && matchTasker;
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: filteredTasks.map((task) {
        final applierChatItems = chatRoomModel
            .where((applierChatItem) => applierChatItem['taskId'] == task['id'])
            .toList();
        return _taskCardWithapplierChatItems(task, applierChatItems);
      }).toList(),
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
      addButton('Read', Colors.blue[100]!, () {
        setState(() {
          int unread = applierChatItem['unreadCount'] ?? 0;
          applierChatItem['unreadCount'] = 0;
          task['unreadCount'] = (task['unreadCount'] ?? 0) - unread;
          if (task['unreadCount']! < 0) task['unreadCount'] = 0;
        });
      });
      addButton('Hide', Colors.orange[100]!, () {
        setState(() {
          applierChatItem['isHidden'] = true;
        });
      });
      addButton('Delete', Colors.red[100]!, () async {
        final confirm = await _showDoubleConfirmDialog('Delete applierChatItem',
            'Are you sure you want to delete this applierChatItem?');
        if (confirm == true) {
          setState(() {
            applierChatItem['isHidden'] = true;
          });
        }
      });
    } else if (displayStatus == 'In Progress' ||
        displayStatus == 'Dispute' ||
        displayStatus == 'Completed') {
      addButton('Read', Colors.blue[100]!, () {
        setState(() {
          int unread = applierChatItem['unreadCount'] ?? 0;
          applierChatItem['unreadCount'] = 0;
          task['unreadCount'] = (task['unreadCount'] ?? 0) - unread;
          if (task['unreadCount']! < 0) task['unreadCount'] = 0;
        });
      });
    } else if (displayStatus == 'Pending Confirmation') {
      addButton('Confirm', Colors.green[100]!, () {
        TaskService()
            .updateTaskStatus(task['id'], 'completed'); // Use database status
        setState(() {
          task['status'] = 'completed'; // Use database status
        });
      });
    }

    return actions;
  }
}

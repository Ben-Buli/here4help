// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/global_task_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:here4help/chat/models/chat_room_model.dart';

// Define statusString as a constant outside the class
const Map<String, String> statusString = {
  'open': 'Open',
  'in_progress': 'In Progress',
  'pending_confirmation': 'Pending Confirmation',
  'dispute': 'Dispute',
  'completed': 'Completed',
};

// TODO: 左右滑動功能：Card, Item
// TODO: 滑動後的動作：接受、拒絕申請者
//  TODO: 點擊進入聊天室
// TODO：各種狀態Card 樣式

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late Future<void> _taskFuture;

  @override
  void initState() {
    super.initState();
    _taskFuture = GlobalTaskList().loadTasks();
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
                Text('Date: ${task['task_date']}'),
                Text('Language Requirement: ${task['language_requirement']}'),
                Text(
                    'Hashtags: ${(task['hashtags'] as List<dynamic>).join(', ')}'),
                Text('Status: ${task['status']}'),
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
    // Only return text color, ignore background.
    switch (status) {
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
      default:
        return Colors.grey[800]!;
    }
  }

  Color _getStatusChipBorderColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.blue[100]!;
      case 'In Progress':
        return Colors.orange[100]!;
      case 'Dispute':
        return Colors.red[100]!;
      case 'Pending Confirmation':
        return Colors.purple[100]!;
      case 'Completed':
        return const Color.fromARGB(255, 218, 218, 218);
      default:
        return Colors.grey[100]!;
    }
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
                if (task['status'] == 'Pending Confirmation') ...[
                  _buildCountdownTimer(task),
                  const SizedBox(height: 8),
                ],
                Text(task['title'] ?? 'N/A',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: null,
                    softWrap: true),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                    Flexible(
                      child: Text(
                        ' ${task['location']}   💰 ${task['salary']}   📅 ${task['task_date']}   🌐 ${task['language_requirement']}',
                        maxLines: null,
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    Chip(
                      label: Text(task['status']),
                      backgroundColor: Colors.transparent,
                      labelStyle: TextStyle(
                          color: _getStatusChipColor(task['status'], 'Text')),
                      side: BorderSide(
                          color: _getStatusChipBorderColor(task['status'])),
                    ),
                    ...((task['hashtags'] as List<dynamic>)
                        .map((tag) => Chip(label: Text(tag.toString())))
                        .toList()),
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
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  visibleapplierChatItems
                                      .remove(applierChatItem);
                                  visibleapplierChatItems.insert(
                                      0, applierChatItem);
                                  applierChatItems.remove(applierChatItem);
                                  applierChatItems.insert(0, applierChatItem);
                                });
                                Slidable.of(context)?.close();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey[300],
                                ),
                                child: const Icon(Icons.push_pin,
                                    color: Colors.black),
                              ),
                            ),
                          ),
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  applierChatItem['isMuted'] =
                                      !(applierChatItem['isMuted'] ?? false);
                                });
                                Slidable.of(context)?.close();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.brown[300],
                                ),
                                child: Icon(
                                  (applierChatItem['isMuted'] ?? false)
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  color: Colors.black,
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
                              onTap: () {
                                setState(() {
                                  int applierChatItemUnread =
                                      applierChatItem['unreadCount'] ?? 0;
                                  applierChatItem['unreadCount'] = 0;
                                  task['unreadCount'] =
                                      (task['unreadCount'] ?? 0) -
                                          applierChatItemUnread;
                                  if (task['unreadCount']! < 0) {
                                    task['unreadCount'] = 0;
                                  }
                                });
                                Slidable.of(context)?.close();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                ),
                                child: const Text(
                                  'Read',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  applierChatItem['isHidden'] = true;
                                });
                                Slidable.of(context)?.close();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                ),
                                child: const Text(
                                  'Hide',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: GestureDetector(
                              onTap: () async {
                                final confirm = await _showDoubleConfirmDialog(
                                    'Reject applierChatItem',
                                    'Are you sure you want to reject this applierChatItem?');
                                if (confirm == true) {
                                  setState(() {
                                    applierChatItem['isHidden'] = true;
                                  });
                                }
                                Slidable.of(context)?.close();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 修改這裡: 用 Stack 包裹 Card，並將未讀徽章放在右上角
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
                              // 移除 trailing 的未讀徽章
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
                          // 未讀徽章，右上角
                          if ((applierChatItem['unreadCount'] ?? 0) > 0)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(0),
                                width: 20,
                                height: 20,
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
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              child: Center(
                child: Text(
                  '${task['unreadCount']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                        GlobalTaskList()
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
          task['status'] = 'Completed';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final globalTaskList = GlobalTaskList();

    final statusOrder = {
      statusString['open']!: 0,
      statusString['in_progress']!: 1,
      statusString['pending_confirmation']!: 2,
      statusString['dispute']!: 3,
      statusString['completed']!: 4,
    };

    return FutureBuilder(
      future: _taskFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          final tasks = globalTaskList.tasks;
          tasks.sort((a, b) {
            final statusA = statusOrder[a['status']] ?? 99;
            final statusB = statusOrder[b['status']] ?? 99;
            if (statusA != statusB) {
              return statusA.compareTo(statusB);
            }
            return (DateTime.parse(b['task_date']))
                .compareTo(DateTime.parse(a['task_date']));
          });

          return ListView(
            padding: const EdgeInsets.all(12),
            children: tasks.map((task) {
              final applierChatItems = chatRoomModel
                  .where((applierChatItem) =>
                      applierChatItem['taskId'] == task['id'])
                  .toList();
              return _taskCardWithapplierChatItems(task, applierChatItems);
            }).toList(),
          );
        }
      },
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
          const Icon(Icons.timer, color: Colors.purple, size: 18),
          const SizedBox(width: 6),
          const Text('Task completion requested. Please confirm before: ',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              )),
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
}

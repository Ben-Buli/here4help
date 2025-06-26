import 'package:flutter/material.dart';
import 'package:here4help/task/services/global_task_list.dart';
import 'package:here4help/chat/services/global_chat_room.dart';
import 'dart:async';
import 'package:flutter/scheduler.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.data});
  final Map<String, dynamic> data; // 接收傳入的資料

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  // 狀態名稱映射
  final Map<String, String> statusString = const {
    'open': 'Open',
    'in_progress': 'In Progress',
    'in_progress_tasker': 'In Progress (Tasker)',
    'applying_tasker': 'Applying (Tasker)',
    'rejected_tasker': 'Rejected (Tasker)',
    'pending_confirmation': 'Pending Confirmation',
    'pending_confirmation_tasker': 'Pending Confirmation (Tasker)',
    'dispute': 'Dispute',
    'completed': 'Completed',
    'completed_tasker': 'Completed (Tasker)',
  };
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _messages = [];
  // 模擬任務狀態
  String taskStatus = 'pending confirmation';

  late String joinTime;

  // 新增狀態變數
  late Duration remainingTime;
  late DateTime taskPendingStart;
  late DateTime taskPendingEnd;
  late Ticker countdownTicker;
  bool countdownCompleted = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    joinTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    // 加強 pendingStart 處理，若不存在自動補上
    if (widget.data['task']['status'] ==
        statusString['pending_confirmation_tasker']) {
      taskPendingStart =
          DateTime.tryParse(widget.data['task']['pendingStart'] ?? '') ??
              DateTime.now();
      widget.data['task']['pendingStart'] = taskPendingStart.toIso8601String();
      taskPendingEnd = taskPendingStart.add(const Duration(seconds: 5));
      remainingTime = taskPendingEnd.difference(DateTime.now());
      countdownTicker = Ticker(_onTick)..start();
    } else if (widget.data['task']['status'] ==
        statusString['pending_confirmation']) {
      taskPendingStart =
          DateTime.tryParse(widget.data['task']['pendingStart'] ?? '') ??
              DateTime.now();
      widget.data['task']['pendingStart'] = taskPendingStart.toIso8601String();
      taskPendingEnd = taskPendingStart.add(const Duration(days: 7));
      remainingTime = taskPendingEnd.difference(DateTime.now());
      countdownTicker = Ticker(_onTick)..start();
    } else {
      remainingTime = const Duration();
    }
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    final remain = taskPendingEnd.difference(now);
    if (remain <= Duration.zero && !countdownCompleted) {
      countdownCompleted = true;
      countdownTicker.stop();
      setState(() {
        remainingTime = Duration.zero;
        widget.data['task']['status'] = statusString['completed_tasker'];
      });
      GlobalTaskList().updateTaskStatus(
        widget.data['task']['id'].toString(),
        statusString['completed_tasker']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The countdown has ended. The task is now automatically completed and the payment has been successfully transferred. Thank you!',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else if (!countdownCompleted) {
      setState(() {
        remainingTime = remain > Duration.zero ? remain : Duration.zero;
      });
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && mounted) {
      setState(() {
        _messages.add(text);
      });
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    if (widget.data['task']['status'] ==
            statusString['pending_confirmation_tasker'] ||
        widget.data['task']['status'] == statusString['pending_confirmation']) {
      countdownTicker.dispose();
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionReply = widget.data['room']['questionReply'] ?? '';
    final room = widget.data['room'];
    final applier = widget.data['room'];
    final List<dynamic> sentMessages = room['sentMessages'] ?? [];

    int totalItemCount = (questionReply.isNotEmpty ? 1 : 0) +
        sentMessages.length +
        _messages.length;

    Widget buildQuestionReplyBubble(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(
                    (room['user']?['name'] ?? applier['name'] ?? 'U')[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 235, 241, 249),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text),
                        // Text(
                        //   joinTime,
                        //   style:
                        //       const TextStyle(fontSize: 10, color: Colors.grey),
                        // ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            child: Text(
                                              (room['name'] ?? 'U')[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            room['name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star,
                                                  color: Color.fromARGB(
                                                      255, 255, 187, 0),
                                                  size: 16),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${room['rating'] ?? 0.0}',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '(${room['reviewsCount'] ?? 0} reviews)',
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        Center(
                                            child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                          child: const Text('Understand'),
                                        )),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: const Text('View Resume')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildApplierBubble(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(
                    (room['user']?['name'] ?? applier['name'] ?? 'U')[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 235, 241, 249),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(text),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildMyMessageBubble(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0), // 上下間距
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, // 我的訊息背景色
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(text),
                    const SizedBox(height: 4),
                    // Text(
                    //   joinTime,
                    //   style: const TextStyle(fontSize: 10, color: Colors.grey),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isInputDisabled =
        widget.data['task']['status'] == statusString['completed'] ||
            widget.data['task']['status'] == statusString['rejected_tasker'] ||
            widget.data['task']['status'] == statusString['completed_tasker'];
    // --- ALERT BAR SWITCH-CASE 重構 ---
    // 預設 alert bar 不會顯示，只有在特定狀態下才顯示
    Widget? alertContent;
    switch (widget.data['task']['status']) {
      case 'Applying (Tasker)':
        alertContent = const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Waiting for poster to respond to your application.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        );
        break;
      case 'Rejected (Tasker)':
        alertContent = const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Unfortunately, the poster has chosen another candidate or declined your application.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        );
        break;
      case 'Pending Confirmation (Tasker)':
        alertContent = Column(
          children: [
            Text(
              '⏰ ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24).toString().padLeft(2, '0')}:${remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'If the poster does not confirm within 7 days, the task will be automatically marked as completed and the payment will be transferred.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
        break;
      case 'Pending Confirmation':
        alertContent = Column(
          children: [
            Text(
              '⏰ ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24).toString().padLeft(2, '0')}:${remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} until auto complete',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Dear Poster, please confirm as soon as possible that the Tasker has completed the task. Otherwise, after the countdown ends, the payment will be automatically transferred to the Tasker.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
        break;
      default:
        // 預設 alertContent 為 null, 不顯示 alert bar
        alertContent = null;
    }
    // --- END ALERT BAR SWITCH-CASE ---

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.data['task']['title'] ?? 'Chat',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              widget.data['room']['name'] ?? 'Applier',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.blue.shade100,
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // alertBar 置於 AppBar 下方
          if (alertContent != null)
            Container(
              color: Colors.grey[100],
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: alertContent,
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: totalItemCount,
              itemBuilder: (context, index) {
                if (questionReply.isNotEmpty && index == 0) {
                  return buildQuestionReplyBubble(questionReply);
                }

                int adjustedIndex = index - (questionReply.isNotEmpty ? 1 : 0);

                if (adjustedIndex < sentMessages.length) {
                  final messageData = sentMessages[adjustedIndex];
                  final isString = messageData is String;
                  final messageText = isString
                      ? messageData
                      : (messageData['message'] ?? '').toString();
                  return buildApplierBubble(messageText);
                }

                int myMessageIndex = adjustedIndex - sentMessages.length;
                if (myMessageIndex < _messages.length) {
                  return buildMyMessageBubble(_messages[myMessageIndex]);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          // 保持原本的 status banner 在底部
          Container(
            color:
                _getStatusBackgroundColor(widget.data['task']['status'] ?? ''),
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              widget.data['task']['status'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _getStatusChipColor(widget.data['task']['status'] ?? ''),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(
            height: 1,
            thickness: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: _buildActionButtonsByStatus()
                .map((e) => Expanded(child: e))
                .toList(),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !isInputDisabled,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        if (!isInputDisabled) _sendMessage();
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: isInputDisabled
                            ? (widget.data['task']['status'] == 'Completed'
                                ? 'This task is completed'
                                : 'This task was rejected')
                            : 'Type a message',
                        hintStyle: TextStyle(
                          color: isInputDisabled ? Colors.grey : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: isInputDisabled ? Colors.grey : Colors.blue,
                  ),
                  onPressed: isInputDisabled ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  // Store applierChatItems in state for Accept button logic
  List<Map<String, dynamic>> applierChatItems = [];

  List<Widget> _buildActionButtonsByStatus() {
    final status = (widget.data['task']['status'] ?? '').toString();
    final Map<String, List<Map<String, dynamic>>> statusActions = {
      statusString['open']!: [
        {'icon': Icons.check, 'label': 'Accept'},
      ],
      statusString['in_progress']!: [
        {'icon': Icons.payment, 'label': 'Pay'},
        {'icon': Icons.volume_off, 'label': 'Silence'},
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      statusString['in_progress_tasker']!: [
        {'icon': Icons.check_circle, 'label': 'Completed'},
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      statusString['applying_tasker']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      statusString['rejected_tasker']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      statusString['pending_confirmation']!: [
        {'icon': Icons.check, 'label': 'Confirm'},
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      statusString['pending_confirmation_tasker']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      statusString['dispute']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      statusString['completed']!: [
        {'icon': Icons.attach_money, 'label': 'Paid'},
        {'icon': Icons.reviews, 'label': 'Reviews'},
      ],
      statusString['completed_tasker']!: [
        {'icon': Icons.reviews, 'label': 'Reviews'},
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
    };

    final actions = statusActions[status] ?? [];

    return actions
        .map((action) => _actionButton(
              action['icon'],
              action['label'],
              () {
                // Accept button logic with double confirm dialog
                if (action['label'] == 'Accept') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Double Check'),
                      content: const Text(
                          'Are you sure you want to accept this applier for this task?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            GlobalTaskList().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              statusString['in_progress']!,
                            );
                            GlobalChatRoom().removeRoomsByTaskIdExcept(
                              widget.data['task']['id'].toString(),
                              widget.data['room']['roomId'].toString(),
                            );
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Task accepted. Now in progress.')),
                            );
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                } else if (action['label'] == 'Confirm') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Double Check'),
                      content: const Text(
                          'Are you sure you want to confirm this task?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            GlobalTaskList globalTaskList = GlobalTaskList();
                            globalTaskList.updateTaskStatus(
                              widget.data['room']['taskId'].toString(),
                              statusString['completed']!,
                            );
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Task confirmed! Salary paid to the creator.')),
                            );
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                } else if (action['label'] == 'Pay') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Double Check'),
                      content: const Text(
                          'Are you sure you want to complete this task with payment?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            GlobalTaskList().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              statusString['completed']!,
                            );
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Task marked as completed with payment.')),
                            );
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                } else if (action['label'] == 'Completed') {
                  // In Progress (Tasker) 的 Completed 按鈕功能
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Double Check'),
                      content: const Text(
                          'Are you sure you have completed this task?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // 在切換到 pending_confirmation_tasker 狀態時，加入 pendingStart 記錄
                            widget.data['task']['pendingStart'] =
                                DateTime.now().toIso8601String();
                            GlobalTaskList().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              statusString['pending_confirmation_tasker']!,
                            );
                            // 重新初始化倒數
                            setState(() {
                              taskPendingStart = DateTime.parse(
                                  widget.data['task']['pendingStart']);
                              taskPendingEnd = taskPendingStart
                                  .add(const Duration(seconds: 5));
                              remainingTime =
                                  taskPendingEnd.difference(DateTime.now());
                              countdownCompleted = false;
                              countdownTicker = Ticker(_onTick)..start();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Waiting for poster confirmation.')),
                            );
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                } else {
                  // TODO: Define other button behaviors here
                }
              },
            ))
        .toList();
  }
}

Color _getStatusChipColor(String status) {
  switch (status) {
    case 'Open':
      return Colors.blue[800]!;
    case 'In Progress':
      return Colors.orange[800]!;
    case 'In Progress (Tasker)':
      return Colors.orange[800]!;
    case 'Applying (Tasker)':
      return Colors.blue[800]!;
    case 'Rejected (Tasker)':
      return Colors.grey[800]!;
    case 'Dispute':
      return Colors.red[800]!;
    case 'Pending Confirmation':
      return Colors.purple[800]!;
    case 'Pending Confirmation (Tasker)':
      return Colors.purple[800]!;
    case 'Completed':
      return Colors.grey[800]!;
    case 'Completed (Tasker)':
      return Colors.grey[800]!;
    default:
      return Colors.grey[800]!;
  }
}

Color _getStatusBackgroundColor(String status) {
  switch (status) {
    case 'Open':
      return Colors.blue[50]!;
    case 'In Progress':
      return Colors.orange[50]!;
    case 'In Progress (Tasker)':
      return Colors.orange[50]!;
    case 'Applying (Tasker)':
      return Colors.blue[50]!;
    case 'Rejected (Tasker)':
      return Colors.grey[200]!;
    case 'Dispute':
      return Colors.red[50]!;
    case 'Pending Confirmation':
      return Colors.purple[50]!;
    case 'Pending Confirmation (Tasker)':
      return Colors.purple[50]!;
    case 'Completed':
      return Colors.grey[200]!;
    case 'Completed (Tasker)':
      return Colors.grey[200]!;
    default:
      return Colors.grey[200]!;
  }
}

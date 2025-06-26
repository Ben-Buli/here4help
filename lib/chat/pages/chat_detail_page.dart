import 'package:flutter/material.dart';
import 'package:here4help/task/services/global_task_list.dart';
import 'package:here4help/chat/services/global_chat_room.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.data});
  final Map<String, dynamic> data; // 接收傳入的資料

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _messages = [];
  // 模擬任務狀態
  String taskStatus = 'pending confirmation';

  late String joinTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    joinTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    Future.delayed(Duration.zero, () {
      _focusNode.requestFocus();
    });
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

    final isCompleted = widget.data['task']['status'] == 'Completed';
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
                      enabled: !isCompleted,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        if (!isCompleted) _sendMessage();
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: isCompleted
                            ? 'This task is completed'
                            : 'Type a message',
                        hintStyle: TextStyle(
                          color: isCompleted ? Colors.grey : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: isCompleted ? Colors.grey : Colors.blue,
                  ),
                  onPressed: isCompleted ? null : _sendMessage,
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
      'Open': [
        {'icon': Icons.check, 'label': 'Accept'},
        // {'icon': Icons.cancel, 'label': 'Reject'},
      ],
      'In Progress': [
        {'icon': Icons.payment, 'label': 'Pay'},
        {'icon': Icons.volume_off, 'label': 'Silence'},
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      'Pending Confirmation': [
        {'icon': Icons.check, 'label': 'Confirm'},
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      'Dispute': [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      'Completed': [
        {'icon': Icons.attach_money, 'label': 'Paid'},
        {'icon': Icons.reviews, 'label': 'Reviews'},
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

                            // 更新 GlobalTaskList 的任務狀態
                            GlobalTaskList().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              'In Progress',
                            );

                            // 移除其他聊天室
                            GlobalChatRoom().removeRoomsByTaskIdExcept(
                              widget.data['task']['id'].toString(),
                              widget.data['room']['roomId'].toString(),
                            );

                            // 刷新界面
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
                              'Completed',
                            );
                            setState(() {}); // 刷新界面
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
                              'Completed',
                            );
                            setState(() {}); // 更新畫面
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

Color _getStatusBackgroundColor(String status) {
  switch (status) {
    case 'Open':
      return Colors.blue[50]!;
    case 'In Progress':
      return Colors.orange[50]!;
    case 'Dispute':
      return Colors.red[50]!;
    case 'Pending Confirmation':
      return Colors.purple[50]!;
    case 'Completed':
      return Colors.grey[200]!;
    default:
      return Colors.grey[200]!;
  }
}

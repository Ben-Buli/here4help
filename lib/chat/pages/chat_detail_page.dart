import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/chat/services/global_chat_room.dart';
import 'package:flutter/scheduler.dart';
import 'package:here4help/constants/task_status.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.data});
  final Map<String, dynamic> data; // 接收傳入的資料

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  // 統一應徵者訊息的背景色
  final Color applierBubbleColor = Colors.grey.shade100;

  Map<String, dynamic> _getProgressData(String status) {
    return TaskStatus.getProgressData(status);
  }

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, String>> _messages = [];
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
        TaskStatus.statusString['pending_confirmation_tasker']) {
      taskPendingStart =
          DateTime.tryParse(widget.data['task']['pendingStart'] ?? '') ??
              DateTime.now();
      widget.data['task']['pendingStart'] = taskPendingStart.toIso8601String();
      taskPendingEnd = taskPendingStart.add(const Duration(seconds: 5));
      remainingTime = taskPendingEnd.difference(DateTime.now());
      countdownTicker = Ticker(_onTick)..start();
    } else if (widget.data['task']['status'] ==
        TaskStatus.statusString['pending_confirmation']) {
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
        widget.data['task']['status'] =
            TaskStatus.statusString['completed_tasker'];
      });
      TaskService().updateTaskStatus(
        widget.data['task']['id'].toString(),
        TaskStatus.statusString['completed_tasker']!,
        statusCode: 'completed',
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
      final now = DateTime.now();
      final formattedTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      setState(() {
        _messages.add({'text': text, 'time': formattedTime});
      });
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    if (widget.data['task']['status'] ==
            TaskStatus.statusString['pending_confirmation_tasker'] ||
        widget.data['task']['status'] ==
            TaskStatus.statusString['pending_confirmation']) {
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
    print(applier);
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
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: applierBubbleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Center(
                                            child: Text('Resume Preview')),
                                        actions: [
                                          Center(
                                            child: TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('CLOSE'),
                                            ),
                                          ),
                                        ],
                                        insetPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 24.0,
                                                vertical: 24.0),
                                        contentPadding:
                                            const EdgeInsets.fromLTRB(
                                                24.0, 20.0, 24.0, 0),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundImage: room['user']
                                                              ?['avatar_url'] !=
                                                          null
                                                      ? (room['user']![
                                                                  'avatar_url']
                                                              .startsWith(
                                                                  'http')
                                                          ? NetworkImage(
                                                              room['user']![
                                                                  'avatar_url'])
                                                          : AssetImage(room[
                                                                      'user']![
                                                                  'avatar_url'])
                                                              as ImageProvider)
                                                      : null,
                                                  child: room['user']
                                                              ?['avatar_url'] ==
                                                          null
                                                      ? Text(
                                                          (room['user']?[
                                                                      'name'] ??
                                                                  applier[
                                                                      'name'] ??
                                                                  'U')[0]
                                                              .toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 20),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 16),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      applier['name'] ??
                                                          'Applier',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.star,
                                                            color: Colors.amber,
                                                            size: 16),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                            '${applier['rating'] ?? 4.2}'),
                                                        Text(
                                                            ' (${applier['cooment'] ?? '16 comments'})'),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                  'Self-recommendation (optional)',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            TextField(
                                              controller: TextEditingController(
                                                  text: room['user']
                                                                  ?['selfIntro']
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? room['user']![
                                                          'selfIntro']
                                                      : 'I am reliable, experienced, and proficient in communication. I have handled similar tasks before and am confident in my ability to deliver quality work.'),
                                              readOnly: true,
                                              maxLines: 4,
                                              decoration: const InputDecoration(
                                                hintText:
                                                    'Tell us about yourself',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                  'Can you speak English?',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            TextField(
                                              controller: TextEditingController(
                                                  text: room['user']?[
                                                                  'languageReply']
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? room['user']![
                                                          'languageReply']
                                                      : 'Yes, I can speak English fluently.'),
                                              readOnly: true,
                                              maxLines: 2,
                                              decoration: const InputDecoration(
                                                hintText: 'Write your answer',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('View Resume'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        joinTime,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
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
                  backgroundImage: room['user']?['avatar_url'] != null
                      ? (room['user']!['avatar_url'].startsWith('http')
                          ? NetworkImage(room['user']!['avatar_url'])
                          : AssetImage(room['user']!['avatar_url'])
                              as ImageProvider)
                      : null,
                  child: room['user']?['avatar_url'] == null
                      ? Text(
                          (room['user']?['name'] ?? applier['name'] ?? 'U')[0]
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: applierBubbleColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(text),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        joinTime,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildMyMessageBubble(Map<String, String> message) {
      final text = message['text'] ?? '';
      final time =
          message['time'] ?? DateFormat('HH:mm').format(DateTime.now());
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0), // 上下間距
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 235, 241, 249), // 我的訊息背景色
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(text),
              ),
            ),
          ],
        ),
      );
    }

    final isInputDisabled =
        widget.data['task']['status'] == TaskStatus.statusString['completed'] ||
            widget.data['task']['status'] ==
                TaskStatus.statusString['rejected_tasker'] ||
            widget.data['task']['status'] ==
                TaskStatus.statusString['completed_tasker'];
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
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(widget.data['task']['title'] ?? 'Task Info'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Task Description',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.data['task']['description'] ??
                            'No description'),
                        const SizedBox(height: 8),
                        const Text('Reward Point:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.data['task']['reward_point'] != null
                            ? 'NT\$${widget.data['task']['reward_point']}'
                            : widget.data['task']['salary'] != null
                                ? 'NT\$${widget.data['task']['salary']}'
                                : 'N/A'),
                        const SizedBox(height: 8),
                        const Text('Request Language:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            widget.data['task']['language_requirement'] ?? '—'),
                        const SizedBox(height: 8),
                        const Text('Location:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.data['task']['location'] ?? '—'),
                        const SizedBox(height: 8),
                        const Text('Task Date:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.data['task']['task_date'] ?? '—'),
                        const SizedBox(height: 8),
                        // --- Application Question section ---
                        const Text('Application Question:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            widget.data['task']['application_question'] ?? '—'),
                        const SizedBox(height: 8),
                        // --- End Application Question section ---
                        const Text('Posted by:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('UserName: ${widget.data['room']['name'] ?? '—'}'),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Color.fromARGB(255, 255, 187, 0),
                                size: 16),
                            const SizedBox(width: 4),
                            Text('${widget.data['room']['rating'] ?? 0.0}'),
                            Text(
                                ' (${widget.data['room']['reviewsCount'] ?? 0} reviews)'),
                          ],
                        )
                      ],
                    ),
                    actions: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 10,
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CLOSE'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                widget.data['task']['title'] ?? 'Chat',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.blue,
                ),
              ),
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
            color: Colors.grey,
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
              (() {
                final status = widget.data['task']['status'] ?? '';
                final progressData = _getProgressData(status);
                final progress = progressData['progress'];
                if (progress != null) {
                  final percent = (progress * 100).round();
                  return '$status ($percent%)';
                } else {
                  return status;
                }
              })(),
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

                      /// 鍵盤收起時取消焦點
                      onEditingComplete: () {
                        FocusScope.of(context).unfocus();
                      },
                      onTapOutside: (_) {
                        FocusScope.of(context).unfocus();
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
      TaskStatus.statusString['open']!: [
        {'icon': Icons.check, 'label': 'Accept'},
      ],
      TaskStatus.statusString['in_progress']!: [
        {'icon': Icons.payment, 'label': 'Pay'},
        {'icon': Icons.volume_off, 'label': 'Silence'},
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      TaskStatus.statusString['in_progress_tasker']!: [
        {'icon': Icons.check_circle, 'label': 'Completed'},
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      TaskStatus.statusString['applying_tasker']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
        {'icon': Icons.block, 'label': 'Block'},
      ],
      TaskStatus.statusString['rejected_tasker']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      TaskStatus.statusString['pending_confirmation']!: [
        {'icon': Icons.check, 'label': 'Confirm'},
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      TaskStatus.statusString['pending_confirmation_tasker']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      TaskStatus.statusString['dispute']!: [
        {'icon': Icons.article, 'label': 'Complaint'},
      ],
      TaskStatus.statusString['completed']!: [
        {'icon': Icons.attach_money, 'label': 'Paid'},
        {'icon': Icons.reviews, 'label': 'Reviews'},
      ],
      TaskStatus.statusString['completed_tasker']!: [
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
                            TaskService().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              TaskStatus.statusString['in_progress']!,
                              statusCode: 'in_progress',
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
                            TaskService taskService = TaskService();
                            taskService.updateTaskStatus(
                              widget.data['room']['taskId'].toString(),
                              TaskStatus.statusString['completed']!,
                              statusCode: 'completed',
                            );
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Task confirmed! Reward point paid to the creator.')),
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
                            TaskService().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              TaskStatus.statusString['completed']!,
                              statusCode: 'completed',
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
                            TaskService().updateTaskStatus(
                              widget.data['task']['id'].toString(),
                              TaskStatus
                                  .statusString['pending_confirmation_tasker']!,
                              statusCode: 'pending_confirmation',
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

  Color _getStatusChipColor(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    switch (displayStatus) {
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
        return Colors.brown[800]!;
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
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    switch (displayStatus) {
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
        return Colors.brown[50]!;
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
}

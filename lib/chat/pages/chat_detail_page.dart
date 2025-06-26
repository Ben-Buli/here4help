import 'package:flutter/material.dart';

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

    Widget buildApplierBubble(String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0), // 上下間距
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 235, 241, 249),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(text),
                    const SizedBox(height: 4),
                    Text(
                      joinTime,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
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
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(text),
                    const SizedBox(height: 4),
                    Text(
                      joinTime,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                  return buildApplierBubble(questionReply);
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
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (taskStatus == 'pending confirmation')
                _actionButton(Icons.payment, 'Pay', () {}),
              _actionButton(Icons.volume_off, 'Silence', () {}),
              _actionButton(Icons.article, 'Complaint', () {}),
              _actionButton(Icons.block, 'Block', () {}),
            ],
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) => _sendMessage(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type a message',
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
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
}

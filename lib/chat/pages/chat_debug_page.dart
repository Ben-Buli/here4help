import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';

class ChatDebugPage extends StatefulWidget {
  const ChatDebugPage({super.key});

  @override
  State<ChatDebugPage> createState() => _ChatDebugPageState();
}

class _ChatDebugPageState extends State<ChatDebugPage> {
  final _taskIdController = TextEditingController();
  final _posterIdController = TextEditingController();
  final _applicantIdController = TextEditingController();

  @override
  void dispose() {
    _taskIdController.dispose();
    _posterIdController.dispose();
    _applicantIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _taskIdController,
              decoration: const InputDecoration(labelText: 'taskId'),
            ),
            TextField(
              controller: _posterIdController,
              decoration:
                  const InputDecoration(labelText: 'posterId (creator_id)'),
            ),
            TextField(
              controller: _applicantIdController,
              decoration: const InputDecoration(labelText: 'applicantId'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final taskId = _taskIdController.text.trim();
                final posterId = _posterIdController.text.trim();
                final applicantId = _applicantIdController.text.trim();
                if (taskId.isEmpty || posterId.isEmpty || applicantId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('請填入 taskId/posterId/applicantId')),
                  );
                  return;
                }
                final roomId = 'task_${taskId}_pair_${posterId}_$applicantId';
                final taskService = TaskService();
                await taskService.loadTasks();
                final task = taskService.getTaskById(taskId) ??
                    {
                      'id': taskId,
                      'creator_id': int.tryParse(posterId) ?? posterId,
                      'title': 'Debug Task $taskId',
                    };
                // 確保 Socket 已初始化
                final center = NotificationCenter();
                if (center.service is! SocketNotificationService) {
                  // 嘗試以現有登入者初始化 socket
                  final me = context.read<UserService>().currentUser;
                  if (me != null) {
                    final svc = SocketNotificationService();
                    await svc.init(userId: me.id.toString());
                    await center.use(svc);
                    await svc.refreshSnapshot();
                  }
                }
                if (mounted) {
                  context.go('/chat/detail', extra: {
                    'task': task,
                    'room': {
                      'roomId': roomId,
                      'taskId': taskId,
                      'questionReply': '',
                      'sentMessages': <dynamic>[],
                    },
                  });
                }
              },
              child: const Text('Join Room'),
            ),
            const SizedBox(height: 24),
            Consumer<UserService>(
              builder: (context, userService, _) {
                final me = userService.currentUser;
                return Text('Current user: ${me?.id} ${me?.name}');
              },
            )
          ],
        ),
      ),
    );
  }
}

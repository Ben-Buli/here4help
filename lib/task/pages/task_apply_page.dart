import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:here4help/services/error_handler_service.dart';

/// 任務投遞應徵履歷表單頁面
class TaskApplyPage extends StatefulWidget {
  final Map<dynamic, dynamic> data;

  const TaskApplyPage({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  State<TaskApplyPage> createState() => _TaskApplyPageState();
}

class _TaskApplyPageState extends State<TaskApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final _selfIntroController = TextEditingController();
  final _englishController = TextEditingController();

  @override
  void dispose() {
    _selfIntroController.dispose();
    _englishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.data['userId'];
    final taskId = widget.data['taskId'];

    final userService = context.watch<UserService>();
    final currentUser = userService.currentUser;

    if (userService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentUser == null) {
      return const Center(child: Text('Failed to load user data.'));
    }

    debugPrint('Current User: ${currentUser.name}, ID: $userId');

    return FutureBuilder<Map<String, dynamic>>(
        future: _loadTask(taskId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final task = snapshot.data ?? {};
          final taskTitle = task['title'] ?? '';
          final applicationQuestion = task['application_question'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: currentUser.avatar_url.isNotEmpty
                            ? (currentUser.avatar_url.startsWith('http')
                                ? NetworkImage(currentUser.avatar_url)
                                : AssetImage(currentUser.avatar_url)
                                    as ImageProvider)
                            : null,
                        child: currentUser.avatar_url.isEmpty
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => const Icon(Icons.star,
                                      color: Colors.amber, size: 20),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('5 (16 comments)'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(taskTitle,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Task Description',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(task['description'] ??
                                  'No description available'),
                              const SizedBox(height: 12),
                              const Text('Reward:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                  '💰 ${task['reward_point'] ?? task['salary']}'),
                              const SizedBox(height: 8),
                              const Text('Request Language:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(task['language_requirement'] ?? '-'),
                              const SizedBox(height: 8),
                              const Text('Location:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(task['location'] ?? '-'),
                              const SizedBox(height: 8),
                              const Text('Task Date:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(task['task_date'] ?? '-'),
                              const SizedBox(height: 8),
                              const Text('Posted by:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text('UserName: ${task['creator_name'] ?? ''}'),
                              const Text('Rating: ⭐ 5.0 (16 reviews)'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('CLOSE'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Consumer<ThemeConfigManager>(
                      builder: (context, themeManager, child) {
                        return Text(
                          taskTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            decoration: TextDecoration.underline,
                            color: themeManager.currentTheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Self-recommendation (optional)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Write down your work-related experience,\nlanguage proficiency to improve your admission rate',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _selfIntroController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tell us about yourself.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (applicationQuestion != null) ...[
                    Text(
                      applicationQuestion,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _englishController,
                      decoration: InputDecoration(
                        hintText: 'Write your answer to the poster',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Consumer<ThemeConfigManager>(
                    builder: (context, themeManager, child) {
                      return Text(
                        'After applying, please wait patiently for the employer\'s reply.\nPolite inquiries can increase favorability.',
                        style:
                            TextStyle(color: themeManager.currentTheme.primary),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;

                          // 顯示加載中提示
                          ErrorHandlerService.showLoading(context, '正在提交應徵...');

                          try {
                            final userService = context.read<UserService>();
                            await userService.ensureUserLoaded();
                            final currentUser = userService.currentUser;
                            if (currentUser == null) {
                              ErrorHandlerService.hideCurrent(context);
                              ErrorHandlerService.showError(context, '請先登入');
                              return;
                            }

                            final taskService = TaskService();
                            final intro = _selfIntroController.text.trim();
                            final q1 = _englishController.text.trim();

                            // 組裝新格式 answers：以「問題原文」為鍵
                            final Map<String, String> answers = {};
                            if (applicationQuestion != null &&
                                applicationQuestion.trim().isNotEmpty &&
                                q1.isNotEmpty) {
                              answers[applicationQuestion.trim()] = q1;
                            }

                            // 使用聚合 API：應徵、創建聊天室、發送訊息（帶重試機制）
                            final result =
                                await ErrorHandlerService.executeWithRetry(
                              operation: () => taskService.applyForTask(
                                taskId: taskId,
                                userId: currentUser.id,
                                coverLetter: intro,
                                answers: answers.isEmpty ? null : answers,
                              ),
                              operationName: 'TaskApplication',
                              shouldRetry: (error) =>
                                  ErrorHandlerService.isNetworkError(error),
                            );

                            // 隱藏加載提示
                            ErrorHandlerService.hideCurrent(context);

                            // 顯示成功提示
                            ErrorHandlerService.showSuccess(
                                context, '應徵提交成功！正在跳轉到聊天室...');

                            // 取得任務資料
                            final task = taskService.getTaskById(taskId) ?? {};
                            final posterId = task['creator_id'] ?? 0;
                            final applicantId = currentUser.id;
                            final roomId = result['room_id']?.toString() ?? '';

                            if (mounted) {
                              // 使用真實的聊天室ID跳轉到聊天詳情頁面
                              context.go('/chat/detail', extra: {
                                'task': task,
                                'room': {
                                  'id': int.tryParse(roomId) ??
                                      0, // 使用聚合 API 返回的 room_id
                                  'roomId': roomId, // 保持字串版本以兼容現有代碼
                                  'taskId': taskId,
                                  'task_id': taskId,
                                  'creator_id': posterId,
                                  'participant_id': applicantId,
                                  'questionReply': intro,
                                  'sentMessages': <dynamic>[],
                                  // 添加當前用戶（應徵者）的資訊
                                  'user_id': currentUser.id,
                                  'user': {
                                    'id': currentUser.id,
                                    'name': currentUser.name,
                                    'avatar_url': currentUser.avatar_url,
                                  },
                                  // 參與者頭像後備（供對方視角顯示）
                                  'participant_avatar': currentUser.avatar_url,
                                  // 聊天夥伴（任務發布者）資訊
                                  'chat_partner': {
                                    'id': task['creator_id'],
                                    'name':
                                        task['creator_name'] ?? 'Task Creator',
                                    'avatar_url': task['creator_avatar'] ?? '',
                                  },
                                },
                              });
                            }
                          } catch (e) {
                            // 隱藏加載提示
                            ErrorHandlerService.hideCurrent(context);

                            // 記錄錯誤
                            await ErrorHandlerService.logError(
                              e.toString(),
                              context: 'TaskApplication',
                            );

                            // 顯示用戶友好的錯誤信息
                            final errorMessage =
                                ErrorHandlerService.getUserFriendlyMessage(
                              e is Exception ? e : Exception(e.toString()),
                            );
                            ErrorHandlerService.showError(
                                context, errorMessage);
                          }
                        },
                        child: const Text('Confirm Submission'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }

  Future<Map<String, dynamic>> _loadTask(String taskId) async {
    final taskService = TaskService();
    await taskService.loadTasks();
    return taskService.getTaskById(taskId) ?? {};
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/services/theme_config_manager.dart';

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
                        backgroundImage: currentUser.avatar_url != null
                            ? (currentUser.avatar_url.startsWith('http')
                                ? NetworkImage(currentUser.avatar_url)
                                : AssetImage(currentUser.avatar_url)
                                    as ImageProvider)
                            : null,
                        child: currentUser.avatar_url == null
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: const Text(
                                  'You have successfully applied.\nPlease wait patiently for the task poster’s response',
                                  textAlign: TextAlign.center,
                                ),
                                actionsAlignment: MainAxisAlignment.center,
                                actions: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(); // 關閉 Dialog
                                      context.go('/task'); // 前往 Task List
                                    },
                                    child: const Text('Back to Task List'),
                                  ),
                                ],
                              ),
                            );
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

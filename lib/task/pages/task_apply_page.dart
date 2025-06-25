import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/task/services/global_task_list.dart';
import 'package:go_router/go_router.dart';

/// 任務投遞應徵履歷表單頁面
class TaskApplyPage extends StatefulWidget {
  final Map<String, dynamic> data;

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

    final globalTaskList = GlobalTaskList();
    final task = globalTaskList.tasks.firstWhere(
      (t) => t['id'] == taskId,
      orElse: () => {},
    );

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
                      ? NetworkImage(currentUser.avatar_url)
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
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        elevation: 0,
                      ),
                      child: const Text('Edit My Resume'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) =>
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('5 (16 comments)'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              taskTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                decoration: TextDecoration.underline,
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
                hintText: 'Tell us about yourself',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            const Text(
              'After applying, please wait patiently for the employer\'s reply.\nPolite inquiries can increase favorability.',
              style: TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Preview Resume'),
                ),
                const SizedBox(width: 8),
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
  }
}

// task_list_page.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/global_task_list.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadGlobalTasks();
  }

  Future<void> _loadGlobalTasks() async {
    final globalTaskList = GlobalTaskList();
    await globalTaskList.loadTasks();
    setState(() {
      tasks = globalTaskList.tasks;
    });
  }

  /// 彈出任務詳情對話框
  void _showTaskDetailDialog(Map<String, dynamic> task) {
    final taskPrimaryLanguage = task['language_requirement'] ?? '-';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        task['title'] ?? 'Task Details',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Task Description',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(task['description'] ?? 'No description.'),
                    const SizedBox(height: 12),
                    Text.rich(TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Salary: \n',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: 'NT\$${task['salary'] ?? "0"}'),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Request Language: \n',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: taskPrimaryLanguage),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Location: \n',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: task['location'] ?? '-'),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Task Date: \n',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: task['task_date'] ?? '-'),
                      ],
                    )),
                    const SizedBox(height: 8),
                    Text.rich(TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Posted by: \n',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                'UserName: ${task['creator_name'] ?? 'N/A'}\n'),
                        const TextSpan(text: 'Rating: ⭐️ 4.7 (18 reviews)'),
                      ],
                    )),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            debugPrint('CLOSE button pressed');
                            if (Navigator.canPop(dialogContext)) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          child: const Text('CLOSE'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final userService = Provider.of<UserService>(
                                context,
                                listen: false);
                            await userService.ensureUserLoaded();

                            final userId = userService.currentUser?.id;

                            if (userId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('User not logged in.')),
                              );
                              return;
                            }

                            debugPrint(
                                'APPLY button pressed for userId: $userId');
                            final data = {
                              'userId': userId,
                              'taskId': task['id'],
                            };

                            debugPrint(
                                'Navigating to TaskApplyPage with data: $data');

                            if (task['id'] != null) {
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.pop(dialogContext);
                              }
                              context.push('/task/apply', extra: data);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Task ID not found. Please check.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: const Text('APPLY NOW'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final date = task['task_date'];
                final dateLabel = (date != null)
                    ? DateFormat('MM/dd')
                        .format(DateTime.tryParse(date) ?? DateTime.now())
                    : '';

                final userName = task['creator_name'] ?? 'N/A Poster';

                return GestureDetector(
                  onTap: () => _showTaskDetailDialog(task),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(task['title'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                            const Icon(Icons.more_vert, size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14),
                            const SizedBox(width: 4),
                            Text(userName,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(Icons.access_time, size: 14),
                            const SizedBox(width: 4),
                            Text(dateLabel,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14),
                            const SizedBox(width: 4),
                            Text(task['location'] ?? '',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(Icons.monetization_on_outlined,
                                size: 14),
                            const SizedBox(width: 4),
                            Text('NT\$${task['salary']} / hour',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.chat_outlined, size: 14),
                            const SizedBox(width: 4),
                            Text(task['language_requirement'] ?? '-',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.local_fire_department,
                                color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text("Popular", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 12),
                            Icon(Icons.schedule, size: 14),
                            SizedBox(width: 4),
                            Text("1 day ago", style: TextStyle(fontSize: 12)),
                            Spacer(),
                            Icon(Icons.bookmark_border, color: Colors.blue),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

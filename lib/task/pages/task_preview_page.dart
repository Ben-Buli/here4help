// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/constants/app_colors.dart';

class TaskPreviewPage extends StatefulWidget {
  const TaskPreviewPage({super.key});

  @override
  State<TaskPreviewPage> createState() => _TaskPreviewPageState();
}

class _TaskPreviewPageState extends State<TaskPreviewPage> {
  Map<String, dynamic>? taskData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaskData();
  }

  Future<void> _loadTaskData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskDataString = prefs.getString('taskData');

      if (taskDataString != null) {
        final data = jsonDecode(taskDataString) as Map<String, dynamic>;
        setState(() {
          taskData = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        // 如果沒有資料，返回上一頁
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No task data found')),
          );
          context.pop();
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading task data: $e')),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (taskData == null) {
      return const Scaffold(
        body: Center(
          child: Text('No task data available'),
        ),
      );
    }

    // 設置預設值
    taskData!['id'] = UniqueKey().toString();
    taskData!['acceptor_id'] = '';
    taskData!['status'] = 'Open'; // 預設狀態為 Open
    taskData!['creator_confirmed'] = '0';
    taskData!['acceptor_confirmed'] = '0';
    taskData!['cancel_reason'] = '';
    taskData!['fail_reason'] = '';
    taskData!['creator_name'] = taskData!['creator_name'] ?? 'Anonymous';
    taskData!['description'] =
        taskData!['description'] ?? 'No description provided';
    taskData!['updated_at'] = DateTime.now().toIso8601String();
    taskData!['created_at'] = DateTime.now().toIso8601String();

    // Extract data with fallback values
    final title = taskData!['title']?.toString() ?? 'N/A';
    final location = taskData!['location']?.toString() ?? 'N/A';
    final salary = taskData!['salary']?.toString() ?? 'N/A';
    final date = taskData!['task_date']?.toString() ?? 'N/A';
    final creatorName = taskData!['creator_name']?.toString() ?? 'N/A';
    final creatorAvatarUrl = taskData!['avatar_url']?.toString();

    final languageRequirement =
        taskData!['language_requirement']?.toString() ?? 'N/A';

    // Render preview page
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Card
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width < 600
                        ? MediaQuery.of(context).size.width * 0.95
                        : MediaQuery.of(context).size.width * 0.4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if ((taskData!['description']?.toString().trim() ?? '')
                            .isNotEmpty) ...[
                          const Text(
                            'Task Description',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(taskData!['description']!.toString().trim()),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Application Question:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...((taskData!['application_question']?.toString() ??
                                'No description provided')
                            .split('|')
                            .asMap()
                            .entries
                            .map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child:
                                      Text('${entry.key + 1}. ${entry.value}'),
                                ))
                            .toList()),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Reward: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: salary),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Task Time: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: date),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Location: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: location),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Username: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: creatorName),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Language Requirement: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: languageRequirement),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop(); // Use root navigator to close only the dialog
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('CLOSE'),
                            ),
                            ElevatedButton(
                              onPressed: null, // Disabled Apply button
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.5),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('APPLY NOW'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth;
                      return Wrap(
                        spacing: 0,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16),
                                const SizedBox(width: 6),
                                Text(creatorName),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 6),
                                Text(date),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 16),
                                const SizedBox(width: 6),
                                Text(location),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.attach_money, size: 16),
                                const SizedBox(width: 6),
                                Text('$salary / hour'),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.language, size: 16),
                                const SizedBox(width: 6),
                                Text(languageRequirement.replaceAll(',', ', ')),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Instruction text
          const Text(
            'Review your task details. When ready, tap "Confirm & Post" to publish.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Warning and submit button
          const Divider(),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please abide by The platform regulations and do not post false fraudulent information. Violators will be held legally responsible.',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Post'),
                    content:
                        const Text('Are you sure you want to post this task?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final taskService = TaskService();

                  try {
                    // 創建任務
                    final success = await taskService.createTask(taskData!);

                    if (success) {
                      // 清除 SharedPreferences 中的資料
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('taskData');

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Task posted successfully!')),
                        );
                        // 導航到任務大廳並刷新
                        context.go('/task');
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Failed to post task: ${taskService.error ?? 'Unknown error'}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error posting task: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task post cancelled.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirm & Post',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

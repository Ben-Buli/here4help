// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/global_task_list.dart';

class TaskPreviewPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const TaskPreviewPage({super.key, required this.data});

  @override
  State<TaskPreviewPage> createState() => _TaskPreviewPageState();
}

class _TaskPreviewPageState extends State<TaskPreviewPage> {
  @override
  Widget build(BuildContext context) {
    debugPrint('Received data in TaskPreviewPage: ${widget.data}');

    widget.data['id'] = UniqueKey().toString();
    widget.data['acceptor_id'] = '';
    widget.data['status'] = 'open';
    widget.data['creator_confirmed'] = '0';
    widget.data['acceptor_confirmed'] = '0';
    widget.data['cancel_reason'] = '';
    widget.data['fail_reason'] = '';
    widget.data['updated_at'] = DateTime.now().toIso8601String();
    widget.data['created_at'] = DateTime.now().toIso8601String();

    // Extract data with fallback values
    final title = widget.data['title']?.toString() ?? 'N/A';
    final location = widget.data['location']?.toString() ?? 'N/A';
    final salary = widget.data['salary']?.toString() ?? 'N/A';
    final date = widget.data['task_date']?.toString() ?? 'N/A';
    final requestLanguage =
        (widget.data['request_language'] as List<String>?) ?? [];
    final creatorName = widget.data['creator_name']?.toString() ?? 'N/A';
    final creatorAvatarUrl = widget.data['avatar_url']?.toString();
    final languageRequirement =
        widget.data['language_requirement']?.toString() ?? 'N/A';

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
                        const Text(
                          'Task Description',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.data['application_question']?.toString() ??
                            'No description provided'),
                        const SizedBox(height: 12),
                        Text('Reward: $salary'),
                        Text('Task Time: $date'),
                        Text('Location: $location'),
                        Text('Username: $creatorName'),
                        Text('Language Requirement: $languageRequirement'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop(); // Use root navigator to close only the dialog
                              },
                              child: const Text('CLOSE'),
                            ),
                            const ElevatedButton(
                              onPressed: null, // Disabled Apply button
                              child: Text('APPLY NOW'),
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
              padding: const EdgeInsets.all(12),
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
                  Text(title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      )),
                  const SizedBox(height: 12),

                  // User Name and Date
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: (creatorAvatarUrl != null &&
                                creatorAvatarUrl.isNotEmpty)
                            ? NetworkImage(creatorAvatarUrl)
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: (creatorAvatarUrl == null ||
                                creatorAvatarUrl.isEmpty)
                            ? const Icon(Icons.person,
                                size: 16, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(creatorName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          )),
                      const Spacer(),
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 4),
                      Text(date),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location and Salary
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Text(location),
                      const Spacer(),
                      const Icon(Icons.attach_money, size: 16),
                      const SizedBox(width: 4),
                      Text('$salary / hour'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Languages as Tags
                  Row(
                    children: [
                      const Icon(Icons.language, size: 16),
                      const SizedBox(width: 4),
                      Text('Languages: $languageRequirement'),
                    ],
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
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final globalTaskList = GlobalTaskList();

                  /// 送出任務到全域任務列表
                  globalTaskList.loadTasks(); // 確保載入任務列表
                  globalTaskList.addTask(widget.data);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task posted successfully!')),
                  );

                  if (mounted) {
                    context.go('/task');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task post cancelled.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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

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
    widget.data['id'] = UniqueKey().toString();
    widget.data['acceptor_id'] = '';
    widget.data['status'] = 'Open'; // 預設狀態為 Open
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
                        if ((widget.data['description']?.toString().trim() ??
                                '')
                            .isNotEmpty) ...[
                          const Text(
                            'Task Description',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(widget.data['description']!.toString().trim()),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Application Question:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...((widget.data['application_question']?.toString() ??
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
                      color: Colors.blue,
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
                  await globalTaskList.loadTasks();

                  // 先新增任務
                  await globalTaskList.addTask(widget.data);

                  print(GlobalTaskList().tasks.length); // 任務有無加進去
                  print(GlobalTaskList().tasks.last['title']); // 看最後一筆是否你剛剛輸入的

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Task posted successfully!')),
                    );
                    // go 改成 push 之後，資料才會即時傳到 task list
                    // 因為 go 會直接跳到 task list，沒有回到上一頁
                    context.push('/task');
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

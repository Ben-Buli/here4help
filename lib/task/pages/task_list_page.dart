// task_list_page.dart

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Map<String, dynamic>> tasks = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String searchQuery = '';
  String? selectedLocation;
  String? selectedLanguage;

  // 根據目前選擇的語言，取得可用的地點
  List<String> getAvailableLocations() {
    final filtered = tasks.where((task) {
      final language = (task['language_requirement'] ?? '').toString();
      return selectedLanguage == null || language == selectedLanguage;
    });
    return filtered
        .map((e) => (e['location'] ?? '').toString())
        .toSet()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // 根據目前選擇的地點，取得可用的語言
  List<String> getAvailableLanguages() {
    final filtered = tasks.where((task) {
      final location = (task['location'] ?? '').toString();
      return selectedLocation == null || location == selectedLocation;
    });
    return filtered
        .map((e) => (e['language_requirement'] ?? '').toString())
        .toSet()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadGlobalTasks();
    // 移除 search bar 自動 focus 功能
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalTasks() async {
    final taskService = TaskService();
    await taskService.loadTasks();

    // 新增 unreadCount 計算邏輯
    for (final task in taskService.tasks) {
      final visibleAppliers = (task['appliers'] as List<dynamic>?)
              ?.where((ap) => ap['visible'] == true)
              .toList() ??
          [];

      for (final applier in visibleAppliers) {
        applier['unreadCount'] = calculateUnreadCount(applier, task);
      }

      final status = (task['status'] ?? '').toString().toLowerCase();
      if (status.toLowerCase() == 'open') {
        task['unreadCount'] = visibleAppliers
            .map((ap) => ap['unreadCount'] as int)
            .fold(0, (prev, element) => prev + element);
      } else if (status.toLowerCase() == 'pending confirmation') {
        task['unreadCount'] = 1; // Pending confirmation adds 1 unread count
      } else if (status.toLowerCase() == 'closed' ||
          status.toLowerCase() == 'cancelled') {
        task['unreadCount'] =
            0; // Closed or cancelled tasks have no unread count
      } else {
        task['unreadCount'] = 0;
      }
    }

    setState(() {
      tasks = taskService.tasks;
    });
  }

  // 新增 unread_service 工具函式
  int calculateUnreadCount(
      Map<String, dynamic> applier, Map<String, dynamic> task) {
    final status = (task['status'] ?? '').toString().toLowerCase();

    if (status == 'pending confirmation') {
      return 1;
    }

    if (status != 'open') {
      return 0;
    }

    final questionApply = applier['questionApply'] ?? 0;
    final unreadMessages = (applier['messages'] != null)
        ? (applier['messages'] as List)
            .where((m) => m['isRead'] == false)
            .length
        : 0;

    return questionApply + unreadMessages;
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
                    const Text('Application Question',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ...((task['application_question'] ?? '')
                        .toString()
                        .split('|')
                        .where((q) => q.trim().isNotEmpty)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) =>
                            Text('${entry.key + 1}. ${entry.value.trim()}'))
                        .toList()),
                    if ((task['application_question'] ?? '')
                        .toString()
                        .trim()
                        .isEmpty)
                      const Text('No questions.'),
                    const SizedBox(height: 12),
                    Text.rich(TextSpan(
                      children: [
                        const TextSpan(
                            text: 'Reward: \n',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '💰 ${task['salary'] ?? "0"}'),
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
    // 取得根據篩選條件的可用選項
    final locations = getAvailableLocations();
    final languages = getAvailableLanguages();

    final filteredTasks = tasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final description = (task['description'] ?? '').toString().toLowerCase();
      final location = (task['location'] ?? '').toString();
      final language = (task['language_requirement'] ?? '').toString();

      final matchQuery =
          title.contains(searchQuery) || description.contains(searchQuery);
      final matchLocation =
          selectedLocation == null || location == selectedLocation;
      final matchLanguage =
          selectedLanguage == null || language == selectedLanguage;

      return matchQuery && matchLocation && matchLanguage;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    hint: const Text('Location'),
                    value: selectedLocation,
                    items: locations
                        .map((loc) => DropdownMenuItem(
                              value: loc,
                              child: Text(loc),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLocation = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    hint: const Text('Language'),
                    value: selectedLanguage,
                    items: languages
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLanguage = value;
                      });
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      searchQuery = '';
                      selectedLocation = null;
                      selectedLanguage = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredTasks.length,
              itemBuilder: (context, index) {
                final task = filteredTasks[index];
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

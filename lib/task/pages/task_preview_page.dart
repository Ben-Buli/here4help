// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:here4help/task/services/task_service.dart';

import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/services/optimized_chat_service.dart';

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
      debugPrint('🔍 開始載入任務資料...');
      final prefs = await SharedPreferences.getInstance();
      final taskDataString = prefs.getString('taskData');

      debugPrint('🔍 SharedPreferences 中的 taskData: $taskDataString');

      if (taskDataString != null) {
        final data = jsonDecode(taskDataString) as Map<String, dynamic>;
        debugPrint('✅ 任務資料解析成功:');
        debugPrint('   title: ${data['title']}');
        debugPrint('   description: ${data['description']}');
        debugPrint(
            '   reward_point: ${data['reward_point'] ?? data['salary']}');
        debugPrint('   location: ${data['location']}');
        debugPrint('   task_date: ${data['task_date']}');
        debugPrint('   language_requirement: ${data['language_requirement']}');

        setState(() {
          taskData = data;
          isLoading = false;
        });
      } else {
        debugPrint('❌ SharedPreferences 中沒有找到 taskData');
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
      debugPrint('❌ 載入任務資料失敗: $e');
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
    // 從 UserService 獲取當前用戶信息
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUser = userService.currentUser;

    // creator_name 從當前用戶獲取，送 API 將以 creator_id 為準
    final creatorName = currentUser?.name ?? 'Anonymous';
    final creatorAvatarUrl = currentUser?.avatar_url ?? '';

    taskData!['creator_name'] = creatorName;
    taskData!['avatar_url'] = creatorAvatarUrl;
    taskData!['description'] =
        taskData!['description'] ?? 'No description provided';
    taskData!['updated_at'] = DateTime.now().toIso8601String();
    taskData!['created_at'] = DateTime.now().toIso8601String();

    // Extract data with fallback values
    final title = taskData!['title']?.toString() ?? 'N/A';
    final location = taskData!['location']?.toString() ?? 'N/A';
    final rewardPoint = taskData!['reward_point']?.toString() ??
        taskData!['salary']?.toString() ??
        'N/A';
    final date = taskData!['task_date']?.toString() ?? 'N/A';

    final languageRequirement =
        taskData!['language_requirement']?.toString() ?? 'N/A';

    // 將語言代碼轉換為語言名稱
    String getLanguageDisplayName(String languageCodes,
        {bool forCard = false}) {
      if (languageCodes == 'N/A' || languageCodes.isEmpty) return 'N/A';

      List<String> names = languageCodes
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // 根據語言數量決定顯示方式
      if (names.isEmpty) return 'N/A';
      if (names.length == 1) return names.first;
      if (names.length == 2) return names.join(', ');
      if (names.length >= 3) {
        // 如果是任務卡顯示，則省略；如果是 dialog 顯示，則完整顯示
        if (forCard) {
          return '${names.first}...';
        } else {
          return names.join(', ');
        }
      }

      return names.join(', ');
    }

    final languageDisplayName =
        getLanguageDisplayName(languageRequirement, forCard: true);
    final languageDisplayNameFull =
        getLanguageDisplayName(languageRequirement, forCard: false);

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
                        Text(
                          title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                        const SizedBox(height: 8),
                        if ((taskData!['description']?.toString().trim() ?? '')
                            .isNotEmpty) ...[
                          const Text(
                            'Task Description',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            taskData!['description']!.toString().trim(),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'Application Question:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(() {
                          final questions =
                              taskData!['application_question']?.toString() ??
                                  '';
                          if (questions.isEmpty || questions.trim().isEmpty) {
                            return [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'No additional questions',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ];
                          }

                          return questions
                              .split('|')
                              .where((q) => q.trim().isNotEmpty)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '${entry.key + 1}. ${entry.value.trim()}',
                                      overflow: TextOverflow.visible,
                                      maxLines: null,
                                    ),
                                  ))
                              .toList();
                        })(),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(
                                text: 'Reward: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: rewardPoint),
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
                              TextSpan(text: languageDisplayNameFull),
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
                                backgroundColor:
                                    Provider.of<ThemeConfigManager>(context,
                                            listen: false)
                                        .effectiveTheme
                                        .primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('CLOSE'),
                            ),
                            ElevatedButton(
                              onPressed: null, // Disabled Apply button
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Provider.of<ThemeConfigManager>(context,
                                            listen: false)
                                        .effectiveTheme
                                        .primary
                                        .withOpacity(0.5),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Provider.of<ThemeConfigManager>(context,
                              listen: false)
                          .effectiveTheme
                          .primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
                                Expanded(
                                  child: Text(
                                    creatorName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    date,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
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
                                Expanded(
                                  child: Text(
                                    location,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.attach_money, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$rewardPoint / hour',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: cardWidth * 0.5,
                            child: Row(
                              children: [
                                const Icon(Icons.language, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    languageDisplayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning,
                  color: Provider.of<ThemeConfigManager>(context, listen: false)
                      .effectiveTheme
                      .error,
                  size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please abide by The platform regulations and do not post false fraudulent information. Violators will be held legally responsible.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Provider.of<ThemeConfigManager>(context, listen: false)
                            .effectiveTheme
                            .error,
                  ),
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
                          foregroundColor: Provider.of<ThemeConfigManager>(
                                  context,
                                  listen: false)
                              .effectiveTheme
                              .primary,
                        ),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Provider.of<ThemeConfigManager>(
                                  context,
                                  listen: false)
                              .effectiveTheme
                              .primary,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final taskService = TaskService();

                  try {
                    // 獲取當前用戶
                    final currentUser =
                        Provider.of<UserService>(context, listen: false)
                            .currentUser;

                    if (currentUser == null) {
                      throw Exception('用戶未登入');
                    }

                    // 準備發送到後端的數據，只包含資料庫需要的欄位
                    final Map<String, dynamic> taskDataForApi = {
                      'title': taskData!['title'] ?? '',
                      'description': taskData!['description'] ?? '',
                      'reward_point': _formatRewardPoint(
                          taskData!['reward_point'] ??
                              taskData!['salary'] ??
                              '0'),
                      'location': taskData!['location'] ?? '',
                      'task_date': taskData!['task_date'] ?? '',
                      'language_requirement':
                          taskData!['language_requirement'] ?? '',
                      // 僅送必要欄位；建立者用 creator_id（由登入用戶）
                      // 預覽中的 creator_name 僅作顯示
                      'creator_id': currentUser.id, // 確保是 int 類型
                      // 初始狀態以 status_code 傳遞
                      'status_code': 'open',
                    };

                    // Debug: 打印發送的數據
                    debugPrint('🔍 準備發送的任務數據:');
                    debugPrint('   title: ${taskDataForApi['title']}');
                    debugPrint(
                        '   description: ${taskDataForApi['description']}');
                    debugPrint(
                        '   reward_point: ${taskDataForApi['reward_point']}');
                    debugPrint('   location: ${taskDataForApi['location']}');
                    debugPrint('   task_date: ${taskDataForApi['task_date']}');
                    debugPrint(
                        '   language_requirement: ${taskDataForApi['language_requirement']}');
                    debugPrint(
                        '   creator_id: ${taskDataForApi['creator_id']} (${taskDataForApi['creator_id'].runtimeType})');
                    debugPrint(
                        '   status_code: ${taskDataForApi['status_code']}');

                    // 如果有申請問題，添加到數據中
                    if (taskData!['application_question'] != null &&
                        taskData!['application_question']
                            .toString()
                            .isNotEmpty) {
                      final questions = taskData!['application_question']
                          .toString()
                          .split(' | ');
                      taskDataForApi['application_questions'] =
                          questions.where((q) => q.trim().isNotEmpty).toList();
                      debugPrint(
                          '   application_questions: ${taskDataForApi['application_questions']}');
                    }

                    // 創建任務
                    final success =
                        await taskService.createTask(taskDataForApi);

                    if (success) {
                      // 清除 SharedPreferences 中的資料
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('taskData');

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Task posted successfully!')),
                        );

                        // 清除聊天服務的快取，確保新任務能立即顯示
                        try {
                          final chatService = OptimizedChatService();
                          chatService.clearCache();
                          debugPrint('🗑️ 已清除聊天服務快取');
                        } catch (e) {
                          debugPrint('⚠️ 清除快取失敗: $e');
                        }

                        // 導航到聊天頁面的 Posted Tasks 分頁，讓用戶看到新創建的任務
                        context.go('/chat?tab=0');
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Failed to post task: ${taskService.error ?? 'Unknown error'}'),
                            backgroundColor: Provider.of<ThemeConfigManager>(
                                    context,
                                    listen: false)
                                .effectiveTheme
                                .error,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error posting task: $e'),
                          backgroundColor: Provider.of<ThemeConfigManager>(
                                  context,
                                  listen: false)
                              .effectiveTheme
                              .error,
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
                backgroundColor:
                    Provider.of<ThemeConfigManager>(context, listen: false)
                        .effectiveTheme
                        .primary,
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

  String _formatRewardPoint(String value) {
    if (value.isEmpty) return '0';
    try {
      // 移除所有非數字字符（除了小數點）
      final cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
      if (cleanValue.isEmpty) return '0';

      final num = double.tryParse(cleanValue);
      if (num == null) return '0';
      return num.toStringAsFixed(0); // 返回整數格式
    } catch (e) {
      return '0';
    }
  }
}

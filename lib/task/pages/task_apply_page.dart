import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/task/models/resume_data.dart';
import 'package:here4help/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final List<TextEditingController> _questionControllers = [];

  @override
  void dispose() {
    _selfIntroController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
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
          final applicationQuestions = List<Map<String, dynamic>>.from(
              task['application_questions'] ?? []);

          // 確保有足夠的控制器
          while (_questionControllers.length < applicationQuestions.length) {
            _questionControllers.add(TextEditingController());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      currentUser.avatar_url.isNotEmpty
                          ? CircleAvatar(
                              radius: 30,
                              backgroundImage: ImageHelper.getAvatarImage(
                                  currentUser.avatar_url),
                              onBackgroundImageError: (exception, stackTrace) {
                                debugPrint('頭像載入錯誤: $exception');
                              },
                            )
                          : const CircleAvatar(
                              radius: 30,
                              child: Icon(Icons.person, size: 40),
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
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${task['creator_rating'] ?? 0.0} (${task['creator_reviews_count'] ?? 0} reviews)'),
                                ],
                              ),
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
                    'Self-recommendation (required)',
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Self-recommendation is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 動態生成所有 application_questions
                  ...applicationQuestions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;
                    final questionText = question['application_question'] ?? '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          questionText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _questionControllers[index],
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Write your answer to the poster',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'This field is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
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
                          try {
                            final userService = context.read<UserService>();
                            await userService.ensureUserLoaded();
                            final currentUser = userService.currentUser;
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please login first')),
                              );
                              return;
                            }

                            final taskService = TaskService();
                            final intro = _selfIntroController.text.trim();

                            // 組裝新格式 answers：以「問題原文」為鍵
                            final Map<String, String> answers = {};
                            for (int i = 0;
                                i < applicationQuestions.length;
                                i++) {
                              final question = applicationQuestions[i];
                              final questionText =
                                  question['application_question'] ?? '';
                              final answer =
                                  _questionControllers[i].text.trim();

                              if (questionText.isNotEmpty &&
                                  answer.isNotEmpty) {
                                answers[questionText] = answer;
                              }
                            }

                            await taskService.applyForTask(
                              taskId: taskId,
                              userId: currentUser.id,
                              coverLetter: intro,
                              answers: answers.isEmpty ? null : answers,
                            );

                            // 取得任務資料，用於組合聊天室 payload
                            final task = taskService.getTaskById(taskId) ?? {};
                            final posterId = task['creator_id'] ?? 0;
                            final applicantId = currentUser.id;

                            // 使用 ChatService 創建實際的聊天室
                            final chatService = ChatService();
                            final roomResult = await chatService.ensureRoom(
                              taskId: taskId,
                              creatorId: posterId,
                              participantId: applicantId,
                            );
                            final roomData = roomResult['room'];
                            final roomId = roomData['id'].toString();

                            // 應徵成功後，發送結構化的 Resume 訊息
                            try {
                              // 建立 Resume 資料結構
                              final List<ApplyResponse> applyResponses = [];
                              for (int i = 0;
                                  i < applicationQuestions.length;
                                  i++) {
                                final question = applicationQuestions[i];
                                final questionText =
                                    question['application_question'] ?? '';
                                final answer =
                                    _questionControllers[i].text.trim();

                                if (questionText.isNotEmpty &&
                                    answer.isNotEmpty) {
                                  applyResponses.add(ApplyResponse(
                                    applyQuestion: questionText,
                                    applyReply: answer,
                                  ));
                                }
                              }

                              final resumeData = ResumeData(
                                applyIntroduction: intro,
                                applyResponses: applyResponses,
                              );

                              // 只有在有內容時才發送 Resume 訊息
                              if (!resumeData.isEmpty) {
                                final resumeJsonString =
                                    resumeData.toJsonString();

                                final sendRes = await chatService.sendMessage(
                                  roomId: roomId,
                                  message: resumeJsonString,
                                  taskId: taskId,
                                  kind: 'resume', // 指定為 resume 類型
                                );

                                // 透過 Socket.IO 同步推播（若可用）
                                try {
                                  final socket = SocketService();
                                  await socket.connect();
                                  socket.sendMessage(
                                    roomId: roomId,
                                    text: resumeJsonString,
                                    messageId:
                                        sendRes['message_id']?.toString(),
                                  );
                                } catch (_) {}
                              }
                            } catch (e) {
                              // Resume 訊息失敗不阻擋流程
                              debugPrint('❌ 發送 Resume 訊息失敗: $e');
                            }

                            if (mounted) {
                              // 使用真實的聊天室ID跳轉到聊天詳情頁面
                              context.go('/chat/detail', extra: {
                                'task': task,
                                'room': {
                                  'id': roomData['id'], // 使用資料庫生成的真實 room_id
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Apply failed: $e')),
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
    try {
      // 使用 TaskService 載入任務資料（list.php 已包含 application_questions）
      final taskService = TaskService();
      await taskService.loadTasks();
      final task = taskService.getTaskById(taskId);

      if (task != null) {
        debugPrint('✅ 從 TaskService 載入任務: ${task['title']}');
        debugPrint('✅ Application questions: ${task['application_questions']}');
        return task;
      }

      // 備用方案：使用專門的 API
      debugPrint('⚠️ TaskService 中找不到任務，嘗試使用 task_edit_data API');
      final response = await http.get(
        Uri.parse(AppConfig.api('/tasks/task_edit_data.php?id=$taskId')),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ 從 task_edit_data API 載入任務資料');
          return Map<String, dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load task');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to load task');
      }
    } catch (e) {
      debugPrint('❌ 載入任務資料失敗: $e');
      return {};
    }
  }
}

// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/chat/pages/chat_detail_page.dart';
import 'package:here4help/task/services/global_task_list.dart';

enum SwipeState { none, edit, delete }

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final Map<String, SwipeState> _swipeStates = {};

  void _setSwipeState(String key, SwipeState state) {
    setState(() {
      _swipeStates.updateAll((k, v) => SwipeState.none);
      _swipeStates[key] = state;
    });
  }

  void _resetSwipeState(String key) {
    setState(() => _swipeStates[key] = SwipeState.none);
  }

  void _resetAllSwipeStates() {
    setState(() {
      _swipeStates.updateAll((k, v) => SwipeState.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    final globalTaskList = GlobalTaskList();

    return FutureBuilder(
      future: globalTaskList.loadTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          final tasks = globalTaskList.tasks;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: tasks.map((task) {
              debugPrint('Processing task: $task');
              final rawHashtags = task['hashtags'];
              debugPrint('Raw hashtags: $rawHashtags');
              final List<Widget> hashtags = [];

              if (rawHashtags != null && rawHashtags.toString().isNotEmpty) {
                for (var tag in rawHashtags.toString().split(',')) {
                  if (tag.trim().isNotEmpty) {
                    hashtags.add(Chip(label: Text(tag.trim())));
                  }
                }
              }

              return _taskCard(
                context,
                task['title'] ?? 'N/A',
                task['location'] ?? 'N/A',
                int.tryParse(task['salary'] ?? '9999') ?? 9999,
                (task['task_date'] != null &&
                        task['task_date'].toString().isNotEmpty)
                    ? DateTime.tryParse(task['task_date']) != null
                        ? DateTime.parse(task['task_date'])
                            .toIso8601String()
                            .substring(0, 10)
                        : 'N/A'
                    : 'N/A',
                task['language_requirement'] ?? 'N/A',
                hashtags,
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _taskCard(BuildContext context, String title, String school,
      int salary, String date, String language, List<Widget> tags) {
    // Use a unique key for each card for swipe state
    final String cardKey = '$title-$school-$date';
    SwipeState currentState = _swipeStates[cardKey] ?? SwipeState.none;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            double velocity = details.primaryVelocity!;
            if (velocity > 0) {
              // right swipe
              if (currentState == SwipeState.edit) {
                // Optionally show edit action
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit triggered')),
                );
                _resetSwipeState(cardKey);
              } else if (currentState == SwipeState.delete) {
                _resetSwipeState(cardKey);
              } else {
                _setSwipeState(cardKey, SwipeState.edit);
              }
            } else {
              // left swipe
              if (currentState == SwipeState.delete) {
                // Confirm delete
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: const Text('Are you sure to delete this task?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task deleted')),
                          );
                        },
                        child: const Text('Delete'),
                      )
                    ],
                  ),
                );
                _resetSwipeState(cardKey);
              } else if (currentState == SwipeState.edit) {
                _resetSwipeState(cardKey);
              } else {
                _setSwipeState(cardKey, SwipeState.delete);
              }
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Background actions
                if (currentState == SwipeState.delete)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 80,
                      color: Colors.red,
                      child: const Center(
                        child: Text('Delete',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                if (currentState == SwipeState.edit)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 80,
                      color: Colors.blue,
                      child: const Center(
                        child:
                            Text('Edit', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                // Main card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.translationValues(
                    currentState == SwipeState.edit
                        ? 80
                        : (currentState == SwipeState.delete ? -80 : 0),
                    0,
                    0,
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  size: 16, color: Colors.grey[700]),
                              Text(
                                  ' $school   💰 $salary   📅 $date   🌐 $language'),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            children: tags,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatEntry(BuildContext context, String key, String name,
      double rating, String msg, String date) {
    SwipeState currentState = _swipeStates[key] ?? SwipeState.none;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          double velocity = details.primaryVelocity!;

          if (velocity > 0) {
            // 右滑
            if (currentState == SwipeState.edit) {
              _resetSwipeState(key);
            } else {
              _setSwipeState(key, SwipeState.edit);
            }
          } else {
            // 左滑
            if (currentState == SwipeState.delete) {
              _resetSwipeState(key);
            } else {
              _setSwipeState(key, SwipeState.delete);
            }
          }
        },
        child: Stack(
          children: [
            // 背景功能
            if (currentState == SwipeState.delete)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 180,
                  color: Colors.red,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionButton('Read', Colors.white, () {
                        _resetSwipeState(key);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Marked as read: $name')),
                        );
                      }),
                      _actionButton('Hide', Colors.white, () {
                        _resetSwipeState(key);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Chat hidden: $name')),
                        );
                      }),
                      _actionButton('Delete', Colors.white, () {
                        _resetSwipeState(key);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Deleted $name')),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            if (currentState == SwipeState.edit)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 120,
                  color: Colors.blue,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.push_pin, color: Colors.white),
                      Icon(Icons.notifications_off, color: Colors.white),
                    ],
                  ),
                ),
              ),
            // 主內容
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: Matrix4.translationValues(
                currentState == SwipeState.edit
                    ? 120
                    : (currentState == SwipeState.delete ? -180 : 0),
                0,
                0,
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('$name ⭐ $rating'),
                subtitle:
                    Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(date, style: const TextStyle(fontSize: 12)),
                    const CircleAvatar(
                      radius: 10,
                      child: Text('1', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                onTap: () {
                  context.go('/chat/detail');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: TextStyle(color: color, fontSize: 14)),
    );
  }
}

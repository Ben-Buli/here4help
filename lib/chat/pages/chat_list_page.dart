// home_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/task/services/global_task_list.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:here4help/task/services/task_appliers.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late Future<void> _taskFuture;

  @override
  void initState() {
    super.initState();
    _taskFuture = GlobalTaskList().loadTasks();
  }

  Widget _taskCardWithAppliers(
      Map<String, dynamic> task, List<Map<String, dynamic>> appliers) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task['title'] ?? 'N/A',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                  Text(
                      ' ${task['location']}   💰 ${task['salary']}   📅 ${task['task_date']}   🌐 ${task['language_requirement']}'),
                ],
              ),
            ),
            Wrap(
              spacing: 6,
              children: (task['hashtags'] as List<dynamic>)
                  .map((tag) => Chip(label: Text(tag.toString())))
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...appliers.map((applier) => Slidable(
                  key: ValueKey(applier['id']),
                  startActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          // Example left slide action: accept applier
                        },
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        icon: Icons.check,
                        label: 'Accept',
                      ),
                    ],
                  ),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) {
                          // Example right slide action: reject applier
                        },
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.close,
                        label: 'Reject',
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors
                          .primaries[applier['name'].codeUnitAt(0) %
                              Colors.primaries.length]
                          .shade400,
                      child: Center(
                        child: Text(
                          applier['name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    title: Text(applier['name']),
                    subtitle: Text(applier['sentMessages'][0]),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.orangeAccent, size: 16),
                            Text('${applier['rating']}',
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                        Text('(${applier['reviewsCount'].toString()})',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final globalTaskList = GlobalTaskList();

    return FutureBuilder(
      future: _taskFuture,
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
              final appliers = taskAppliers
                  .where((applier) => applier['taskId'] == task['id'])
                  .toList();

              return _taskCardWithAppliers(task, appliers);
            }).toList(),
          );
        }
      },
    );
  }
}

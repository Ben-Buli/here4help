import 'package:flutter/foundation.dart';
import 'package:here4help/task/models/task_model.dart';

class GlobalTaskList extends ChangeNotifier {
  static final GlobalTaskList _instance = GlobalTaskList._internal();

  factory GlobalTaskList() => _instance;

  GlobalTaskList._internal();

  final List<Map<String, dynamic>> _tasks = [];

  /// 狀態說明: Open - 開放中, Inprogress - 進行中, Pending Confirmation - 待確認, Completed - 已完成, Dispute - 爭議中
  final List<TaskModel> _defaultTasks = [
    TaskModel(
      id: "a1a1a1a1-b2b2-c3c3-d4d4-e5e5e5e5e5e6",
      creatorName: "Alice",
      acceptorId: null,
      title: "Home Cleaning",
      description:
          "Need help cleaning a two-bedroom apartment, including mopping floors, cleaning windows, and organizing clutter.",
      salary: "400",
      location: "NCCU",
      taskDate: "2025-06-08",
      status: "Open",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "English",
      hashtags: ['Cleaning', 'NCCU', 'House'],
      createdAt: "2025-05-24 23:46:14",
      updatedAt: "2025-05-24 23:46:14",
    ),
    TaskModel(
      id: "b2b2b2b2-c3c3-d4d4-e5e5-f6f6f6f6f6f7",
      creatorName: "Bob",
      acceptorId: "b2b2b2b2-c3c3-d4d4-e5e5-f6f6f6f6f6f6",
      title: "Assist with Document Organization",
      description:
          "Need help organizing and scanning a large number of paper documents, expected to take about 4 hours.",
      salary: "350",
      location: "NTUT",
      taskDate: "2025-05-29",
      status: "In Progress",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "Japanese",
      hashtags: ['Document', 'Taipei'],
      createdAt: "2025-05-24 23:46:14",
      updatedAt: "2025-05-24 23:46:14",
    ),
    TaskModel(
      id: "c3c3c3c3-d4d4-e5e5-f6f6-a1a1a1a1a1a2",
      creatorName: "Alice",
      acceptorId: "a1a1a1a1-b2b2-c3c3-d4d4-e5e5e5e5e5e5",
      title: "Computer System Maintenance",
      description:
          "Assist with cleaning computer systems, updating software, and performing basic cybersecurity settings.",
      salary: "600",
      location: "NCU",
      taskDate: "2025-05-19 23:46:14",
      status: "Dispute",
      creatorConfirmed: "1",
      acceptorConfirmed: "1",
      cancelReason: null,
      failReason: null,
      languageRequirement: "English",
      hashtags: ['IT', 'NCU', 'Maintenance'],
      createdAt: "2025-05-23 23:46:14",
      updatedAt: "2025-05-23 23:46:14",
    ),
    TaskModel(
      id: "e5e5e5e5-f6f6-a1a1-b2b2-c3c3c3c3c3c3",
      creatorName: "Chris",
      acceptorId: null,
      title: "Help Moving Furniture",
      description:
          "Need help moving furniture from the first floor to the third floor, including sofa, table, and other large furniture.",
      salary: "500",
      location: "NCCU",
      taskDate: "2025-06-03 23:46:14",
      status: "Pending Confirmation",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      hashtags: ['Moving', 'NCU', 'Furniture'],
      languageRequirement: "English",
      createdAt: "2025-05-24 23:46:14",
      updatedAt: "2025-05-24 23:46:14",
    ),
    TaskModel(
      id: "f6f6f6f6-a1a1-b2b2-c3c3-d4d4d4d4d4d4",
      creatorName: "Linda",
      acceptorId: null,
      title: "Accompany Elderly to Doctor",
      description:
          "Accompany an 80-year-old elder to the hospital for a checkup, assist with registration, guidance, and companionship.",
      salary: "300",
      location: "NTU",
      taskDate: "2025-06-05",
      status: "Completed",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "Spanish",
      hashtags: ['Elderly', 'NTU', 'Health'],
      createdAt: "2025-05-24 23:46:14",
      updatedAt: "2025-05-27 23:46:14",
    ),
    TaskModel(
      id: "g7g7g7g7-h8h8-i9i9-j0j0-k1k1k1k1k1k2",
      creatorName: "David",
      acceptorId: null,
      title: "Document Translation",
      description:
          "Translate documents from English to Chinese, approximately 10 pages.",
      salary: "300",
      location: "NCCU",
      taskDate: "2024-03-17",
      status: "Open",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "English",
      hashtags: ['Translation', 'NCU', 'Language'],
      createdAt: "2024-03-01 10:00:00",
      updatedAt: "2024-03-01 10:00:00",
    ),
    TaskModel(
      id: "h8h8h8h8-i9i9-j0j0-k1k1-l2l2l2l2l2l3",
      creatorName: "Emma",
      acceptorId: null,
      title: "Phone Number Setup",
      description:
          "Assist in setting up a new phone number and configuring telecom services.",
      salary: "450",
      location: "NTU",
      taskDate: "2024-03-18",
      status: "Open",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "English",
      hashtags: ['Telecom', 'NTU', 'Setup'],
      createdAt: "2024-03-01 11:00:00",
      updatedAt: "2024-03-01 11:00:00",
    ),
    TaskModel(
      id: "i9i9i9i9-j0j0-k1k1-l2l2-m3m3m3m3m3m4",
      creatorName: "Buli",
      acceptorId: null,
      title: "Apply for Passport",
      description:
          "Need assistance with the process of applying for a new passport, including preparing documents and visiting the government office.",
      salary: "350",
      location: "NTU",
      taskDate: "2025-06-12",
      status: "Applying (Tasker)", // 此狀態for 應徵者模式
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "English",
      hashtags: ['Tasker', 'Passport'],
      createdAt: "2025-05-28 09:30:00",
      updatedAt: "2025-05-28 09:30:00",
    ),
    TaskModel(
      id: "j1j1j1j1-k2k2-l3l3-m4m4-n5n5n5n5n5n6",
      creatorName: "Sophia",
      acceptorId: null,
      title: "Apply for International Driver's License",
      description:
          "Need assistance with the process of applying for an international driver's license, including preparing required documents and visiting the relevant office.",
      salary: "400",
      location: "NCCU",
      taskDate: "2025-06-15",
      status: "In Progress (Tasker)", // 此狀態for 應徵者模式
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: null,
      failReason: null,
      languageRequirement: "English",
      hashtags: ['Tasker', 'DriverLicense'],
      createdAt: "2025-05-29 10:00:00",
      updatedAt: "2025-05-29 10:00:00",
    ),
    TaskModel(
      id: "k2k2k2k2-l3l3-m4m4-n5n5-o6o6o6o6o6o7",
      creatorName: "Mia",
      acceptorId: null,
      title: "Grocery Shopping Assistance",
      description:
          "This is a demonstration task for the 'Rejected (Tasker)' status. No actual action is needed.",
      salary: "400",
      location: "NIU",
      taskDate: "2025-07-01",
      status: "Rejected (Tasker)",
      creatorConfirmed: "0",
      acceptorConfirmed: "0",
      cancelReason: "Your application was rejected by the task creator.",
      failReason: null,
      languageRequirement: "English",
      hashtags: ['Sample', 'Tasker'],
      createdAt: "2025-06-01 12:00:00",
      updatedAt: "2025-06-01 12:00:00",
    )
  ];

  /// 讀取任務列表，只有在 _tasks 為空時才加入預設任務。
  Future<void> loadTasks({bool force = false}) async {
    if (force || _tasks.isEmpty) {
      _tasks.clear();
      _tasks.addAll(_defaultTasks.map((task) => task.toMap()));
      _sortTasks();
    }
  }

  /// 強制重載任務列表
  Future<void> reloadTasks() async {
    await loadTasks(force: true);
  }

  /// 更新任務狀態，並在更新後對任務進行排序。
  void updateTaskStatus(String taskId, String newStatus) {
    loadTasks(); // 确保任务列表已加载
    if (newStatus.isEmpty) return; // 如果新狀態為空，
    final index = _tasks.indexWhere((task) => task['id'] == taskId);
    if (index != -1) {
      _tasks[index]['status'] = newStatus;
      _tasks[index]['updated_at'] = DateTime.now().toString();
      _sortTasks();
    }
  }

  /// 添加新任務到列表中，並在添加後對任務進行排序。
  Future<void> addTask(Map<String, dynamic> task) async {
    _tasks.add(task);
    await Future.delayed(const Duration(milliseconds: 10)); // 模擬異步處理
    _sortTasks();
    notifyListeners(); // 🔔 通知 UI 更新
  }

  List<Map<String, dynamic>> get tasks => _tasks;

  /// 對任務列表進行排序，根據更新時間降序排列。
  void _sortTasks() {
    _tasks.sort((a, b) => DateTime.parse(b['updated_at'])
        .compareTo(DateTime.parse(a['updated_at'])));
  }

  bool hasChanges(List<Map<String, dynamic>> newTasks) {
    return newTasks.length != _tasks.length;
  }
}

final List<ApplicationQuestionModel> mockApplicationQuestions = [
  ApplicationQuestionModel(
    id: 'q1-task1',
    taskId: 'a1a1a1a1-b2b2-c3c3-d4d4-e5e5e5e5e5e6',
    applicationQuestion: 'What is your previous experience in house cleaning?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q2-task1',
    taskId: 'a1a1a1a1-b2b2-c3c3-d4d4-e5e5e5e5e5e6',
    applicationQuestion: 'Can you work with strong cleaning agents?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q3-task1',
    taskId: 'a1a1a1a1-b2b2-c3c3-d4d4-e5e5e5e5e5e6',
    applicationQuestion: 'Are you available for a 2-bedroom cleaning job?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q1-task2',
    taskId: 'b2b2b2b2-c3c3-d4d4-e5e5-f6f6f6f6f6f7',
    applicationQuestion: 'Have you used scanners or managed paper archives?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q2-task2',
    taskId: 'b2b2b2b2-c3c3-d4d4-e5e5-f6f6f6f6f6f7',
    applicationQuestion: 'How do you ensure organized digital records?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q3-task2',
    taskId: 'b2b2b2b2-c3c3-d4d4-e5e5-f6f6f6f6f6f7',
    applicationQuestion: 'Do you have experience working with physical files?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q1-task3',
    taskId: 'c3c3c3c3-d4d4-e5e5-f6f6-a1a1a1a1a1a2',
    applicationQuestion: 'Have you performed computer maintenance before?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q2-task3',
    taskId: 'c3c3c3c3-d4d4-e5e5-f6f6-a1a1a1a1a1a2',
    applicationQuestion: 'Are you familiar with cybersecurity basics?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q3-task3',
    taskId: 'c3c3c3c3-d4d4-e5e5-f6f6-a1a1a1a1a1a2',
    applicationQuestion: 'Can you update software and drivers?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q1-task4',
    taskId: 'e5e5e5e5-f6f6-a1a1-b2b2-c3c3c3c3c3c3',
    applicationQuestion: 'Do you have experience moving heavy furniture?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q2-task4',
    taskId: 'e5e5e5e5-f6f6-a1a1-b2b2-c3c3c3c3c3c3',
    applicationQuestion: 'Are you comfortable working on stairs?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q3-task4',
    taskId: 'e5e5e5e5-f6f6-a1a1-b2b2-c3c3c3c3c3c3',
    applicationQuestion: 'Can you help with disassembling furniture?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q1-task5',
    taskId: 'f6f6f6f6-a1a1-b2b2-c3c3-d4d4d4d4d4d4',
    applicationQuestion: 'Have you accompanied elderly people before?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q2-task5',
    taskId: 'f6f6f6f6-a1a1-b2b2-c3c3-d4d4d4d4d4d4',
    applicationQuestion: 'Are you familiar with hospital procedures?',
    applierReply: null,
  ),
  ApplicationQuestionModel(
    id: 'q3-task5',
    taskId: 'f6f6f6f6-a1a1-b2b2-c3c3-d4d4d4d4d4d4',
    applicationQuestion: 'Can you provide companionship during appointments?',
    applierReply: null,
  ),
];

import 'package:here4help/task/models/task_model.dart';

class GlobalTaskList {
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
      applicationQuestion: "Do you have cleaning experience?",
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
      applicationQuestion:
          "Do you have relevant computer maintenance experience?",
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
      applicationQuestion: "Do you have experience moving large furniture?",
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
      applicationQuestion: "Do you have experience accompanying the elderly?",
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
      applicationQuestion: "Do you have translation experience?",
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
      applicationQuestion: "Are you familiar with telecom services?",
      languageRequirement: "English",
      hashtags: ['Telecom', 'NTU', 'Setup'],
      createdAt: "2024-03-01 11:00:00",
      updatedAt: "2024-03-01 11:00:00",
    ),
  ];

  /// 讀取任務列表，只有在 _tasks 為空時才加入預設任務。
  Future<void> loadTasks() async {
    if (_tasks.isEmpty) {
      _tasks.addAll(_defaultTasks.map((task) => task.toMap()));
      _sortTasks();
    }
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
  void addTask(Map<String, dynamic> task) {
    _tasks.add(task);
    _sortTasks();
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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

class TaskService extends ChangeNotifier {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 從後端 API 載入任務列表
  Future<void> loadTasks() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse(AppConfig.taskListUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _tasks.clear();
          final dataList = data['data'];
          if (dataList is List) {
            _tasks.addAll(List<Map<String, dynamic>>.from(dataList));
          } else if (dataList is Map) {
            // 檢查是否有 tasks 子陣列
            if (dataList['tasks'] is List) {
              _tasks.addAll(List<Map<String, dynamic>>.from(dataList['tasks']));
            } else {
              // 如果 data 是單個任務對象，轉換為列表
              _tasks.add(Map<String, dynamic>.from(dataList));
            }
          }
          _sortTasks();
        } else {
          _error = data['message'] ?? 'Failed to load tasks';
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to load tasks';
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskService loadTasks error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 創建新任務
  Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http
          .post(
            Uri.parse(AppConfig.taskCreateUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(taskData),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 重新載入任務列表
          await loadTasks();
          return true;
        } else {
          _error = data['message'] ?? 'Failed to create task';
          return false;
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to create task';
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskService createTask error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新任務狀態
  Future<bool> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final response = await http
          .put(
            Uri.parse('${AppConfig.taskListUrl}/$taskId/status'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 更新本地任務狀態
          final index = _tasks.indexWhere((task) => task['id'] == taskId);
          if (index != -1) {
            _tasks[index]['status'] = newStatus;
            _tasks[index]['updated_at'] = DateTime.now().toIso8601String();
            _sortTasks();
            notifyListeners();
          }
          return true;
        } else {
          _error = data['message'] ?? 'Failed to update task status';
          return false;
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to update task status';
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskService updateTaskStatus error: $e');
      return false;
    }
  }

  /// 獲取特定任務
  Map<String, dynamic>? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((task) => task['id'] == taskId);
    } catch (e) {
      return null;
    }
  }

  /// 對任務列表進行排序
  void _sortTasks() {
    _tasks.sort((a, b) {
      final aDate = DateTime.tryParse(a['updated_at'] ?? a['created_at'] ?? '');
      final bDate = DateTime.tryParse(b['updated_at'] ?? b['created_at'] ?? '');

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });
  }

  /// 清除錯誤
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 強制重載任務列表
  Future<void> reloadTasks() async {
    await loadTasks();
  }

  /// 檢查任務資料空欄位
  Future<Map<String, dynamic>> checkEmptyTaskFields() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/backend/api/tasks/generate-sample-data.php?action=check'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return data['data'];
        } else {
          _error = data['message'] ?? 'Failed to check empty fields';
          return {};
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to check empty fields';
        return {};
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskService checkEmptyTaskFields error: $e');
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 為空欄位生成資料
  Future<Map<String, dynamic>> fillEmptyTaskFields() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/backend/api/tasks/generate-sample-data.php?action=fill'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 重新載入任務列表
          await loadTasks();
          return data['data'];
        } else {
          _error = data['message'] ?? 'Failed to fill empty fields';
          return {};
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to fill empty fields';
        return {};
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskService fillEmptyTaskFields error: $e');
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 生成範例任務資料
  Future<Map<String, dynamic>> generateSampleTasks({int count = 8}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http
          .post(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/backend/api/tasks/generate-sample-data.php'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'count': count}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 重新載入任務列表
          await loadTasks();
          return data['data'];
        } else {
          _error = data['message'] ?? 'Failed to generate sample tasks';
          return {};
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to generate sample tasks';
        return {};
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskService generateSampleTasks error: $e');
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

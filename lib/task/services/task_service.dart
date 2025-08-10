import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';

class TaskService extends ChangeNotifier {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final List<Map<String, dynamic>> _tasks = [];
  final List<Map<String, dynamic>> _statuses = [];
  final List<Map<String, dynamic>> _myApplications = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get statuses => _statuses;
  List<Map<String, dynamic>> get myApplications => _myApplications;
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

  /// 取得任務狀態清單（從後端）
  Future<void> loadStatuses({bool force = false}) async {
    if (_statuses.isNotEmpty && !force) return;
    try {
      final response = await http.get(
        Uri.parse(AppConfig.taskStatusesUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _statuses
            ..clear()
            ..addAll(List<Map<String, dynamic>>.from(data['data'] ?? []));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('TaskService loadStatuses error: $e');
    }
  }

  /// 載入我投遞的任務（同時提供 client_status_* 欄位）
  Future<void> loadMyApplications(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.applicationsListByUserUrl}?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final payload = data['data'];
          List<Map<String, dynamic>> apps = [];
          if (payload is List) {
            apps = List<Map<String, dynamic>>.from(payload);
          } else if (payload is Map && payload['applications'] is List) {
            apps = List<Map<String, dynamic>>.from(payload['applications']);
          } else if (data['applications'] is List) {
            apps = List<Map<String, dynamic>>.from(data['applications']);
          }
          _myApplications
            ..clear()
            ..addAll(apps);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('TaskService loadMyApplications error: $e');
    }
  }

  /// 送出應徵
  Future<Map<String, dynamic>> applyForTask({
    required String taskId,
    required int userId,
    String? coverLetter,
    String? introduction,
    String? q1,
    String? q2,
    String? q3,
  }) async {
    final body = <String, dynamic>{
      'task_id': taskId,
      'user_id': userId,
    };
    if (coverLetter != null) body['cover_letter'] = coverLetter;
    if (introduction != null) body['introduction'] = introduction;
    if (q1 != null) body['q1'] = q1;
    if (q2 != null) body['q2'] = q2;
    if (q3 != null) body['q3'] = q3;

    final resp = await http
        .post(
          Uri.parse(AppConfig.applicationApplyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Apply failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Apply failed');
    }
  }

  /// 創建新任務
  Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔍 TaskService createTask 開始');
      debugPrint('🔍 API URL: ${AppConfig.taskCreateUrl}');
      debugPrint('🔍 發送數據: ${jsonEncode(taskData)}');

      final response = await http
          .post(
            Uri.parse(AppConfig.taskCreateUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(taskData),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🔍 HTTP 回應狀態碼: ${response.statusCode}');
      debugPrint('🔍 HTTP 回應內容: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          debugPrint('✅ 任務創建成功');
          // 重新載入任務列表
          await loadTasks();
          return true;
        } else {
          _error = data['message'] ?? 'Failed to create task';
          debugPrint('❌ 任務創建失敗: $_error');
          return false;
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to create task';
        debugPrint('❌ HTTP 錯誤: $_error');
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('❌ TaskService createTask 錯誤: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新任務狀態（支援 statusId 或 statusCode 或舊文字）
  Future<bool> updateTaskStatus(String taskId, String newStatus,
      {int? statusId, String? statusCode}) async {
    try {
      final body = <String, dynamic>{'id': taskId, 'status': newStatus};
      if (statusId != null) body['status_id'] = statusId;
      if (statusCode != null) body['status_code'] = statusCode;

      final response = await http
          .put(
            Uri.parse(AppConfig.taskUpdateUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 更新本地任務狀態
          final index = _tasks.indexWhere((task) => task['id'] == taskId);
          if (index != -1) {
            // 後端回傳最新 task 物件，直接覆蓋以確保狀態/顯示一致
            final updated = Map<String, dynamic>.from(data['data'] ?? {});
            if (updated.isNotEmpty) {
              _tasks[index] = updated;
            } else {
              _tasks[index]['status'] = newStatus;
              _tasks[index]['updated_at'] = DateTime.now().toIso8601String();
            }
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

  /// 指派應徵者（Poster 操作）
  Future<Map<String, dynamic>> approveApplication({
    required String taskId,
    required int userId,
    required int posterId,
  }) async {
    final body = {
      'task_id': taskId,
      'user_id': userId,
      'poster_id': posterId,
    };

    final resp = await http
        .post(
          Uri.parse(AppConfig.applicationApproveUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Approve failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Approve failed');
    }
  }

  /// 拒絕應徵者（Poster 操作）
  Future<Map<String, dynamic>> rejectApplication({
    required String taskId,
    required int userId,
    required int posterId,
  }) async {
    final body = {
      'task_id': taskId,
      'user_id': userId,
      'poster_id': posterId,
    };

    final resp = await http
        .post(
          Uri.parse(AppConfig.applicationRejectUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Reject failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Reject failed');
    }
  }

  /// 載入特定任務的應徵者列表（Poster 用）
  Future<List<Map<String, dynamic>>> loadApplicationsByTask(
      String taskId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.applicationsListByTaskUrl}?task_id=$taskId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final payload = data['data'];
          if (payload is Map && payload['applications'] is List) {
            return List<Map<String, dynamic>>.from(payload['applications']);
          }
        }
      }
    } catch (e) {
      debugPrint('TaskService loadApplicationsByTask error: $e');
    }
    return [];
  }
}

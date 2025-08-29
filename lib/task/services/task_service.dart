import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../auth/services/auth_service.dart';

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

  /// 取得任務分頁（回傳 items 與 hasMore）
  Future<({List<Map<String, dynamic>> tasks, bool hasMore})> fetchTasksPage({
    required int limit,
    required int offset,
    Map<String, String>? filters,
  }) async {
    try {
      final query = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (filters != null) {
        query.addAll(filters);
      }
      final uri =
          Uri.parse(AppConfig.taskListUrl).replace(queryParameters: query);
      final resp = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          final payload = data['data'] ?? {};
          final itemsRaw = payload['tasks'] ?? [];
          final List<Map<String, dynamic>> items = (itemsRaw is List)
              ? itemsRaw.map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
          final hasMore = (payload['pagination']?['has_more'] ?? false) == true;
          return (tasks: items, hasMore: hasMore);
        }
      }
      return (tasks: <Map<String, dynamic>>[], hasMore: false);
    } catch (e) {
      debugPrint('fetchTasksPage error: $e');
      return (tasks: <Map<String, dynamic>>[], hasMore: false);
    }
  }

  /// 取得 Posted Tasks 聚合資料（含應徵者和聊天室）
  Future<({List<Map<String, dynamic>> tasks, bool hasMore})>
      fetchPostedTasksAggregated({
    required int limit,
    required int offset,
    required String creatorId,
    Map<String, String>? filters,
  }) async {
    try {
      final query = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
        'creator_id': creatorId,
      };
      if (filters != null) {
        query.addAll(filters);
      }

      final uri = Uri.parse(
              '${AppConfig.apiBaseUrl}/backend/api/tasks/applications/posted_task_applications.php')
          .replace(queryParameters: query);

      debugPrint('🔍 [Posted Tasks Aggregated] API URL: $uri');

      // 獲取認證 token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        // debugPrint(
        //     '🔐 [Posted Tasks Aggregated] 使用認證 token: ${token.substring(0, 20)}...');
        // debugPrint('🔐 [Posted Tasks Aggregated] 完整 headers: $headers');
      } else {
        // debugPrint('⚠️ [Posted Tasks Aggregated] 沒有認證 token');
        // debugPrint('⚠️ [Posted Tasks Aggregated] token 值: $token');
      }

      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      // debugPrint(
      //     '🔍 [Posted Tasks Aggregated] Response Status: ${resp.statusCode}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        // debugPrint(
        //     '🔍 [Posted Tasks Aggregated] Response Success: ${data['success']}');
        if (data['success'] == true) {
          final payload = data['data'] ?? {};
          final itemsRaw = payload['tasks'] ?? [];
          final List<Map<String, dynamic>> items = (itemsRaw is List)
              ? itemsRaw.map((e) => Map<String, dynamic>.from(e)).toList()
              : [];
          final hasMore = (payload['pagination']?['has_more'] ?? false) == true;
          // debugPrint('🔍 [Posted Tasks Aggregated] 成功獲取 ${items.length} 個任務');

          // 調試：顯示前幾個任務的詳細數據
          for (int i = 0; i < items.length && i < 3; i++) {
            final task = items[i];
            // debugPrint('📋 任務 [$i] 詳細數據:');
            debugPrint('  - ID: ${task['id']}');
            // debugPrint('  - Title: "${task['title']}"');
            // debugPrint('  - Description: "${task['description']}"');
            // debugPrint('  - Location: "${task['location']}"');
            // debugPrint('  - Status: "${task['status']}"');
            // debugPrint('  - Status Display: "${task['status_display']}"');
            // debugPrint('  - 所有鍵: ${task.keys.toList()}');
          }

          return (tasks: items, hasMore: hasMore);
        } else {
          debugPrint(
              '❌ [Posted Tasks Aggregated] API Error: ${data['message']}');
        }
      } else {
        debugPrint(
            '❌ [Posted Tasks Aggregated] HTTP Error: ${resp.statusCode} - ${resp.body}');
      }
      return (tasks: <Map<String, dynamic>>[], hasMore: false);
    } catch (e) {
      debugPrint('fetchPostedTasksAggregated error: $e');
      return (tasks: <Map<String, dynamic>>[], hasMore: false);
    }
  }

  /// 取得任務的編輯資料（完整任務 + application_questions）
  Future<Map<String, dynamic>?> fetchTaskEditData(String taskId) async {
    try {
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/backend/api/tasks/task_edit_data.php?id=$taskId');
      final resp = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
      }
    } catch (e) {
      debugPrint('fetchTaskEditData error: $e');
    }
    return null;
  }

  /// Poster 確認完成（自動轉點與異動紀錄由後端處理）
  Future<Map<String, dynamic>> confirmCompletion({
    required String taskId,
    bool preview = false,
  }) async {
    // 獲取用戶 token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final body = {
      'task_id': taskId,
      if (preview) 'preview': 1,
    };
    final resp = await http
        .post(
          Uri.parse(AppConfig.taskConfirmCompletionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Confirm failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Confirm failed');
    }
  }

  /// Poster 不同意完成（統計拒絕次數由後端處理）
  Future<Map<String, dynamic>> disagreeCompletion({
    required String taskId,
    String? reason,
  }) async {
    // 獲取用戶 token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final body = {'task_id': taskId, if (reason != null) 'reason': reason};
    final resp = await http
        .post(
          Uri.parse(AppConfig.taskDisagreeCompletionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Disagree failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Disagree failed');
    }
  }

  /// 支付並評價（輸入兩次支付碼 + 三項評分 + 評論）
  Future<Map<String, dynamic>> payAndReview({
    required String taskId,
    required int ratingService,
    required int ratingAttitude,
    required int ratingExperience,
    String? comment,
    required String paymentCode1,
    required String paymentCode2,
  }) async {
    final body = {
      'task_id': taskId,
      'ratings': {
        'service': ratingService,
        'attitude': ratingAttitude,
        'experience': ratingExperience,
      },
      if (comment != null) 'comment': comment,
      'payment_code_1': paymentCode1,
      'payment_code_2': paymentCode2,
    };
    final resp = await http
        .post(
          Uri.parse(AppConfig.taskPayAndReviewUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Pay & Review failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Pay & Review failed');
    }
  }

  /// 接受應徵者
  Future<Map<String, dynamic>> acceptApplication({
    required String taskId,
    String? applicationId,
    String? userId,
    required String posterId,
  }) async {
    // 獲取用戶 token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final body = {
      'task_id': taskId,
      'poster_id': posterId,
      if (applicationId != null) 'application_id': applicationId,
      if (userId != null) 'user_id': userId,
    };

    final resp = await http
        .post(
          Uri.parse(
              '${AppConfig.apiBaseUrl}/backend/api/tasks/applications/accept.php'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      debugPrint('🔍 TaskService acceptApplication: 回應內容: $data');
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Accept application failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Accept application failed');
    }
  }

  /// 送出或更新評論
  Future<Map<String, dynamic>> submitReview({
    required String taskId,
    required int ratingService,
    required int ratingAttitude,
    required int ratingExperience,
    String? comment,
  }) async {
    // 獲取用戶 token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final body = {
      'task_id': taskId,
      'ratings': {
        'service': ratingService,
        'attitude': ratingAttitude,
        'experience': ratingExperience,
      },
      if (comment != null) 'comment': comment,
    };
    final resp = await http
        .post(
          Uri.parse(AppConfig.taskReviewsSubmitUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Submit review failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Submit review failed');
    }
  }

  /// 取得評論（若有則前端切換唯讀）
  Future<Map<String, dynamic>?> getReview({
    required String taskId,
  }) async {
    final uri = Uri.parse('${AppConfig.taskReviewsGetUrl}?task_id=$taskId');
    final resp = await http.get(uri, headers: {
      'Content-Type': 'application/json'
    }).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        return data['data'] == null
            ? null
            : Map<String, dynamic>.from(data['data']);
      }
      return null;
    } else {
      return null;
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

  /// 載入用戶的應徵記錄
  Future<void> loadMyApplications(int? userId) async {
    if (userId == null) return;

    try {
      // 獲取認證 token
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('❌ TaskService loadMyApplications: 沒有認證 token');
        return;
      }

      debugPrint('🔍 TaskService loadMyApplications: 開始載入用戶 $userId 的應徵記錄');
      debugPrint(
          '🔍 API URL: ${AppConfig.myWorkApplicationsUrl}?user_id=$userId');

      final response = await http.get(
        Uri.parse('${AppConfig.myWorkApplicationsUrl}?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));
      debugPrint(
          '🔍 TaskService loadMyApplications: HTTP 狀態碼: ${response.statusCode}');
      // debugPrint('🔍 TaskService loadMyApplications: 回應內容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // debugPrint('🔍 TaskService loadMyApplications: 解析後的資料: $data');

        if (data['success'] == true) {
          final payload = data['data'];
          List<Map<String, dynamic>> apps = [];

          if (payload is List) {
            apps = List<Map<String, dynamic>>.from(payload);
            debugPrint(
                '🔍 TaskService loadMyApplications: 從 data 陣列獲取 ${apps.length} 個應徵記錄');
          } else if (payload is Map && payload['applications'] is List) {
            apps = List<Map<String, dynamic>>.from(payload['applications']);
            debugPrint(
                '🔍 TaskService loadMyApplications: 從 data.applications 陣列獲取 ${apps.length} 個應徵記錄');
          } else if (data['applications'] is List) {
            apps = List<Map<String, dynamic>>.from(data['applications']);
            debugPrint(
                '🔍 TaskService loadMyApplications: 從 applications 陣列獲取 ${apps.length} 個應徵記錄');
          } else {
            debugPrint(
                '⚠️ TaskService loadMyApplications: 無法識別的資料結構: $payload');
          }

          _myApplications
            ..clear()
            ..addAll(apps);

          debugPrint(
              '✅ TaskService loadMyApplications: 成功載入 ${_myApplications.length} 個應徵記錄');
          notifyListeners();
        } else {
          debugPrint(
              '❌ TaskService loadMyApplications: API 返回失敗: ${data['message']}');
        }
      } else {
        debugPrint(
            '❌ TaskService loadMyApplications: HTTP 錯誤 ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('TaskService loadMyApplications error: $e');
    }
  }

  /// 後端分頁：取得我的應徵（My Works）清單
  /// 返回 items 與是否還有下一頁（hasMore）
  Future<({List<Map<String, dynamic>> items, bool hasMore})>
      fetchMyWorksApplications({
    required String userId,
    required int limit,
    required int offset,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('未登入');
      }

      final uri = Uri.parse(
        '${AppConfig.myWorkApplicationsUrl}?user_id=$userId&limit=$limit&offset=$offset',
      );

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'API error');
      }

      // 後端回傳可能是 data 或 data.applications
      final payload = data['data'];
      List<Map<String, dynamic>> items = [];
      if (payload is List) {
        items = List<Map<String, dynamic>>.from(payload);
      } else if (payload is Map && payload['applications'] is List) {
        items = List<Map<String, dynamic>>.from(payload['applications']);
      } else if (data['applications'] is List) {
        items = List<Map<String, dynamic>>.from(data['applications']);
      }

      // 粗略計算 hasMore：若本頁筆數等於 limit，則可能還有下一頁
      final bool hasMore = items.length >= limit;

      return (items: items, hasMore: hasMore);
    } catch (e) {
      debugPrint('fetchMyWorksApplications error: $e');
      return (items: <Map<String, dynamic>>[], hasMore: false);
    }
  }

  /// 送出應徵
  Future<Map<String, dynamic>> applyForTask({
    required String taskId,
    required int userId,
    String? coverLetter,
    Map<String, String>? answers,
  }) async {
    final body = <String, dynamic>{
      'task_id': taskId,
      'user_id': userId,
    };
    if (coverLetter != null) body['cover_letter'] = coverLetter;
    if (answers != null && answers.isNotEmpty) body['answers'] = answers;

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
          Uri.parse(AppConfig.applicationApproveUrlV2),
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

  /// 更新應徵狀態（通用方法）
  Future<bool> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      final body = {
        'application_id': applicationId,
        'status': status,
      };

      final response = await http
          .put(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/backend/api/tasks/applications/update-status.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          throw Exception(
              data['message'] ?? 'Failed to update application status');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: Failed to update application status');
      }
    } catch (e) {
      debugPrint('TaskService updateApplicationStatus error: $e');
      throw Exception('Failed to update application status: $e');
    }
  }

  /// 刪除應徵（軟刪除）
  /// 軟刪除：將 status 設為 'Cancelled'
  /// 執行者：Poster
  Future<bool> deleteApplication({
    required String applicationId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      final response = await http.delete(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/backend/api/tasks/applications/delete.php?application_id=$applicationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          throw Exception(data['message'] ?? 'Failed to delete application');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: Failed to delete application');
      }
    } catch (e) {
      debugPrint('TaskService deleteApplication error: $e');
      throw Exception('Failed to delete application: $e');
    }
  }

  /// 載入特定任務的應徵者列表（Poster 用）
  Future<List<Map<String, dynamic>>> loadApplicationsByTask(
      String taskId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.taskApplicantsUrl}?task_id=$taskId'),
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

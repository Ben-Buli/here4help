import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../auth/services/auth_service.dart';
import '../../services/http_client_service.dart';

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

      // 獲取認證標頭
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .get(
            Uri.parse(AppConfig.taskListUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🔍 [TaskService] loadTasks API 調用:');
      debugPrint('  - URL: ${AppConfig.taskListUrl}');
      debugPrint('  - Headers: $headers');
      debugPrint('  - Status Code: ${response.statusCode}');
      debugPrint(
          '  - Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _tasks.clear();
          final dataList = data['data'];
          debugPrint('🔍 [TaskService] 解析任務數據:');
          debugPrint('  - dataList type: ${dataList.runtimeType}');

          if (dataList is List) {
            _tasks.addAll(List<Map<String, dynamic>>.from(dataList));
            debugPrint('  - 直接從 List 載入 ${_tasks.length} 個任務');
          } else if (dataList is Map) {
            // 檢查是否有 tasks 子陣列
            if (dataList['tasks'] is List) {
              _tasks.addAll(List<Map<String, dynamic>>.from(dataList['tasks']));
              debugPrint('  - 從 Map.tasks 載入 ${_tasks.length} 個任務');
            } else {
              // 如果 data 是單個任務對象，轉換為列表
              _tasks.add(Map<String, dynamic>.from(dataList));
              debugPrint('  - 從單個 Map 載入 1 個任務');
            }
          }

          debugPrint('✅ [TaskService] 最終載入 ${_tasks.length} 個任務');
          if (_tasks.isNotEmpty) {
            debugPrint(
                '  - 第一個任務: ${_tasks.first['title']} (ID: ${_tasks.first['id']})');
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

      // 獲取認證標頭
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri =
          Uri.parse(AppConfig.taskListUrl).replace(queryParameters: query);
      final resp = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));
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

      const path = '/tasks/applications/posted_task_applications.php';
      final apiUrl = Uri.parse(AppConfig.api(path))
          .replace(queryParameters: query)
          .toString();

      debugPrint('🔍 [Posted Tasks Aggregated] API URL: $apiUrl');

      // 使用 HttpClientService 以統一 header 與 query token 備援
      final data = await HttpClientService.getJson(
        apiUrl,
        useQueryParamToken: true,
      );

      if (data['success'] == true) {
        final payload = data['data'] ?? {};
        final itemsRaw = payload['tasks'] ?? [];
        final List<Map<String, dynamic>> items = (itemsRaw is List)
            ? itemsRaw.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        final hasMore = (payload['pagination']?['has_more'] ?? false) == true;
        debugPrint('🔍 [Posted Tasks Aggregated] 成功獲取 ${items.length} 個任務');
        return (tasks: items, hasMore: hasMore);
      } else {
        debugPrint('❌ [Posted Tasks Aggregated] API Error: ${data['message']}');
        return (tasks: <Map<String, dynamic>>[], hasMore: false);
      }
    } catch (e) {
      debugPrint('fetchPostedTasksAggregated error: $e');
      return (tasks: <Map<String, dynamic>>[], hasMore: false);
    }
  }

  /// 取得任務的編輯資料（完整任務 + application_questions）
  Future<Map<String, dynamic>?> fetchTaskEditData(String taskId) async {
    try {
      final uri =
          Uri.parse(AppConfig.api('/tasks/task_edit_data.php?id=$taskId'));
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
    final body = {
      'task_id': taskId,
      if (preview) 'preview': 1,
    };

    final resp = await HttpClientService.post(
      AppConfig.taskConfirmCompletionUrl,
      body: body,
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Confirm completion failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Confirm completion failed');
    }
  }

  /// Poster 不同意完成（統計拒絕次數由後端處理）
  Future<Map<String, dynamic>> disagreeCompletion({
    required String taskId,
    String? reason,
  }) async {
    // 獲取用戶 token
    final token = await AuthService.getToken();
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
    // 獲取用戶 token
    final token = await AuthService.getToken();
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
      'payment_code_1': paymentCode1,
      'payment_code_2': paymentCode2,
    };
    final resp = await http
        .post(
          Uri.parse(AppConfig.taskPayAndReviewUrl),
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
    final token = await AuthService.getToken();
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
          Uri.parse(AppConfig.api('/tasks/applications/accept.php')),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      try {
        final data = jsonDecode(resp.body);
        debugPrint('🔍 TaskService acceptApplication: 回應內容: $data');
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? 'Accept application failed');
      } catch (e) {
        // JSON 解析失敗，檢查是否為 HTML 錯誤
        final responseBody = resp.body;
        if (responseBody.contains('<html>') ||
            responseBody.contains('<br />') ||
            responseBody.contains('<!DOCTYPE')) {
          debugPrint('❌ TaskService acceptApplication: 後端返回 HTML 錯誤頁面');
          debugPrint(
              '❌ 回應內容: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}...');
          throw Exception(
              'Backend server error: PHP error occurred. Please check server logs.');
        }
        throw Exception('Invalid JSON response: $e');
      }
    } else {
      // 檢查是否返回 HTML 錯誤頁面
      final responseBody = resp.body;
      if (responseBody.contains('<html>') ||
          responseBody.contains('<br />') ||
          responseBody.contains('<!DOCTYPE')) {
        debugPrint('❌ TaskService acceptApplication: 後端返回 HTML 錯誤頁面');
        debugPrint(
            '❌ 回應內容: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}...');
        throw Exception(
            'Backend server error: PHP error occurred. Please check server logs.');
      }
      throw Exception('HTTP ${resp.statusCode}: Accept application failed');
    }
  }

  /// 轉移點數（發布者 → 任務接案者）
  Future<Map<String, dynamic>> transferPoints({
    required int fromUserId,
    required int toUserId,
    required int amount,
    required String taskId,
  }) async {
    final body = {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'task_id': taskId,
      'transaction_type': 'task_payment',
    };

    final resp = await HttpClientService.post(
      AppConfig.api('/points/transfer.php'),
      body: body,
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Points transfer failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Points transfer failed');
    }
  }

  /// 扣除官方手續費（由發布者支付）
  Future<Map<String, dynamic>> deductCompletionFee({
    required int userId,
    required int amount,
    required String taskId,
    required double feeRate,
  }) async {
    final body = {
      'user_id': userId,
      'amount': amount,
      'task_id': taskId,
      'fee_rate': feeRate,
      'transaction_type': 'completion_fee',
    };

    final resp = await HttpClientService.post(
      AppConfig.api('/points/deduct-fee.php'),
      body: body,
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Fee deduction failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Fee deduction failed');
    }
  }

  /// 記錄官方費用收入（fee_revenue_ledger）
  Future<Map<String, dynamic>> recordFeeRevenue({
    required String taskId,
    required int srcTransactionId,
    required int payerUserId,
    required int amountPoints,
    required double rate,
    String? note,
  }) async {
    final body = {
      'task_id': taskId,
      'src_transaction_id': srcTransactionId,
      'payer_user_id': payerUserId,
      'amount_points': amountPoints,
      'rate': rate,
      if (note != null) 'note': note,
    };

    final resp = await HttpClientService.post(
      AppConfig.api('/fees/record.php'),
      body: body,
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(data['message'] ?? 'Record fee failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Record fee failed');
    }
  }

  /// 驗證付款密碼
  Future<Map<String, dynamic>> verifyPaymentPassword({
    required String paymentPassword,
  }) async {
    final body = {
      'payment_password': paymentPassword,
    };

    final resp = await HttpClientService.post(
      AppConfig.api('/account/verify-payment-password.php'),
      body: body,
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      throw Exception(
          data['message'] ?? 'Payment password verification failed');
    } else {
      final data = HttpClientService.parseJsonResponse(resp);
      throw Exception(data['message'] ??
          'HTTP ${resp.statusCode}: Payment password verification failed');
    }
  }

  /// 送出或更新評論
  Future<Map<String, dynamic>> submitReview({
    required String taskId,
    required String taskerId,
    required int rating,
    String? comment,
  }) async {
    final body = {
      'task_id': taskId,
      'tasker_id': taskerId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    };

    final resp = await HttpClientService.post(
      AppConfig.taskReviewsSubmitUrl,
      body: body,
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
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
    final resp = await HttpClientService.get(
      '${AppConfig.taskReviewsGetUrl}?task_id=$taskId',
      useQueryParamToken: true, // MAMP 兼容性：使用查詢參數傳遞 token
    );

    if (HttpClientService.isSuccessResponse(resp)) {
      final data = HttpClientService.parseJsonResponse(resp);
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
    try {
      debugPrint('🔍 [TaskService] 開始應徵任務: taskId=$taskId, userId=$userId');

      final body = <String, dynamic>{
        'task_id': taskId,
        'user_id': userId,
      };
      if (coverLetter != null) body['cover_letter'] = coverLetter;
      if (answers != null && answers.isNotEmpty) body['answers'] = answers;

      debugPrint('🔍 [TaskService] 應徵請求內容: $body');

      final resp = await HttpClientService.post(
        AppConfig.applicationApplyUrl,
        body: body,
        useQueryParamToken: true,
      );

      debugPrint('🔍 [TaskService] 應徵回應狀態碼: ${resp.statusCode}');
      debugPrint('🔍 [TaskService] 應徵回應內容: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          debugPrint('✅ [TaskService] 應徵成功');
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? 'Apply failed');
      } else {
        // 檢查是否返回 HTML 錯誤頁面
        final responseBody = resp.body;
        if (responseBody.contains('<html>') ||
            responseBody.contains('<br />') ||
            responseBody.contains('<!DOCTYPE')) {
          debugPrint('❌ [TaskService] 後端返回 HTML 錯誤頁面');
          debugPrint(
              '❌ 回應內容: ${responseBody.length > 500 ? responseBody.substring(0, 500) : responseBody}...');
          throw Exception(
              'Backend server error: PHP error occurred. Please check server logs.');
        }
        throw Exception('HTTP ${resp.statusCode}: Apply failed');
      }
    } catch (e) {
      debugPrint('❌ [TaskService] 應徵失敗: $e');
      rethrow;
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
            AppConfig.api('/tasks/generate-sample-data.php?action=check')),
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
        Uri.parse(AppConfig.api('/tasks/generate-sample-data.php?action=fill')),
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
            Uri.parse(AppConfig.api('/tasks/generate-sample-data.php')),
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
    // 獲取用戶 token
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final body = {
      'task_id': taskId,
      'user_id': userId,
      'poster_id': posterId,
    };

    final resp = await http
        .post(
          Uri.parse(AppConfig.applicationApproveUrlV2),
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
      throw Exception(data['message'] ?? 'Approve failed');
    } else {
      throw Exception('HTTP ${resp.statusCode}: Approve failed');
    }
  }

  /// 拒絕應徵者（Task Creator 操作）
  Future<Map<String, dynamic>> rejectApplication({
    required String taskId,
    required int userId,
    required int posterId,
  }) async {
    debugPrint('🔍 [rejectApplication] 開始執行');
    debugPrint('  - taskId: $taskId');
    debugPrint('  - userId: $userId');
    debugPrint('  - posterId: $posterId');

    // 獲取用戶 token
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('User not authenticated');
    }

    final body = {
      'task_id': taskId,
      'user_id': userId,
      'poster_id': posterId,
    };

    debugPrint('  - request body: $body');
    debugPrint('  - API URL: ${AppConfig.applicationRejectUrl}');

    final resp = await http
        .post(
          Uri.parse(AppConfig.applicationRejectUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    debugPrint('  - response status: ${resp.statusCode}');
    debugPrint('  - response body: ${resp.body}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        debugPrint('✅ [rejectApplication] 成功完成');
        return Map<String, dynamic>.from(data['data'] ?? {});
      }
      debugPrint('❌ [rejectApplication] API 返回失敗: ${data['message']}');
      throw Exception(data['message'] ?? 'Reject failed');
    } else {
      debugPrint('❌ [rejectApplication] HTTP 錯誤: ${resp.statusCode}');
      debugPrint('  - response body: ${resp.body}');
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
            Uri.parse(AppConfig.api('/tasks/applications/update-status.php')),
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
        Uri.parse(AppConfig.api(
            '/tasks/applications/delete.php?application_id=$applicationId')),
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

  /// 撤回當前用戶的應徵（Participant 操作）
  Future<Map<String, dynamic>> withdrawCurrentApplication({
    required String taskId,
  }) async {
    try {
      // 獲取用戶 token
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      // 獲取當前用戶 ID
      // 使用 AuthService.getUserData() 方法來獲取用戶信息
      final userData = await AuthService.getUserData();
      if (userData == null) {
        throw Exception('Current user not found');
      }

      final userId = userData['id'] as int;

      // 首先查找當前用戶在該任務的應徵記錄
      final applicationsResponse = await http.get(
        Uri.parse('${AppConfig.myWorkApplicationsUrl}?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (applicationsResponse.statusCode != 200) {
        throw Exception('Failed to fetch user applications');
      }

      final applicationsData = jsonDecode(applicationsResponse.body);
      if (applicationsData['success'] != true) {
        throw Exception(
            applicationsData['message'] ?? 'Failed to fetch applications');
      }

      // 查找該任務的應徵記錄
      final applications = applicationsData['data'] is List
          ? applicationsData['data']
          : applicationsData['applications'] ?? [];

      Map<String, dynamic>? targetApplication;
      for (final app in applications) {
        if (app['task_id'].toString() == taskId && app['status'] == 'applied') {
          targetApplication = app;
          break;
        }
      }

      if (targetApplication == null) {
        throw Exception('No active application found for this task');
      }

      final applicationId = targetApplication['id']?.toString() ??
          targetApplication['application_id']?.toString();

      if (applicationId == null) {
        throw Exception('Application ID not found');
      }

      // 使用 update-status API 將狀態更新為 withdrawn
      final body = {
        'application_id': applicationId,
        'status': 'withdrawn',
      };

      final response = await http
          .put(
            Uri.parse(AppConfig.api('/tasks/applications/update-status.php')),
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
          return Map<String, dynamic>.from(data['data'] ?? {});
        }
        throw Exception(data['message'] ?? 'Withdraw application failed');
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: Withdraw application failed');
      }
    } catch (e) {
      debugPrint('TaskService withdrawCurrentApplication error: $e');
      throw Exception('Failed to withdraw application: $e');
    }
  }

  /// 從聊天室上下文拒絕應徵者（Task Creator 操作）
  Future<Map<String, dynamic>> rejectApplicationFromChat({
    required String taskId,
    required int applicantUserId,
  }) async {
    try {
      debugPrint('🔍 [rejectApplicationFromChat] 開始執行');
      debugPrint('  - taskId: $taskId');
      debugPrint('  - applicantUserId: $applicantUserId');

      // 獲取用戶 token
      final token = await AuthService.getToken();
      debugPrint('  - token: ${token != null ? 'found' : 'null'}');
      if (token == null) {
        throw Exception('User not authenticated');
      }

      // 獲取當前用戶 ID 作為 poster_id
      // 使用 AuthService.getUserData() 方法來獲取用戶信息
      final userData = await AuthService.getUserData();
      debugPrint('  - userData: $userData');
      if (userData == null) {
        throw Exception('Current user not found');
      }

      if (userData['id'] == null) {
        debugPrint('❌ [rejectApplicationFromChat] userData[\'id\'] is null');
        throw Exception('User ID not found in user data');
      }

      final posterId = userData['id'] as int;
      debugPrint('  - posterId: $posterId');

      // 調用現有的 rejectApplication 方法
      debugPrint('🔍 [rejectApplicationFromChat] 呼叫 rejectApplication');
      final result = await rejectApplication(
        taskId: taskId,
        userId: applicantUserId,
        posterId: posterId,
      );

      debugPrint('✅ [rejectApplicationFromChat] 成功完成');
      return result;
    } catch (e) {
      debugPrint('❌ [rejectApplicationFromChat] 錯誤: $e');
      throw Exception('Failed to reject application: $e');
    }
  }
}

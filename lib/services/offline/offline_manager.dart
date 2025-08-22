import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../cache/cache_manager.dart';

/// 離線動作資料結構
class OfflineAction {
  final String id;
  final String type; // 'api_call', 'upload', 'message', etc.
  final String endpoint;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final int maxRetries;

  OfflineAction({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.maxRetries = 3,
  });

  OfflineAction copyWith({
    int? retryCount,
  }) =>
      OfflineAction(
        id: id,
        type: type,
        endpoint: endpoint,
        data: data,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
        maxRetries: maxRetries,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'endpoint': endpoint,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'maxRetries': maxRetries,
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
        id: json['id'],
        type: json['type'],
        endpoint: json['endpoint'],
        data: Map<String, dynamic>.from(json['data']),
        createdAt: DateTime.parse(json['createdAt']),
        retryCount: json['retryCount'] ?? 0,
        maxRetries: json['maxRetries'] ?? 3,
      );
}

/// 離線狀態管理器
/// 監控網路連接狀態，管理離線模式下的資料存取
class OfflineManager extends ChangeNotifier {
  static OfflineManager? _instance;
  static OfflineManager get instance => _instance ??= OfflineManager._();

  OfflineManager._() {
    _initialize();
  }

  // 網路連接狀態
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  // 連接類型
  String _connectionType = 'unknown';
  String get connectionType => _connectionType;

  // 離線佇列
  final List<OfflineAction> _offlineQueue = [];
  List<OfflineAction> get offlineQueue => List.unmodifiable(_offlineQueue);

  // 監聽器
  Timer? _networkCheckTimer;

  /// 初始化
  Future<void> _initialize() async {
    await _checkInitialConnectivity();
    _startPeriodicNetworkCheck();
    await _loadOfflineQueue();
  }

  /// 檢查初始連接狀態
  Future<void> _checkInitialConnectivity() async {
    try {
      _isOnline = await _checkNetworkReachability();
      _connectionType = _isOnline ? 'connected' : 'disconnected';
      notifyListeners();
    } catch (e) {
      print('檢查初始連接狀態失敗: $e');
      _isOnline = false;
      _connectionType = 'error';
      notifyListeners();
    }
  }

  /// 開始定期網路檢查
  void _startPeriodicNetworkCheck() {
    _networkCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performNetworkCheck(),
    );
  }

  /// 檢查網路可達性
  Future<bool> _checkNetworkReachability() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 執行網路檢查
  Future<void> _performNetworkCheck() async {
    final wasOnline = _isOnline;
    _isOnline = await _checkNetworkReachability();
    _connectionType = _isOnline ? 'connected' : 'disconnected';

    if (wasOnline != _isOnline) {
      print('網路狀態變更: ${_isOnline ? "線上" : "離線"}');

      if (_isOnline) {
        await _onNetworkRestored();
      } else {
        await _onNetworkLost();
      }

      notifyListeners();
    }
  }

  /// 網路恢復時的處理
  Future<void> _onNetworkRestored() async {
    print('網路已恢復，開始處理離線佇列...');
    await _processOfflineQueue();
  }

  /// 網路中斷時的處理
  Future<void> _onNetworkLost() async {
    print('網路已中斷，進入離線模式');
  }

  /// 添加離線動作到佇列
  Future<void> addOfflineAction({
    required String type,
    required String endpoint,
    required Map<String, dynamic> data,
  }) async {
    final action = OfflineAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      endpoint: endpoint,
      data: data,
      createdAt: DateTime.now(),
    );

    _offlineQueue.add(action);
    await _saveOfflineQueue();

    print('離線動作已添加到佇列: ${action.type} - ${action.endpoint}');
    notifyListeners();
  }

  /// 處理離線佇列
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty || !_isOnline) {
      return;
    }

    final actionsToProcess = List<OfflineAction>.from(_offlineQueue);

    for (final action in actionsToProcess) {
      try {
        final success = await _executeOfflineAction(action);

        if (success) {
          _offlineQueue.remove(action);
          print('離線動作執行成功: ${action.type} - ${action.endpoint}');
        } else {
          // 增加重試次數
          final updatedAction =
              action.copyWith(retryCount: action.retryCount + 1);

          if (updatedAction.retryCount >= updatedAction.maxRetries) {
            _offlineQueue.remove(action);
            print('離線動作達到最大重試次數，已移除: ${action.type} - ${action.endpoint}');
          } else {
            final index = _offlineQueue.indexOf(action);
            if (index != -1) {
              _offlineQueue[index] = updatedAction;
            }
            print(
                '離線動作執行失敗，重試次數: ${updatedAction.retryCount}/${updatedAction.maxRetries}');
          }
        }
      } catch (e) {
        print('處理離線動作時發生錯誤: $e');
      }
    }

    await _saveOfflineQueue();
    notifyListeners();
  }

  /// 執行離線動作
  Future<bool> _executeOfflineAction(OfflineAction action) async {
    // 這裡應該根據動作類型執行相應的 API 調用
    // 暫時返回模擬結果
    try {
      // 模擬 API 調用
      await Future.delayed(const Duration(milliseconds: 500));

      // 根據動作類型執行不同的邏輯
      switch (action.type) {
        case 'send_message':
          return await _executeSendMessage(action);
        case 'update_task':
          return await _executeUpdateTask(action);
        case 'upload_file':
          return await _executeUploadFile(action);
        default:
          return await _executeGenericAction(action);
      }
    } catch (e) {
      print('執行離線動作失敗: $e');
      return false;
    }
  }

  /// 執行發送訊息動作
  Future<bool> _executeSendMessage(OfflineAction action) async {
    // 這裡應該調用實際的訊息發送 API
    print('執行發送訊息: ${action.data}');
    return true; // 模擬成功
  }

  /// 執行更新任務動作
  Future<bool> _executeUpdateTask(OfflineAction action) async {
    // 這裡應該調用實際的任務更新 API
    print('執行更新任務: ${action.data}');
    return true; // 模擬成功
  }

  /// 執行檔案上傳動作
  Future<bool> _executeUploadFile(OfflineAction action) async {
    // 這裡應該調用實際的檔案上傳 API
    print('執行檔案上傳: ${action.data}');
    return true; // 模擬成功
  }

  /// 執行通用動作
  Future<bool> _executeGenericAction(OfflineAction action) async {
    // 這裡應該調用通用的 HTTP 客戶端
    print('執行通用動作: ${action.endpoint}');
    return true; // 模擬成功
  }

  /// 儲存離線佇列
  Future<void> _saveOfflineQueue() async {
    try {
      final cacheManager = CacheManager.instance;
      final queueData = _offlineQueue.map((action) => action.toJson()).toList();

      await cacheManager.cacheUserProfile(
        userId: 0, // 使用特殊 ID 儲存離線佇列
        profile: {'offline_queue': queueData},
        expiry: const Duration(days: 30),
      );
    } catch (e) {
      print('儲存離線佇列失敗: $e');
    }
  }

  /// 載入離線佇列
  Future<void> _loadOfflineQueue() async {
    try {
      final cacheManager = CacheManager.instance;
      final cachedData = await cacheManager.getCachedUserProfile(0);

      if (cachedData != null && cachedData['offline_queue'] != null) {
        final queueData = cachedData['offline_queue'] as List<dynamic>;
        _offlineQueue.clear();

        for (final actionData in queueData) {
          try {
            final action = OfflineAction.fromJson(actionData);
            _offlineQueue.add(action);
          } catch (e) {
            print('載入離線動作失敗: $e');
          }
        }

        print('載入離線佇列完成，共 ${_offlineQueue.length} 個動作');
      }
    } catch (e) {
      print('載入離線佇列失敗: $e');
    }
  }

  /// 清空離線佇列
  Future<void> clearOfflineQueue() async {
    _offlineQueue.clear();
    await _saveOfflineQueue();
    notifyListeners();
    print('離線佇列已清空');
  }

  /// 手動重試離線佇列
  Future<void> retryOfflineQueue() async {
    if (_isOnline) {
      await _processOfflineQueue();
    } else {
      print('網路未連接，無法重試離線佇列');
    }
  }

  /// 獲取連接狀態描述
  String getConnectionStatusText() {
    if (!_isOnline) {
      return '離線模式';
    }

    switch (_connectionType) {
      case 'connected':
        return '網路已連接';
      case 'disconnected':
        return '網路已斷線';
      case 'error':
        return '網路錯誤';
      default:
        return '未知狀態';
    }
  }

  /// 獲取離線統計資訊
  Map<String, dynamic> getOfflineStats() {
    final now = DateTime.now();
    final recentActions = _offlineQueue
        .where(
          (action) => now.difference(action.createdAt).inHours < 24,
        )
        .length;

    return {
      'isOnline': _isOnline,
      'connectionType': _connectionType,
      'queueSize': _offlineQueue.length,
      'recentActions': recentActions,
      'oldestAction': _offlineQueue.isNotEmpty
          ? _offlineQueue.first.createdAt.toIso8601String()
          : null,
    };
  }

  /// 釋放資源
  @override
  void dispose() {
    _networkCheckTimer?.cancel();
    super.dispose();
  }
}

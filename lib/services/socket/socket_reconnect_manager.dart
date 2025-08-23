import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../offline/offline_manager.dart';

/// Socket 重連管理器
/// 提供自動重連、退避策略和連接狀態管理
class SocketReconnectManager extends ChangeNotifier {
  static SocketReconnectManager? _instance;
  static SocketReconnectManager get instance =>
      _instance ??= SocketReconnectManager._();

  SocketReconnectManager._();

  // Socket 連接
  io.Socket? _socket;
  io.Socket? get socket => _socket;

  // 連接狀態
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isReconnecting = false;
  bool get isReconnecting => _isReconnecting;

  // 重連配置
  int _reconnectAttempts = 0;
  int get reconnectAttempts => _reconnectAttempts;

  static const int maxReconnectAttempts = 10;
  static const int baseDelayMs = 1000; // 基礎延遲 1 秒
  static const int maxDelayMs = 30000; // 最大延遲 30 秒
  static const double backoffMultiplier = 1.5; // 退避倍數
  static const double jitterFactor = 0.1; // 抖動因子

  // 計時器
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // 事件監聽器
  final Map<String, List<Function>> _eventListeners = {};

  // 離線管理器
  final OfflineManager _offlineManager = OfflineManager.instance;

  /// 連接到 Socket 伺服器
  Future<void> connect(String serverUrl,
      {Map<String, dynamic>? options}) async {
    if (_isConnected || _isConnecting) {
      print('Socket 已連接或正在連接中');
      return;
    }

    _isConnecting = true;
    notifyListeners();

    try {
      // 檢查網路狀態
      if (_offlineManager.isOffline) {
        print('網路離線，無法連接 Socket');
        _isConnecting = false;
        notifyListeners();
        return;
      }

      // 創建 Socket 連接
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 10000,
        'forceNew': true,
        ...?options,
      });

      _setupSocketListeners();

      // 開始連接
      _socket!.connect();

      print('開始連接 Socket: $serverUrl');
    } catch (e) {
      print('Socket 連接失敗: $e');
      _isConnecting = false;
      _handleConnectionError();
      notifyListeners();
    }
  }

  /// 設置 Socket 事件監聽器
  void _setupSocketListeners() {
    if (_socket == null) return;

    // 連接成功
    _socket!.on('connect', (_) {
      print('Socket 連接成功');
      _isConnected = true;
      _isConnecting = false;
      _isReconnecting = false;
      _reconnectAttempts = 0;

      _startHeartbeat();
      _cancelReconnectTimer();

      notifyListeners();
      _emitEvent('connected', null);
    });

    // 連接失敗
    _socket!.on('connect_error', (error) {
      print('Socket 連接錯誤: $error');
      _isConnected = false;
      _isConnecting = false;

      _handleConnectionError();
      notifyListeners();
      _emitEvent('connect_error', error);
    });

    // 連接斷開
    _socket!.on('disconnect', (reason) {
      print('Socket 連接斷開: $reason');
      _isConnected = false;
      _isConnecting = false;

      _stopHeartbeat();

      // 如果不是主動斷開，則嘗試重連
      if (reason != 'io client disconnect') {
        _handleConnectionLoss();
      }

      notifyListeners();
      _emitEvent('disconnected', reason);
    });

    // 重連嘗試
    _socket!.on('reconnect_attempt', (attemptNumber) {
      print('Socket 重連嘗試: $attemptNumber');
      _isReconnecting = true;
      notifyListeners();
      _emitEvent('reconnect_attempt', attemptNumber);
    });

    // 重連成功
    _socket!.on('reconnect', (attemptNumber) {
      print('Socket 重連成功，嘗試次數: $attemptNumber');
      _isReconnecting = false;
      _reconnectAttempts = 0;
      notifyListeners();
      _emitEvent('reconnected', attemptNumber);
    });

    // 重連失敗
    _socket!.on('reconnect_failed', (_) {
      print('Socket 重連失敗');
      _isReconnecting = false;
      notifyListeners();
      _emitEvent('reconnect_failed', null);
    });

    // Pong 回應（心跳）
    _socket!.on('pong', (_) {
      print('收到 Socket pong');
    });
  }

  /// 處理連接錯誤
  void _handleConnectionError() {
    _reconnectAttempts++;

    if (_reconnectAttempts <= maxReconnectAttempts) {
      _scheduleReconnect();
    } else {
      print('達到最大重連次數，停止重連');
      _emitEvent('max_reconnect_attempts_reached', _reconnectAttempts);
    }
  }

  /// 處理連接丟失
  void _handleConnectionLoss() {
    if (_offlineManager.isOffline) {
      print('網路離線，暫停重連');
      return;
    }

    _handleConnectionError();
  }

  /// 排程重連
  void _scheduleReconnect() {
    _cancelReconnectTimer();

    final delay = _calculateBackoffDelay();
    print('排程 Socket 重連，延遲: ${delay}ms');

    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_isConnected && !_isConnecting) {
        _attemptReconnect();
      }
    });
  }

  /// 計算退避延遲
  int _calculateBackoffDelay() {
    // 指數退避算法：baseDelay * (multiplier ^ attempts)
    final exponentialDelay =
        baseDelayMs * pow(backoffMultiplier, _reconnectAttempts - 1);

    // 限制最大延遲
    final clampedDelay = min(exponentialDelay, maxDelayMs.toDouble()).toInt();

    // 添加隨機抖動，避免雷群效應
    final jitter =
        (clampedDelay * jitterFactor * (Random().nextDouble() - 0.5)).toInt();

    return clampedDelay + jitter;
  }

  /// 嘗試重連
  Future<void> _attemptReconnect() async {
    if (_isConnected || _isConnecting) {
      return;
    }

    // 檢查網路狀態
    if (_offlineManager.isOffline) {
      print('網路離線，延遲重連');
      _scheduleReconnect();
      return;
    }

    print('嘗試 Socket 重連，第 $_reconnectAttempts 次');
    _isReconnecting = true;
    _isConnecting = true;
    notifyListeners();

    try {
      if (_socket != null) {
        _socket!.connect();
      }
    } catch (e) {
      print('重連失敗: $e');
      _isConnecting = false;
      _handleConnectionError();
      notifyListeners();
    }
  }

  /// 手動重連
  Future<void> manualReconnect() async {
    print('手動觸發 Socket 重連');
    _reconnectAttempts = 0;
    _cancelReconnectTimer();

    if (_isConnected) {
      disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await _attemptReconnect();
  }

  /// 斷開連接
  void disconnect() {
    print('主動斷開 Socket 連接');

    _cancelReconnectTimer();
    _stopHeartbeat();

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _isConnected = false;
    _isConnecting = false;
    _isReconnecting = false;
    _reconnectAttempts = 0;

    notifyListeners();
  }

  /// 發送事件
  void emit(String event, dynamic data) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
    } else {
      print('Socket 未連接，無法發送事件: $event');
    }
  }

  /// 監聽事件
  void on(String event, Function callback) {
    if (!_eventListeners.containsKey(event)) {
      _eventListeners[event] = [];
    }
    _eventListeners[event]!.add(callback);

    // 如果 Socket 已連接，直接設置監聽器
    if (_socket != null) {
      _socket!.on(event, (data) => callback(data));
    }
  }

  /// 移除事件監聽器
  void off(String event, [Function? callback]) {
    if (callback != null) {
      _eventListeners[event]?.remove(callback);
    } else {
      _eventListeners[event]?.clear();
    }

    if (_socket != null) {
      _socket!.off(event);
    }
  }

  /// 發出自定義事件
  void _emitEvent(String event, dynamic data) {
    final listeners = _eventListeners[event];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(data);
        } catch (e) {
          print('事件監聽器錯誤: $e');
        }
      }
    }
  }

  /// 開始心跳
  void _startHeartbeat() {
    _stopHeartbeat();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _socket != null) {
        _socket!.emit('ping');
      }
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 取消重連計時器
  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 獲取連接狀態描述
  String getConnectionStatusText() {
    if (_isConnected) {
      return 'Socket 已連接';
    } else if (_isConnecting) {
      return 'Socket 連接中...';
    } else if (_isReconnecting) {
      return 'Socket 重連中... ($_reconnectAttempts/$maxReconnectAttempts)';
    } else {
      return 'Socket 未連接';
    }
  }

  /// 獲取重連統計資訊
  Map<String, dynamic> getReconnectStats() {
    return {
      'isConnected': _isConnected,
      'isConnecting': _isConnecting,
      'isReconnecting': _isReconnecting,
      'reconnectAttempts': _reconnectAttempts,
      'maxReconnectAttempts': maxReconnectAttempts,
      'nextReconnectDelay': _reconnectAttempts < maxReconnectAttempts
          ? _calculateBackoffDelay()
          : null,
    };
  }

  /// 重置重連計數器
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
    notifyListeners();
  }

  /// 釋放資源
  @override
  void dispose() {
    disconnect();
    _eventListeners.clear();
    super.dispose();
  }
}

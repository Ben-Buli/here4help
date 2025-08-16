import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:here4help/auth/services/auth_service.dart';

/// 未讀訊息通知服務介面
abstract class NotificationService {
  // Streams
  Stream<int> observeTotalUnread();
  Stream<Map<String, int>> observeUnreadByTask();
  Stream<Map<String, int>> observeUnreadByRoom();
  Stream<ConnectionStatus> observeConnectionStatus();

  // Commands
  Future<void> markRoomRead(
      {required String roomId, required String upToMessageId});
  Future<void> markTaskRead(
      {required String taskId, required String upToMessageId});
  Future<void> refreshSnapshot();

  // Lifecycle
  Future<void> init({required String userId});
  Future<void> dispose();

  // Persistence (本地)
  Future<void> loadCache();
  Future<void> saveCache();
}

/// 連線狀態
enum ConnectionStatus { connected, disconnected, error, reconnecting }

/// 佔位實作（零未讀）
class NotificationServicePlaceholder implements NotificationService {
  static final NotificationServicePlaceholder _instance =
      NotificationServicePlaceholder._internal();
  factory NotificationServicePlaceholder() => _instance;
  NotificationServicePlaceholder._internal();

  StreamController<int> _totalUnreadController =
      StreamController<int>.broadcast();
  StreamController<Map<String, int>> _byTaskController =
      StreamController<Map<String, int>>.broadcast();
  StreamController<Map<String, int>> _byRoomController =
      StreamController<Map<String, int>>.broadcast();
  StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  Map<String, int> _unreadByTask = const {};
  Map<String, int> _unreadByRoom = const {};
  int _totalUnread = 0;

  @override
  Stream<int> observeTotalUnread() => _totalUnreadController.stream;

  @override
  Stream<Map<String, int>> observeUnreadByTask() => _byTaskController.stream;

  @override
  Stream<Map<String, int>> observeUnreadByRoom() => _byRoomController.stream;
  @override
  Stream<ConnectionStatus> observeConnectionStatus() =>
      _statusController.stream;

  bool _disposed = false;

  void _safeAdd<T>(StreamController<T> controller, T value) {
    if (_disposed) return;
    try {
      // 某些情況下 controller 可能已關閉，使用 try/catch 保護
      controller.add(value);
    } catch (_) {}
  }

  void _emitAll() {
    _safeAdd<int>(_totalUnreadController, _totalUnread);
    _safeAdd<Map<String, int>>(_byTaskController, _unreadByTask);
    _safeAdd<Map<String, int>>(_byRoomController, _unreadByRoom);
  }

  @override
  Future<void> init({required String userId}) async {
    // 佔位：全部 0
    _disposed = false;

    // 如果 StreamController 已經關閉，重新創建
    if (_totalUnreadController.isClosed) {
      _totalUnreadController = StreamController<int>.broadcast();
    }
    if (_byTaskController.isClosed) {
      _byTaskController = StreamController<Map<String, int>>.broadcast();
    }
    if (_byRoomController.isClosed) {
      _byRoomController = StreamController<Map<String, int>>.broadcast();
    }
    if (_statusController.isClosed) {
      _statusController = StreamController<ConnectionStatus>.broadcast();
    }

    _unreadByTask = const {};
    _unreadByRoom = const {};
    _totalUnread = 0;
    _emitAll();
    _safeAdd<ConnectionStatus>(
        _statusController, ConnectionStatus.disconnected);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _totalUnreadController.close();
    await _byTaskController.close();
    await _byRoomController.close();
    await _statusController.close();
  }

  @override
  Future<void> loadCache() async {
    // 佔位：不做事
  }

  @override
  Future<void> saveCache() async {
    // 佔位：不做事
  }

  @override
  Future<void> markRoomRead(
      {required String roomId, required String upToMessageId}) async {
    // 佔位：不做事，但仍觸發一次廣播以確保 UI 有更新機會
    _emitAll();
  }

  @override
  Future<void> markTaskRead(
      {required String taskId, required String upToMessageId}) async {
    // 佔位：不做事
    _emitAll();
  }

  @override
  Future<void> refreshSnapshot() async {
    // 佔位：全部 0
    _emitAll();
  }
}

/// Socket.IO 未讀服務（MVP）
class SocketNotificationService implements NotificationService {
  static final SocketNotificationService _instance =
      SocketNotificationService._internal();
  factory SocketNotificationService() => _instance;
  SocketNotificationService._internal();

  final StreamController<int> _totalUnreadController =
      StreamController<int>.broadcast();
  final StreamController<Map<String, int>> _byTaskController =
      StreamController<Map<String, int>>.broadcast();
  final StreamController<Map<String, int>> _byRoomController =
      StreamController<Map<String, int>>.broadcast();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  final Map<String, int> _unreadByTask = const {};
  Map<String, int> _unreadByRoom = const {};
  int _totalUnread = 0;

  io.Socket? _socket; // assigned in init

  @override
  Stream<int> observeTotalUnread() => _totalUnreadController.stream;

  @override
  Stream<Map<String, int>> observeUnreadByTask() => _byTaskController.stream;

  @override
  Stream<Map<String, int>> observeUnreadByRoom() => _byRoomController.stream;
  @override
  Stream<ConnectionStatus> observeConnectionStatus() =>
      _statusController.stream;

  bool _disposed2 = false;

  void _safeAdd2<T>(StreamController<T> controller, T value) {
    if (_disposed2) return;
    try {
      controller.add(value);
    } catch (_) {}
  }

  void _emitAll() {
    _safeAdd2<int>(_totalUnreadController, _totalUnread);
    _safeAdd2<Map<String, int>>(_byTaskController, _unreadByTask);
    _safeAdd2<Map<String, int>>(_byRoomController, _unreadByRoom);
  }

  @override
  Future<void> init({required String userId}) async {
    _disposed2 = false;
    final token = await _getToken();
    _socket = io.io(
        AppConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': token})
            .enableAutoConnect()
            .build());

    _socket?.on('connect', (_) {
      // request snapshot via REST
      refreshSnapshot();
      _statusController.add(ConnectionStatus.connected);
    });
    _socket?.on('unread_total', (data) {
      final total = (data is Map && data['total'] is num)
          ? (data['total'] as num).toInt()
          : 0;
      _totalUnread = total;
      _emitAll();
    });
    _socket?.on('unread_by_room', (data) {
      if (data is Map && data['by_room'] is Map) {
        final raw = Map<String, dynamic>.from(data['by_room']);
        _unreadByRoom = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
        _emitAll();
      }
    });
    _socket?.on('disconnect', (_) {
      _statusController.add(ConnectionStatus.disconnected);
    });
    _socket?.on('connect_error', (_) {
      _statusController.add(ConnectionStatus.error);
    });
    _socket?.on('reconnect_attempt', (_) {
      _statusController.add(ConnectionStatus.reconnecting);
    });
    _socket?.on('reconnect', (_) {
      _statusController.add(ConnectionStatus.connected);
    });
  }

  @override
  Future<void> dispose() async {
    try {
      _socket?.dispose();
    } catch (_) {}
    _disposed2 = true;
    await _totalUnreadController.close();
    await _byTaskController.close();
    await _byRoomController.close();
    await _statusController.close();
  }

  @override
  Future<void> loadCache() async {}

  @override
  Future<void> saveCache() async {}

  @override
  Future<void> markRoomRead(
      {required String roomId, required String upToMessageId}) async {
    _socket
        ?.emit('read_room', {'roomId': roomId, 'upToMessageId': upToMessageId});
    // 同步到後端 DB
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(AppConfig.chatReadRoomV2Url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'room_id': roomId}),
      );
    } catch (_) {}
  }

  @override
  Future<void> markTaskRead(
      {required String taskId, required String upToMessageId}) async {}

  @override
  Future<void> refreshSnapshot() async {
    try {
      final token = await _getToken();
      final resp = await http.get(
        Uri.parse(AppConfig.unreadByTasksUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] is Map) {
          final d = Map<String, dynamic>.from(data['data']);
          _totalUnread = (d['total'] as num?)?.toInt() ?? 0;
          final byRoom = Map<String, dynamic>.from(d['by_room'] ?? {});
          _unreadByRoom = byRoom.map((k, v) => MapEntry(k, (v as num).toInt()));
          _emitAll();
        }
      }
    } catch (_) {}
  }

  Future<String> _getToken() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token for socket connection');
    }
    return token;
  }

  // Chat controls (MVP)
  void joinRoom(String roomId) {
    _socket?.emit('join_room', {'roomId': roomId});
  }

  void leaveRoom(String roomId) {
    _socket?.emit('leave_room', {'roomId': roomId});
  }

  void sendMessage(
      {required String roomId,
      required String text,
      List<String> toUserIds = const []}) {
    _socket?.emit('send_message', {
      'roomId': roomId,
      'text': text,
      'toUserIds': toUserIds,
    });
  }

  void addMessageListener(void Function(dynamic data) handler) {
    _socket?.on('message', handler);
  }

  void removeMessageListener(void Function(dynamic data) handler) {
    _socket?.off('message', handler);
  }

  void addTypingListener(void Function(dynamic data) handler) {
    _socket?.on('typing', handler);
  }

  void removeTypingListener(void Function(dynamic data) handler) {
    _socket?.off('typing', handler);
  }
}

/// 全域通知中心：固定輸出 Stream，不受實作切換影響
class NotificationCenter {
  static final NotificationCenter _instance = NotificationCenter._internal();
  factory NotificationCenter() => _instance;
  NotificationCenter._internal();

  NotificationService _service = NotificationServicePlaceholder();
  bool _isInitialized = false; // 新增：追蹤初始化狀態

  final StreamController<int> _totalUnreadForwarder =
      StreamController<int>.broadcast();
  final StreamController<Map<String, int>> _byTaskForwarder =
      StreamController<Map<String, int>>.broadcast();
  final StreamController<Map<String, int>> _byRoomForwarder =
      StreamController<Map<String, int>>.broadcast();
  final StreamController<ConnectionStatus> _statusForwarder =
      StreamController<ConnectionStatus>.broadcast();

  StreamSubscription<int>? _s1;
  StreamSubscription<Map<String, int>>? _s2;
  StreamSubscription<Map<String, int>>? _s3;
  StreamSubscription<ConnectionStatus>? _s4;

  Stream<int> get totalUnreadStream => _totalUnreadForwarder.stream;
  Stream<Map<String, int>> get byTaskStream => _byTaskForwarder.stream;
  Stream<Map<String, int>> get byRoomStream => _byRoomForwarder.stream;
  Stream<ConnectionStatus> get connectionStatusStream =>
      _statusForwarder.stream;

  NotificationService get service => _service;
  bool get isInitialized => _isInitialized; // 新增：檢查初始化狀態

  Future<void> use(NotificationService service) async {
    await _s1?.cancel();
    await _s2?.cancel();
    await _s3?.cancel();
    await _s4?.cancel();
    _service = service;
    _s1 = _service.observeTotalUnread().listen(_totalUnreadForwarder.add);
    _s2 = _service.observeUnreadByTask().listen(_byTaskForwarder.add);
    _s3 = _service.observeUnreadByRoom().listen(_byRoomForwarder.add);
    _s4 = _service.observeConnectionStatus().listen(_statusForwarder.add);

    // 標記為已初始化
    _isInitialized = true;
    print('✅ NotificationCenter 已初始化完成');
  }

  /// 等待未讀數據載入完成
  Future<void> waitForUnreadData(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_isInitialized && _service is! NotificationServicePlaceholder) {
      print('✅ NotificationCenter 已初始化，直接返回');
      return;
    }

    print('⏳ 等待 NotificationCenter 初始化...');
    final startTime = DateTime.now();

    while (!_isInitialized || _service is NotificationServicePlaceholder) {
      if (DateTime.now().difference(startTime) > timeout) {
        print('⚠️ NotificationCenter 初始化超時，使用佔位服務');
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('✅ NotificationCenter 初始化等待完成');
  }

  Future<void> dispose() async {
    await _s1?.cancel();
    await _s2?.cancel();
    await _s3?.cancel();
    await _s4?.cancel();
    await _totalUnreadForwarder.close();
    await _byTaskForwarder.close();
    await _byRoomForwarder.close();
    await _statusForwarder.close();
  }
}

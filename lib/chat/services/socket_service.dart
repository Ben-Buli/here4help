import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/config/app_config.dart';
import 'package:flutter/foundation.dart';

/// Socket.IO 即時聊天服務
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  final Set<String> _pendingJoinRooms = <String>{};

  // 監聽器
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(Map<String, dynamic>)? onUnreadUpdate;
  Function(Map<String, dynamic>)? onTypingUpdate;

  /// 初始化並連接 Socket.IO
  Future<void> connect() async {
    if (_isConnected && _socket != null) {
      debugPrint('🔌 Socket already connected');
      return;
    }

    try {
      // 獲取認證 token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userId = prefs.getInt('user_id');

      if (token == null || userId == null) {
        debugPrint('❌ No auth token or user ID found');
        return;
      }

      _currentUserId = userId.toString();

      if (kDebugMode) {
        debugPrint(
            '🔍 Socket 連接配置: userId=$_currentUserId, token=${token.substring(0, 20)}...');
      }

      // Socket.IO 連接配置
      final socketUrl = AppConfig.socketUrl;

      if (kDebugMode) {
        debugPrint('🔍 Socket URL: $socketUrl');
      }

      _socket = io.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'token': token,
        },
        'timeout': 10000, // 10 秒超時
        'forceNew': true, // 強制新連接
      });

      // 連接事件
      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('✅ Socket connected for user $_currentUserId');

        // Auto-join any rooms that were queued before connection
        if (_pendingJoinRooms.isNotEmpty) {
          for (final roomId in _pendingJoinRooms) {
            _socket!.emit('join_room', {'roomId': roomId});
            debugPrint('🏠 Auto-joined queued room: $roomId');
          }
          _pendingJoinRooms.clear();
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('❌ Socket disconnected');
      });

      _socket!.onConnectError((error) {
        debugPrint('❌ Socket connection error: $error');
      });

      // 聊天事件監聽
      _setupEventListeners();

      // 開始連接
      _socket!.connect();
    } catch (e) {
      debugPrint('❌ Socket connection failed: $e');
    }
  }

  /// 設置事件監聽器
  void _setupEventListeners() {
    if (_socket == null) return;

    if (kDebugMode) {
      debugPrint('🔍 設置 Socket 事件監聽器');
    }

    // 收到新訊息
    _socket!.on('message', (data) {
      if (kDebugMode) {
        debugPrint('📨 Received message: $data');
      }
      if (onMessageReceived != null) {
        onMessageReceived!(Map<String, dynamic>.from(data));
      }
    });

    // 未讀數量更新
    _socket!.on('unread_total', (data) {
      // debugPrint('🔔 Unread total updated: $data');
      if (onUnreadUpdate != null) {
        onUnreadUpdate!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('unread_by_room', (data) {
      // debugPrint('🔔 Unread by room updated: $data');
      if (onUnreadUpdate != null) {
        onUnreadUpdate!(Map<String, dynamic>.from(data));
      }
    });

    // 打字狀態
    _socket!.on('typing', (data) {
      debugPrint('⌨️ Typing update: $data');
      if (onTypingUpdate != null) {
        onTypingUpdate!(Map<String, dynamic>.from(data));
      }
    });
  }

  /// 加入聊天室
  void joinRoom(String roomId) {
    if (!_isConnected || _socket == null) {
      // Queue the room join until we connect
      _pendingJoinRooms.add(roomId);
      debugPrint('⏳ Socket not connected, queued join for room: $roomId');
      return;
    }

    _socket!.emit('join_room', {'roomId': roomId});
    debugPrint('🏠 Joined room: $roomId');
  }

  /// 離開聊天室
  void leaveRoom(String roomId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit('leave_room', {'roomId': roomId});
    debugPrint('🚪 Left room: $roomId');
  }

  /// 發送訊息
  void sendMessage({
    required String roomId,
    required String text,
    String? messageId,
    List<String>? toUserIds,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('❌ Socket not connected, cannot send message');
      return;
    }

    final data = {
      'roomId': roomId,
      'text': text,
      'messageId': messageId,
      'toUserIds': toUserIds,
    };

    _socket!.emit('send_message', data);
    debugPrint('💬 Sent message to room $roomId: $text');
  }

  /// 標記聊天室為已讀
  void markRoomAsRead(String roomId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit('read_room', {'roomId': roomId});
    debugPrint('✅ Marked room $roomId as read');
  }

  /// 發送打字狀態
  void sendTypingStatus({
    required String roomId,
    required bool isTyping,
  }) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit('typing', {
      'roomId': roomId,
      'isTyping': isTyping,
    });
  }

  /// 斷開連接
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
    _isConnected = false;
    _currentUserId = null;
    debugPrint('🔌 Socket disconnected');
  }

  /// 檢查連接狀態
  bool get isConnected => _isConnected && _socket != null;

  /// 獲取當前用戶ID
  String? get currentUserId => _currentUserId;
}

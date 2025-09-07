import 'dart:async';
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
  String? _lastRoomIdToJoin;

  // 廣播新訊息的 Stream（支援多處監聽）
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 監聽器
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(Map<String, dynamic>)? onUnreadUpdate;
  Function(Map<String, dynamic>)? onTypingUpdate;
  // 新增：任務狀態變化監聽器
  Function(Map<String, dynamic>)? onTaskStatusUpdate;
  Function(Map<String, dynamic>)? onApplicationStatusUpdate;
  // 新增：封鎖狀態變化監聽器
  Function(Map<String, dynamic>)? onBlockStatusUpdate;

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

      // Socket.IO 連接配置
      final socketUrl = AppConfig.socketUrl;

      _socket = io.io(socketUrl, <String, dynamic>{
        'transports': <String>['websocket'], // 明確指定為 List<String>
        'autoConnect': false,
        'query': <String, String>{
          // 明確指定為 Map<String, String>
          'token': token,
        },
        'forceNew': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      // 連接事件
      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint(
            '✅ Socket connected for user $_currentUserId, url: ${AppConfig.socketUrl}');

        // Auto-join any rooms that were queued before connection
        if (_pendingJoinRooms.isNotEmpty) {
          for (final roomId in _pendingJoinRooms) {
            _socket!.emit('join_room', {'roomId': roomId});
            debugPrint('🏠 Auto-joined queued room: $roomId');
          }
          _pendingJoinRooms.clear();
        }

        // 保險：若有最後一次想加入的房間，再強制補送一次 join
        if (_lastRoomIdToJoin != null && _lastRoomIdToJoin!.isNotEmpty) {
          _socket!.emit('join_room', {'roomId': _lastRoomIdToJoin});
          debugPrint(
              '🏠 Force-joined last requested room: ${_lastRoomIdToJoin!}');
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

    // 收到新訊息
    _socket!.on('message', (data) {
      debugPrint('📨 Received message: $data');
      try {
        final messageData = Map<String, dynamic>.from(data as Map);
        // 廣播到通用訊息流
        _messageController.add(messageData);
      } catch (e) {
        debugPrint('❌ Error broadcasting message data: $e');
      }
      if (onMessageReceived != null) {
        try {
          final messageData = Map<String, dynamic>.from(data as Map);
          onMessageReceived!(messageData);
        } catch (e) {
          debugPrint('❌ Error parsing message data: $e');
        }
      }
    });

    // 未讀數量更新
    _socket!.on('unread_total', (data) {
      // debugPrint('🔔 Unread total updated: $data');
      if (onUnreadUpdate != null) {
        try {
          final unreadData = Map<String, dynamic>.from(data as Map);
          onUnreadUpdate!(unreadData);
        } catch (e) {
          debugPrint('❌ Error parsing unread_total data: $e');
        }
      }
    });

    _socket!.on('unread_by_room', (data) {
      // debugPrint('🔔 Unread by room updated: $data');
      if (onUnreadUpdate != null) {
        try {
          final unreadData = Map<String, dynamic>.from(data as Map);
          onUnreadUpdate!(unreadData);
        } catch (e) {
          debugPrint('❌ Error parsing unread_by_room data: $e');
        }
      }
    });

    // 打字狀態
    _socket!.on('typing', (data) {
      debugPrint('⌨️ Typing update: $data');
      if (onTypingUpdate != null) {
        try {
          final typingData = Map<String, dynamic>.from(data as Map);
          onTypingUpdate!(typingData);
        } catch (e) {
          debugPrint('❌ Error parsing typing data: $e');
        }
      }
    });

    // 任務狀態更新
    _socket!.on('task_status_update', (data) {
      debugPrint('📋 Task status update: $data');
      if (onTaskStatusUpdate != null) {
        try {
          final statusData = Map<String, dynamic>.from(data as Map);
          onTaskStatusUpdate!(statusData);
        } catch (e) {
          debugPrint('❌ Error parsing task status data: $e');
        }
      }
    });

    // 應徵狀態更新
    _socket!.on('application_status_update', (data) {
      debugPrint('📝 Application status update: $data');
      if (onApplicationStatusUpdate != null) {
        try {
          final applicationData = Map<String, dynamic>.from(data as Map);
          onApplicationStatusUpdate!(applicationData);
        } catch (e) {
          debugPrint('❌ Error parsing application status data: $e');
        }
      }
    });

    // 封鎖狀態更新
    _socket!.on('block_status_update', (data) {
      debugPrint('🚫 Block status update: $data');
      if (onBlockStatusUpdate != null) {
        try {
          final blockData = Map<String, dynamic>.from(data as Map);
          onBlockStatusUpdate!(blockData);
        } catch (e) {
          debugPrint('❌ Error parsing block status data: $e');
        }
      }
    });
  }

  /// 加入聊天室
  void joinRoom(String roomId) {
    if (!_isConnected || _socket == null) {
      // Queue the room join until we connect
      _pendingJoinRooms.add(roomId);
      _lastRoomIdToJoin = roomId;
      debugPrint('⏳ Socket not connected, queued join for room: $roomId');
      return;
    }

    _socket!.emit('join_room', <String, String>{'roomId': roomId});
    _lastRoomIdToJoin = roomId;
    debugPrint('🏠 Joined room: $roomId');
  }

  /// 離開聊天室
  void leaveRoom(String roomId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit('leave_room', <String, String>{'roomId': roomId});
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

    final data = <String, dynamic>{
      'roomId': roomId,
      'text': text,
    };

    if (messageId != null) {
      data['messageId'] = messageId;
    }

    if (toUserIds != null) {
      data['toUserIds'] = toUserIds;
    }

    _socket!.emit('send_message', data);
    debugPrint('💬 Sent message to room $roomId: $text');
  }

  /// 標記聊天室為已讀
  void markRoomAsRead(String roomId) {
    // 先保險確保已加入房間（若未連線會排佇列，連上後會強制補送 join）
    try {
      joinRoom(roomId);
    } catch (_) {}

    if (!_isConnected || _socket == null) {
      debugPrint('⏳ Socket not connected, queued read for room: $roomId');
      return;
    }

    _socket!.emit('read_room', <String, String>{'roomId': roomId});
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

    _socket!.emit('typing', <String, dynamic>{
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

    // 清除所有待處理的房間和狀態
    _pendingJoinRooms.clear();
    _lastRoomIdToJoin = null;

    // 清除監聽器
    onMessageReceived = null;
    onUnreadUpdate = null;
    onTypingUpdate = null;
    onTaskStatusUpdate = null;
    onApplicationStatusUpdate = null;
    onBlockStatusUpdate = null;

    debugPrint('🔌 Socket disconnected and state cleared');
  }

  /// 檢查連接狀態
  bool get isConnected => _isConnected && _socket != null;

  /// 獲取當前用戶ID
  String? get currentUserId => _currentUserId;

  /// 提供指定房間的即時訊息 Stream（會自動嘗試連線並加入房間）
  Stream<Map<String, dynamic>> messagesForRoom(String roomId) {
    // 確保連線（背景連線即可）
    // ignore: discarded_futures
    connect();
    // 嘗試加入房間（若未連線會排入佇列）
    joinRoom(roomId);
    // 過濾該房間的訊息
    return _messageController.stream.where(
        (m) => (m['roomId']?.toString() ?? m['room_id']?.toString()) == roomId);
  }
}

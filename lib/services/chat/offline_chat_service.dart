import 'dart:async';
import 'package:flutter/foundation.dart';
import '../socket/socket_reconnect_manager.dart';
import '../cache/cache_manager.dart';
import '../offline/offline_manager.dart';

/// 待發送訊息資料結構
class PendingMessage {
  final String tempId;
  final int chatRoomId;
  final String content;
  final String type;
  final DateTime createdAt;
  final int retryCount;

  PendingMessage({
    required this.tempId,
    required this.chatRoomId,
    required this.content,
    required this.type,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingMessage copyWith({int? retryCount}) => PendingMessage(
        tempId: tempId,
        chatRoomId: chatRoomId,
        content: content,
        type: type,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );

  Map<String, dynamic> toJson() => {
        'tempId': tempId,
        'chatRoomId': chatRoomId,
        'content': content,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
        tempId: json['tempId'],
        chatRoomId: json['chatRoomId'],
        content: json['content'],
        type: json['type'],
        createdAt: DateTime.parse(json['createdAt']),
        retryCount: json['retryCount'] ?? 0,
      );
}

/// 離線感知的聊天服務
/// 提供聊天室的離線支援、訊息快取和自動重連功能
class OfflineChatService extends ChangeNotifier {
  static OfflineChatService? _instance;
  static OfflineChatService get instance =>
      _instance ??= OfflineChatService._();

  OfflineChatService._() {
    _initialize();
  }

  // 服務依賴
  final SocketReconnectManager _socketManager = SocketReconnectManager.instance;
  final CacheManager _cacheManager = CacheManager.instance;
  final OfflineManager _offlineManager = OfflineManager.instance;

  // 聊天室狀態
  final Map<int, List<Map<String, dynamic>>> _chatRoomMessages = {};
  final Map<int, bool> _joinedRooms = {};
  final Set<String> _pendingMessages = {};

  // 訊息佇列
  final List<PendingMessage> _messageQueue = [];

  /// 初始化服務
  void _initialize() {
    // 監聽 Socket 連接狀態
    _socketManager.on('connected', _onSocketConnected);
    _socketManager.on('disconnected', _onSocketDisconnected);
    _socketManager.on('reconnected', _onSocketReconnected);

    // 監聽離線狀態
    _offlineManager.addListener(_onOfflineStatusChanged);

    // 設置訊息監聽器
    _setupMessageListeners();

    // 載入待發送訊息
    _loadPendingMessages();
  }

  /// Socket 連接成功處理
  void _onSocketConnected(dynamic data) {
    print('聊天服務：Socket 已連接');
    _processPendingMessages();
    _rejoinChatRooms();
  }

  /// Socket 斷開連接處理
  void _onSocketDisconnected(dynamic reason) {
    print('聊天服務：Socket 已斷開 - $reason');
  }

  /// Socket 重連成功處理
  void _onSocketReconnected(dynamic attemptNumber) {
    print('聊天服務：Socket 重連成功 - 嘗試次數: $attemptNumber');
    _processPendingMessages();
    _rejoinChatRooms();
  }

  /// 離線狀態變更處理
  void _onOfflineStatusChanged() {
    if (_offlineManager.isOnline && _socketManager.isConnected) {
      _processPendingMessages();
    }
  }

  /// 設置訊息監聽器
  void _setupMessageListeners() {
    _socketManager.on('message', _onMessageReceived);
    _socketManager.on('message_sent', _onMessageSent);
    _socketManager.on('message_error', _onMessageError);
    _socketManager.on('user_joined', _onUserJoined);
    _socketManager.on('user_left', _onUserLeft);
  }

  /// 收到訊息處理
  void _onMessageReceived(dynamic data) {
    try {
      final message = Map<String, dynamic>.from(data);
      final chatRoomId = message['chat_room_id'] as int;

      // 添加到本地訊息列表
      if (!_chatRoomMessages.containsKey(chatRoomId)) {
        _chatRoomMessages[chatRoomId] = [];
      }

      _chatRoomMessages[chatRoomId]!.add(message);

      // 快取訊息
      _cacheRoomMessages(chatRoomId);

      notifyListeners();

      print('收到新訊息：聊天室 $chatRoomId');
    } catch (e) {
      print('處理收到訊息失敗: $e');
    }
  }

  /// 訊息發送成功處理
  void _onMessageSent(dynamic data) {
    try {
      final response = Map<String, dynamic>.from(data);
      final tempId = response['temp_id'] as String?;
      final chatRoomId = response['chat_room_id'] as int;

      if (tempId != null) {
        // 移除待發送標記
        _pendingMessages.remove(tempId);

        // 移除佇列中的訊息
        _messageQueue.removeWhere((msg) => msg.tempId == tempId);

        // 更新本地訊息狀態
        _updateLocalMessageStatus(chatRoomId, tempId, 'sent', response);

        // 儲存佇列
        _savePendingMessages();

        notifyListeners();

        print('訊息發送成功：$tempId');
      }
    } catch (e) {
      print('處理訊息發送成功失敗: $e');
    }
  }

  /// 訊息發送錯誤處理
  void _onMessageError(dynamic data) {
    try {
      final error = Map<String, dynamic>.from(data);
      final tempId = error['temp_id'] as String?;

      if (tempId != null) {
        // 移除待發送標記
        _pendingMessages.remove(tempId);

        // 增加重試次數或移除訊息
        final messageIndex =
            _messageQueue.indexWhere((msg) => msg.tempId == tempId);
        if (messageIndex != -1) {
          final message = _messageQueue[messageIndex];
          if (message.retryCount < 3) {
            _messageQueue[messageIndex] =
                message.copyWith(retryCount: message.retryCount + 1);
          } else {
            _messageQueue.removeAt(messageIndex);
            _updateLocalMessageStatus(
                message.chatRoomId, tempId, 'failed', error);
          }
        }

        // 儲存佇列
        _savePendingMessages();

        notifyListeners();

        print('訊息發送失敗：$tempId - ${error['message']}');
      }
    } catch (e) {
      print('處理訊息發送錯誤失敗: $e');
    }
  }

  /// 用戶加入聊天室處理
  void _onUserJoined(dynamic data) {
    print('用戶加入聊天室: $data');
    notifyListeners();
  }

  /// 用戶離開聊天室處理
  void _onUserLeft(dynamic data) {
    print('用戶離開聊天室: $data');
    notifyListeners();
  }

  /// 加入聊天室
  Future<void> joinChatRoom(int chatRoomId) async {
    try {
      // 標記為已加入
      _joinedRooms[chatRoomId] = true;

      // 載入快取的訊息
      await _loadCachedMessages(chatRoomId);

      // 如果 Socket 已連接，發送加入請求
      if (_socketManager.isConnected) {
        _socketManager.emit('join_room', {'chat_room_id': chatRoomId});
        print('加入聊天室: $chatRoomId');
      } else {
        print('Socket 未連接，聊天室 $chatRoomId 將在連接後自動加入');
      }

      notifyListeners();
    } catch (e) {
      print('加入聊天室失敗: $e');
    }
  }

  /// 離開聊天室
  void leaveChatRoom(int chatRoomId) {
    try {
      // 移除加入標記
      _joinedRooms.remove(chatRoomId);

      // 如果 Socket 已連接，發送離開請求
      if (_socketManager.isConnected) {
        _socketManager.emit('leave_room', {'chat_room_id': chatRoomId});
        print('離開聊天室: $chatRoomId');
      }

      notifyListeners();
    } catch (e) {
      print('離開聊天室失敗: $e');
    }
  }

  /// 發送訊息
  Future<String> sendMessage({
    required int chatRoomId,
    required String content,
    String type = 'text',
  }) async {
    final tempId = '${DateTime.now().millisecondsSinceEpoch}_$chatRoomId';

    try {
      // 創建本地訊息
      final localMessage = {
        'temp_id': tempId,
        'chat_room_id': chatRoomId,
        'content': content,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'sending',
        'is_local': true,
      };

      // 添加到本地訊息列表
      if (!_chatRoomMessages.containsKey(chatRoomId)) {
        _chatRoomMessages[chatRoomId] = [];
      }
      _chatRoomMessages[chatRoomId]!.add(localMessage);

      // 如果在線且 Socket 已連接，直接發送
      if (_offlineManager.isOnline && _socketManager.isConnected) {
        _pendingMessages.add(tempId);

        _socketManager.emit('send_message', {
          'temp_id': tempId,
          'chat_room_id': chatRoomId,
          'content': content,
          'type': type,
        });

        print('發送訊息：聊天室 $chatRoomId');
      } else {
        // 添加到待發送佇列
        final pendingMessage = PendingMessage(
          tempId: tempId,
          chatRoomId: chatRoomId,
          content: content,
          type: type,
          createdAt: DateTime.now(),
        );

        _messageQueue.add(pendingMessage);
        await _savePendingMessages();

        // 更新本地訊息狀態
        localMessage['status'] = 'queued';

        print('訊息已加入佇列：聊天室 $chatRoomId（離線模式）');
      }

      // 快取訊息
      await _cacheRoomMessages(chatRoomId);

      notifyListeners();
      return tempId;
    } catch (e) {
      print('發送訊息失敗: $e');
      rethrow;
    }
  }

  /// 獲取聊天室訊息
  List<Map<String, dynamic>> getChatRoomMessages(int chatRoomId) {
    return _chatRoomMessages[chatRoomId] ?? [];
  }

  /// 處理待發送訊息
  Future<void> _processPendingMessages() async {
    if (_messageQueue.isEmpty || !_socketManager.isConnected) {
      return;
    }

    final messagesToProcess = List<PendingMessage>.from(_messageQueue);

    for (final message in messagesToProcess) {
      if (!_pendingMessages.contains(message.tempId)) {
        _pendingMessages.add(message.tempId);

        _socketManager.emit('send_message', {
          'temp_id': message.tempId,
          'chat_room_id': message.chatRoomId,
          'content': message.content,
          'type': message.type,
        });

        print('重新發送待發送訊息：${message.tempId}');
      }
    }
  }

  /// 重新加入聊天室
  void _rejoinChatRooms() {
    for (final chatRoomId in _joinedRooms.keys) {
      if (_joinedRooms[chatRoomId] == true) {
        _socketManager.emit('join_room', {'chat_room_id': chatRoomId});
        print('重新加入聊天室: $chatRoomId');
      }
    }
  }

  /// 載入快取的訊息
  Future<void> _loadCachedMessages(int chatRoomId) async {
    try {
      final cachedMessages =
          await _cacheManager.getCachedUserProfile(chatRoomId);

      if (cachedMessages != null && cachedMessages['messages'] != null) {
        final messages = cachedMessages['messages'] as List<dynamic>;
        _chatRoomMessages[chatRoomId] = messages.cast<Map<String, dynamic>>();

        print('載入聊天室 $chatRoomId 的快取訊息，共 ${messages.length} 筆');
        notifyListeners();
      }
    } catch (e) {
      print('載入快取訊息失敗: $e');
    }
  }

  /// 快取聊天室訊息
  Future<void> _cacheRoomMessages(int chatRoomId) async {
    try {
      final messages = _chatRoomMessages[chatRoomId] ?? [];

      // 只快取最新的 50 筆訊息
      final messagesToCache = messages.length > 50
          ? messages.sublist(messages.length - 50)
          : messages;

      await _cacheManager.cacheUserProfile(
        userId: chatRoomId,
        profile: {'messages': messagesToCache},
        expiry: const Duration(days: 7),
      );
    } catch (e) {
      print('快取訊息失敗: $e');
    }
  }

  /// 更新本地訊息狀態
  void _updateLocalMessageStatus(int chatRoomId, String tempId, String status,
      Map<String, dynamic>? data) {
    final messages = _chatRoomMessages[chatRoomId];
    if (messages != null) {
      final messageIndex =
          messages.indexWhere((msg) => msg['temp_id'] == tempId);
      if (messageIndex != -1) {
        messages[messageIndex]['status'] = status;
        if (data != null) {
          messages[messageIndex].addAll(data);
        }
      }
    }
  }

  /// 儲存待發送訊息
  Future<void> _savePendingMessages() async {
    try {
      final queueData = _messageQueue.map((msg) => msg.toJson()).toList();

      await _cacheManager.cacheUserProfile(
        userId: -1, // 使用特殊 ID 儲存訊息佇列
        profile: {'message_queue': queueData},
        expiry: const Duration(days: 30),
      );
    } catch (e) {
      print('儲存待發送訊息失敗: $e');
    }
  }

  /// 載入待發送訊息
  Future<void> _loadPendingMessages() async {
    try {
      final cachedData = await _cacheManager.getCachedUserProfile(-1);

      if (cachedData != null && cachedData['message_queue'] != null) {
        final queueData = cachedData['message_queue'] as List<dynamic>;
        _messageQueue.clear();

        for (final messageData in queueData) {
          try {
            final message = PendingMessage.fromJson(messageData);
            _messageQueue.add(message);
          } catch (e) {
            print('載入待發送訊息失敗: $e');
          }
        }

        print('載入待發送訊息完成，共 ${_messageQueue.length} 筆');
      }
    } catch (e) {
      print('載入待發送訊息失敗: $e');
    }
  }

  /// 清空聊天室訊息
  void clearChatRoomMessages(int chatRoomId) {
    _chatRoomMessages.remove(chatRoomId);
    notifyListeners();
  }

  /// 獲取待發送訊息統計
  Map<String, dynamic> getPendingMessageStats() {
    return {
      'queueSize': _messageQueue.length,
      'pendingCount': _pendingMessages.length,
      'joinedRooms': _joinedRooms.length,
    };
  }

  /// 釋放資源
  @override
  void dispose() {
    _socketManager.off('connected', _onSocketConnected);
    _socketManager.off('disconnected', _onSocketDisconnected);
    _socketManager.off('reconnected', _onSocketReconnected);
    _offlineManager.removeListener(_onOfflineStatusChanged);

    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/chat/services/global_chat_room.dart';
import 'package:flutter/scheduler.dart';
import 'package:here4help/constants/task_status.dart' as TaskStatusConstants;
import 'package:here4help/chat/widgets/dynamic_action_bar.dart';
import 'package:here4help/chat/utils/action_bar_config.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/socket_service.dart';

import 'package:photo_view/photo_view.dart';
import 'package:here4help/utils/path_mapper.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'dart:ui';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/widgets/dispute_dialog.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, this.data});
  final Map<String, dynamic>? data; // 接收傳入的資料（可選）

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  // 統一應徵者訊息的背景色
  final Color applierBubbleColor = Colors.grey.shade100;

  // 當前登入用戶 ID
  int? _currentUserId;

  // 聊天室聚合數據
  Map<String, dynamic>? _chatData;

  // 錯誤處理狀態
  bool _hasError = false;
  String _errorMessage = '';

  // 聊天訊息列表（從資料庫載入）
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isLoadingMessages = false;
  int? resultOpponentLastReadId;
  // 新增：滾動控制與新訊息提示
  final ScrollController _listController = ScrollController();
  bool _isAtBottom = true;
  bool _showNewMsgBanner = false;
  int _unseenCount = 0;
  // 本地暫存「傳送中」訊息
  final List<Map<String, dynamic>> _pendingMessages = [];
  // 角色與動作列控制
  String _userRole = 'participant';
  bool _showActionBar = true;
  // 移除狀態 Bar 動畫控制相關變數

  // Socket.IO 服務
  final SocketService _socketService = SocketService();
  String? _currentRoomId;

  // 對方頭像與名稱（相對於當前使用者的聊天室對象）快取
  String? _opponentAvatarUrlCached;
  String _opponentNameCached = 'U';

  // 進度資料暫不使用，保留映射函式如需擴充再啟用

  // 移除 _taskStatusDisplay 方法，不再使用

  // 偵測訊息內的第一個圖片連結（支援純 URL 或 [Photo]\nURL 格式）
  String? _extractFirstImageUrl(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      // 允許相對路徑（後端回傳 backend/uploads/...）與完整 URL
      final httpMatch = RegExp(r'(https?:\/\/[^\s]+\.(png|jpg|jpeg|gif))',
              caseSensitive: false)
          .firstMatch(trimmed);
      if (httpMatch != null) return httpMatch.group(1);
      final relMatch = RegExp(
              r'^(?:\/)?(backend\/uploads\/[^\s]+\.(png|jpg|jpeg|gif))$',
              caseSensitive: false)
          .firstMatch(trimmed);
      if (relMatch != null) {
        final rel = relMatch.group(1)!;
        // 映射為可訪問 URL
        return PathMapper.mapDatabasePathToUrl(rel);
      }
    }
    return null;
  }

  // 建立訊息內容：若包含圖片 URL 則顯示縮圖並可點擊預覽，否則顯示文字
  Widget _buildMessageContent(String text) {
    if (text.isEmpty) {
      return const Text('', style: TextStyle(fontSize: 14));
    }

    final imageUrl = _extractFirstImageUrl(text);
    if (imageUrl == null) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14),
        softWrap: true,
        overflow: TextOverflow.visible,
      );
    }
    // 隱藏 URL/相對路徑，只保留其他說明文字（例如 [Photo] 檔名）
    final httpRe =
        RegExp(r'https?:\/\/[^\s]+\.(png|jpg|jpeg|gif)', caseSensitive: false);
    final relRe = RegExp(
        r'^(?:\/)?backend\/uploads\/[^\s]+\.(png|jpg|jpeg|gif)$',
        caseSensitive: false);
    final photoTagRe = RegExp(r'^\s*\[photo\]', caseSensitive: false);
    final fileNameOnlyRe =
        RegExp(r'^[^\\/\s]+\.(png|jpe?g|gif)$', caseSensitive: false);
    final caption = text
        .split('\n')
        .where((line) {
          final t = line.trim();
          if (t.isEmpty) return false;
          if (httpRe.hasMatch(t)) return false;
          if (relRe.hasMatch(t)) return false;
          if (photoTagRe.hasMatch(t)) return false; // [Photo] 檔名行不顯示
          if (fileNameOnlyRe.hasMatch(t)) return false; // 純檔名行不顯示
          return true;
        })
        .join('\n')
        .trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption.isNotEmpty) ...[
          Text(caption),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: () {
            if (!mounted) return;
            _showImagePreview(imageUrl);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LayoutBuilder(builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.black12,
                      height: maxW * 0.6,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Color _glassNavColor(BuildContext context) {
    try {
      final themeManager =
          Provider.of<ThemeConfigManager>(context, listen: false);
      return themeManager.navigationBarBackground;
    } catch (_) {
      final appBarBg = Theme.of(context).appBarTheme.backgroundColor;
      return (appBarBg ?? Colors.white).withOpacity(0.3);
    }
  }

  // _taskStatusCode() 暫不使用（資料以顯示文字流程處理）

  int? _getOpponentUserId() {
    try {
      final room = _room;
      if (room == null) return null;
      final creatorId = room['creator_id'] ?? room['creatorId'];
      final participantId = room['participant_id'] ?? room['participantId'];
      if (_currentUserId == null) return null;
      final int? creator =
          (creatorId is int) ? creatorId : int.tryParse('$creatorId');
      final int? participant = (participantId is int)
          ? participantId
          : int.tryParse('$participantId');
      debugPrint(
          '👥 resolve opponent: currentUserId=$_currentUserId, creator=$creator, participant=$participant');
      if (creator == _currentUserId) return participant;
      if (participant == _currentUserId) return creator;
      return participant ?? creator;
    } catch (e) {
      debugPrint('❌ _getOpponentUserId error: $e');
      return null;
    }
  }

  /// 取得對方顯示名稱（依對方 userId 判斷應取哪一側欄位）
  String _getOpponentDisplayName() {
    try {
      final room = _room;
      final task = _task;
      final partner = room?['chat_partner'] as Map<String, dynamic>?;
      final participantObj = room?['participant'] as Map<String, dynamic>?;
      if (room == null) return 'User';
      final int? opponentId = _getOpponentUserId();
      final int? participantId = (room['participant_id'] is int)
          ? room['participant_id']
          : int.tryParse('${room['participant_id']}');

      String? firstNonEmpty(List<dynamic> list) {
        for (final v in list) {
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return null;
      }

      String? name;
      if (opponentId != null &&
          participantId != null &&
          opponentId == participantId) {
        // 對方為 participant
        name = firstNonEmpty([
          room['participant_nickname'],
          room['participant_name'],
          participantObj?['nickname'],
          participantObj?['name'],
          task?['participant_name'],
        ]);
      } else {
        // 對方為 creator
        name = firstNonEmpty([
          room['creator_nickname'],
          room['creator_name'],
          partner?['nickname'],
          partner?['name'],
          task?['creator_name'],
        ]);
      }
      return (name == null || name.isEmpty) ? 'User' : name;
    } catch (_) {
      return 'User';
    }
  }

  /// 嘗試從多個來源擷取對方評分（平均星等、評論數）
  (double avg, int count) _getOpponentRating() {
    double avg = 0;
    int count = 0;
    try {
      final chatPartnerInfo = _chatPartnerInfo;
      if (chatPartnerInfo != null) {
        avg = (chatPartnerInfo['average_rating'] as num?)?.toDouble() ?? 0.0;
        count = (chatPartnerInfo['total_ratings'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('❌ 獲取對方評分失敗: $e');
    }
    return (avg, count);
  }

  // 移除未使用的 _getRoomCreatorId 以消除警告

  // 移除未使用的 _getRoomParticipantId 以消除 linter 警告

  // 移除未使用的 _amCreatorInThisRoom 以消除警告

  /// 取得對方頭像 URL
  String? _getOpponentAvatarUrl() {
    try {
      final chatPartnerInfo = _chatPartnerInfo;
      if (chatPartnerInfo != null) {
        return chatPartnerInfo['avatar_url'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ 獲取對方頭像失敗: $e');
      return null;
    }
  }

  void _scrollToBottom({bool delayed = false}) {
    void run() {
      if (!_listController.hasClients) return;
      _listController.animateTo(
        _listController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    if (delayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    } else {
      run();
    }
  }

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // 模擬任務狀態
  String taskStatus = 'pending confirmation';

  late String joinTime;

  // 新增狀態變數
  late Duration remainingTime;
  late DateTime taskPendingStart;
  late DateTime taskPendingEnd;
  late Ticker countdownTicker;
  bool countdownCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _initializeChat(); // 載入當前用戶 ID

    // 移除狀態 Bar 動畫初始化

    // 監聽列表滾動，更新是否在底部
    _listController.addListener(() {
      if (!_listController.hasClients) return;
      final maxScroll = _listController.position.maxScrollExtent;
      final offset = _listController.offset;
      final atBottom = (maxScroll - offset) <= 24.0; // 容忍 24px
      if (_isAtBottom != atBottom) {
        setState(() {
          _isAtBottom = atBottom;
          if (_isAtBottom) {
            _showNewMsgBanner = false;
            _unseenCount = 0;
          }
        });
      }
    });

    final now = DateTime.now();
    joinTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  // 移除狀態 Bar 自動消失方法

  /// 載入當前登入用戶 ID
  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final currentAvatar = prefs.getString('user_avatarUrl') ?? '';
      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
        debugPrint(
            '🔍 current user avatar from prefs: ${currentAvatar.isNotEmpty ? currentAvatar : 'empty'}');
      }
    } catch (e) {
      debugPrint('❌ 載入當前用戶 ID 失敗: $e');
    }
  }

  // 已有下方 dispose，避免重覆定義（保留於 520 行段落）

  void _toggleActionBar() {
    setState(() {
      _showActionBar = !_showActionBar;
    });
  }

  /// 選擇圖片並上傳，成功後發送一則圖片訊息（簡化：以 [Photo] 檔名 + URL）
  Future<void> _pickAndSendPhoto() async {
    try {
      if (_currentRoomId == null) throw Exception('room 未初始化');

      // 使用新的跨平台圖片服務
      final chatService = ChatService();
      final upload =
          await chatService.pickAndUploadFromGallery(_currentRoomId!);

      final url = upload['url'] ?? upload['path'] ?? '';
      final fileName = upload['filename'] ?? upload['name'] ?? 'image';
      final text = url is String && url.isNotEmpty
          ? '[Photo] $fileName\n$url'
          : '[Photo] $fileName';
      _controller.text = text;
      await _sendMessage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選取圖片失敗: $e')),
      );
    }
  }

  /// 初始化聊天室
  Future<void> _initializeChat() async {
    try {
      // 從 widget.data 獲取 room_id
      String? roomId;

      if (widget.data != null) {
        roomId = widget.data!['room']?['id']?.toString();
        debugPrint('🔍 從 widget.data 獲取 room_id: $roomId');
      }

      if (roomId == null || roomId.isEmpty) {
        debugPrint('❌ widget.data 中沒有 room_id');
        setState(() {
          _hasError = true;
          _errorMessage = '無法獲取聊天室 ID，請返回聊天列表重新選擇';
        });
        return;
      }

      debugPrint('🔍 初始化聊天室，room_id: $roomId');

      // 使用聚合 API 獲取聊天室數據
      final chatData = await ChatService().getChatDetailData(roomId: roomId);

      if (mounted) {
        setState(() {
          // 更新聊天室數據
          _chatData = chatData;
          _userRole = chatData['user_role'] ?? 'participant';
          _currentRoomId = roomId;
        });

        // 保存完整的聊天室數據到本地儲存
        await _saveChatRoomData(chatData, roomId);

        // 更新任務狀態相關數據
        final task = chatData['task'];
        if (task != null) {
          setState(() {
            // 只在真正需要倒計時時才啟動，避免不必要的通知
            if (task['status']?['code'] == 'pending_confirmation_tasker') {
              // 檢查是否真的需要倒計時（避免測試數據觸發）
              final taskCreatedAt = task['created_at'];
              if (taskCreatedAt != null) {
                try {
                  final createdAt = DateTime.parse(taskCreatedAt);
                  final now = DateTime.now();
                  final timeSinceCreation = now.difference(createdAt);

                  // 只有在創建時間合理範圍內才啟動倒計時
                  if (timeSinceCreation.inDays < 30) {
                    // 30天內的任務才考慮倒計時
                    taskPendingStart = DateTime.now();
                    taskPendingEnd =
                        taskPendingStart.add(const Duration(seconds: 5));
                    remainingTime = taskPendingEnd.difference(DateTime.now());
                    countdownTicker = Ticker(_onTick)..start();
                  } else {
                    remainingTime = const Duration();
                  }
                } catch (e) {
                  debugPrint('❌ 解析任務創建時間失敗: $e');
                  remainingTime = const Duration();
                }
              } else {
                remainingTime = const Duration();
              }
            } else if (task['status']?['code'] == 'pending_confirmation') {
              // 檢查是否真的需要倒計時
              final taskCreatedAt = task['created_at'];
              if (taskCreatedAt != null) {
                try {
                  final createdAt = DateTime.parse(taskCreatedAt);
                  final now = DateTime.now();
                  final timeSinceCreation = now.difference(createdAt);

                  // 只有在創建時間合理範圍內才啟動倒計時
                  if (timeSinceCreation.inDays < 30) {
                    // 30天內的任務才考慮倒計時
                    taskPendingStart = DateTime.now();
                    taskPendingEnd =
                        taskPendingStart.add(const Duration(days: 7));
                    remainingTime = taskPendingEnd.difference(DateTime.now());
                    countdownTicker = Ticker(_onTick)..start();
                  } else {
                    remainingTime = const Duration();
                  }
                } catch (e) {
                  debugPrint('❌ 解析任務創建時間失敗: $e');
                  remainingTime = const Duration();
                }
              } else {
                remainingTime = const Duration();
              }
            } else {
              remainingTime = const Duration();
            }
          });
        }

        // 載入聊天訊息
        await _loadChatMessages();

        // 設置 Socket.IO
        await _setupSocket();

        // 解析對方身份
        _resolveOpponentIdentity();
      }
    } catch (e) {
      debugPrint('❌ 初始化聊天室失敗: $e');
      // 在 initState 中不能使用 ScaffoldMessenger.of(context)
      // 將錯誤存儲到狀態中，在 build 方法中顯示
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = '載入聊天室失敗: $e';
        });
      }
    }
  }

  /// 設置 Socket.IO 連接
  Future<void> _setupSocket() async {
    try {
      // 連接 Socket.IO
      await _socketService.connect();

      // 設置事件監聽器
      _socketService.onMessageReceived = _onMessageReceived;
      _socketService.onUnreadUpdate = _onUnreadUpdate;

      // 加入當前聊天室
      if (_currentRoomId != null) {
        _socketService.joinRoom(_currentRoomId!);
        // 標記為已讀
        _socketService.markRoomAsRead(_currentRoomId!);
        // 每次建立/切換聊天室時，解析一次對方身份與頭像
        _resolveOpponentIdentity();
      }

      debugPrint('✅ Socket setup completed for room: $_currentRoomId');
    } catch (e) {
      debugPrint('❌ Socket setup failed: $e');
    }
  }

  /// 解析聊天室中「對方」身份並快取頭像與名稱
  void _resolveOpponentIdentity() {
    try {
      // 若尚未取得當前使用者 ID，暫不解析，避免誤判角色導致顯示自己的頭像
      if (_currentUserId == null) {
        debugPrint('⏸️ 略過解析對方身份，因 _currentUserId 為 null');
        return;
      }
      final name = _getOpponentDisplayName().trim();
      final url = _getOpponentAvatarUrl();
      final oppId = _getOpponentUserId();
      setState(() {
        _opponentNameCached = name.isNotEmpty ? name : 'U';
        _opponentAvatarUrlCached =
            (url != null && url.trim().isNotEmpty) ? url : null;
      });
      debugPrint(
          '🧩 Opponent resolved: id=${oppId ?? 'null'}, name=$_opponentNameCached, avatar=${_opponentAvatarUrlCached ?? 'null'}');
    } catch (_) {}
  }

  /// 處理收到的即時訊息
  void _onMessageReceived(Map<String, dynamic> messageData) {
    debugPrint('📨 Received real-time message: $messageData');

    // 檢查是否為當前聊天室的訊息
    final roomId = messageData['roomId']?.toString();
    final fromUserId = messageData['fromUserId'];
    if (roomId == _currentRoomId) {
      // 不是自己發的且不在底部時，顯示新訊息提示
      final isFromMe = _currentUserId != null &&
          (fromUserId == _currentUserId || '$fromUserId' == '$_currentUserId');
      if (!isFromMe && !_isAtBottom) {
        setState(() {
          _unseenCount += 1;
          _showNewMsgBanner = true;
        });
      }
      _loadChatMessages();
    }
  }

  /// 處理未讀訊息更新
  void _onUnreadUpdate(Map<String, dynamic> unreadData) {
    // debugPrint('🔔 Unread update: $unreadData');
    // 這裡可以更新 UI 中的未讀徽章
  }

  /// 格式化訊息時間
  String _formatMessageTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return DateFormat('HH:mm').format(DateTime.now());
    }

    try {
      final dateTime = DateTime.parse(timeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      debugPrint('❌ 時間格式化失敗: $e');
      return DateFormat('HH:mm').format(DateTime.now());
    }
  }

  /// 從資料庫載入聊天訊息
  Future<void> _loadChatMessages() async {
    if (_isLoadingMessages) return;

    try {
      setState(() {
        _isLoadingMessages = true;
      });

      if (_currentRoomId == null || _currentRoomId!.isEmpty) {
        debugPrint('❌ 無法取得 roomId');
        return;
      }

      debugPrint('🔍 載入聊天訊息，roomId: $_currentRoomId');

      // 如果已經有聚合數據，直接使用其中的訊息
      if (_chatData != null && _chatData!['messages'] != null) {
        final messages = _chatData!['messages'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _chatMessages =
                messages.map((msg) => Map<String, dynamic>.from(msg)).toList();
            _isLoadingMessages = false;
          });
          // 在底部則保持自動滾到底
          if (_isAtBottom) {
            _scrollToBottom(delayed: true);
          }
        }
        debugPrint('✅ 從聚合數據載入 ${_chatMessages.length} 條訊息');
        return;
      }

      // 備用方案：使用原有的 API
      final result = await ChatService().getMessages(roomId: _currentRoomId!);
      final messages = result['messages'] as List<dynamic>? ?? [];
      // 讀取對方最後已讀訊息 ID 供渲染使用
      resultOpponentLastReadId =
          (result['opponent_last_read_message_id'] is int)
              ? result['opponent_last_read_message_id']
              : int.tryParse('${result['opponent_last_read_message_id']}') ?? 0;

      if (mounted) {
        setState(() {
          _chatMessages =
              messages.map((msg) => Map<String, dynamic>.from(msg)).toList();
          _isLoadingMessages = false;
        });
        // 標記已讀（讀到列表中的最後一則訊息）
        try {
          if (_chatMessages.isNotEmpty) {
            final lastIdRaw = _chatMessages.last['id'];
            final lastId = (lastIdRaw is int)
                ? lastIdRaw
                : int.tryParse('$lastIdRaw') ?? 0;
            if (lastId > 0 && _currentRoomId != null) {
              NotificationCenter().service.markRoomRead(
                  roomId: _currentRoomId!, upToMessageId: '$lastId');
            }
          }
        } catch (_) {}
        // 在底部則保持自動滾到底
        if (_isAtBottom) {
          _scrollToBottom(delayed: true);
        }
      }

      debugPrint('✅ 成功載入 ${_chatMessages.length} 條訊息');
    } catch (e) {
      debugPrint('❌ 載入聊天訊息失敗: $e');
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  /// 保存聊天室數據到本地儲存
  Future<void> _saveChatRoomData(
      Map<String, dynamic> chatData, String roomId) async {
    try {
      await ChatStorageService.savechatRoomData(
        roomId: roomId,
        room: chatData['room'] ?? {},
        task: chatData['task'] ?? {},
        userRole: chatData['user_role']?.toString(),
        chatPartnerInfo: chatData['chat_partner_info'],
      );
      debugPrint('✅ 聊天室數據已保存到本地儲存: roomId=$roomId');
    } catch (e) {
      debugPrint('❌ 保存聊天室數據失敗: $e');
    }
  }

  /// 獲取當前用戶資訊
  Future<Map<String, dynamic>?> _getCurrentUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'name': prefs.getString('user_name') ?? 'Me',
        'avatar_url': prefs.getString('user_avatarUrl') ?? '',
      };
    } catch (e) {
      debugPrint('❌ 無法獲取當前用戶資訊: $e');
      return null;
    }
  }

  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    final remain = taskPendingEnd.difference(now);
    if (remain <= Duration.zero && !countdownCompleted) {
      countdownCompleted = true;
      countdownTicker.stop();
      setState(() {
        remainingTime = Duration.zero;
        if (_task != null) {
          _task!['status'] =
              TaskStatusConstants.TaskStatus.statusString['completed_tasker'];
        }
      });
      if (_task != null) {
        TaskService().updateTaskStatus(
          _task!['id'].toString(),
          TaskStatusConstants.TaskStatus.statusString['completed_tasker']!,
          statusCode: 'completed',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The countdown has ended. The task is now automatically completed and the payment has been successfully transferred. Thank you!',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else if (!countdownCompleted) {
      setState(() {
        remainingTime = remain > Duration.zero ? remain : Duration.zero;
      });
    }
  }

  /// 發送訊息到聊天室（保存到資料庫）
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !mounted) return;

    try {
      if (_currentRoomId == null) {
        debugPrint('❌ 無法取得 roomId');
        return;
      }

      final taskId = _task?['id']?.toString() ?? '';
      if (taskId.isEmpty) {
        debugPrint('❌ 無法取得 taskId');
        return;
      }

      // 清空輸入框
      _controller.clear();

      // 創建本地暫存訊息
      final pendingMessage = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'room_id': _currentRoomId,
        'from_user_id': _currentUserId,
        'content': text,
        'message': text,
        'created_at': DateTime.now().toIso8601String(),
        'is_pending': true,
      };

      setState(() {
        _pendingMessages.add(pendingMessage);
        _chatMessages.add(pendingMessage);
      });

      // 滾動到底部
      _scrollToBottom();

      // 發送到後端
      final result = await ChatService().sendMessage(
        roomId: _currentRoomId!,
        message: text,
        taskId: taskId,
      );

      if (mounted) {
        setState(() {
          // 移除暫存訊息
          _pendingMessages.remove(pendingMessage);
          _chatMessages.remove(pendingMessage);

          // 添加真實訊息
          if (result['success'] == true) {
            final realMessage = result['message'] as Map<String, dynamic>;
            _chatMessages.add(Map<String, dynamic>.from(realMessage));
          }
        });

        // 滾動到底部
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ 發送訊息失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('發送訊息失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // 最後一次保險：離開時嘗試標記到目前列表最後一則
    try {
      if (_currentRoomId != null && _chatMessages.isNotEmpty) {
        final lastIdRaw = _chatMessages.last['id'];
        final lastId =
            (lastIdRaw is int) ? lastIdRaw : int.tryParse('$lastIdRaw') ?? 0;
        if (lastId > 0) {
          NotificationCenter()
              .service
              .markRoomRead(roomId: _currentRoomId!, upToMessageId: '$lastId');
        }
      }
    } catch (_) {}
    // 離開 Socket.IO 房間
    if (_currentRoomId != null) {
      _socketService.leaveRoom(_currentRoomId!);
    }

    // 清理計時器
    if (_task?['status']?['code'] == 'pending_confirmation_tasker' ||
        _task?['status']?['code'] == 'pending_confirmation') {
      countdownTicker.dispose();
    }

    _controller.dispose();
    _focusNode.dispose();
    // 移除狀態 Bar 相關清理
    super.dispose();
  }

  /// 獲取應徵者的應徵資料
  Future<Map<String, dynamic>?> _getApplicationData(
      String taskId, int applicantId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.taskApplicantsUrl}?task_id=$taskId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final applications = data['data']['applications'] as List;
          // 找到指定應徵者的應徵資料
          final application = applications.firstWhere(
            (app) => app['user_id'] == applicantId,
            orElse: () => null,
          );
          return application;
        }
      }
    } catch (e) {
      debugPrint('Error fetching application data: $e');
    }
    return null;
  }

  /// 顯示應徵者履歷對話框
  void _showApplierResumeDialog() {
    if (_application == null) {
      debugPrint('❌ 沒有申請數據');
      return;
    }

    final coverLetter = _application!['cover_letter'] ?? '';
    final answersJson = _application!['answers_json'] ?? '{}';
    final applierName = _chatPartnerInfo?['name'] ?? 'Applicant';
    final applierAvatar = _chatPartnerInfo?['avatar_url'];
    final averageRating = _chatPartnerInfo?['average_rating'] ?? 0.0;
    final totalRatings = _chatPartnerInfo?['total_ratings'] ?? 0;

    // 解析 answers_json
    Map<String, dynamic> answers = {};
    try {
      answers = json.decode(answersJson);
    } catch (e) {
      debugPrint('❌ 解析 answers_json 失敗: $e');
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題和關閉按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Applicant Resume',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 申請者信息
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _getAvatarColor(applierName),
                    backgroundImage:
                        applierAvatar != null && applierAvatar.isNotEmpty
                            ? NetworkImage(
                                PathMapper.mapDatabasePathToUrl(applierAvatar))
                            : null,
                    child: applierAvatar == null || applierAvatar.isEmpty
                        ? Text(
                            _getInitials(applierName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          applierName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${averageRating.toStringAsFixed(1)} ($totalRatings reviews)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cover Letter
              if (coverLetter.isNotEmpty) ...[
                Text(
                  'Cover Letter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(coverLetter),
                ),
                const SizedBox(height: 20),
              ],

              // Application Questions
              if (answers.isNotEmpty) ...[
                Text(
                  'Application Questions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _applicationQuestions.length,
                    itemBuilder: (context, index) {
                      final question = _applicationQuestions[index];
                      final questionText = question['question_text'] ?? '';
                      final answer =
                          answers[questionText] ?? 'No answer provided';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q${index + 1}: $questionText',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A: $answer',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              // 底部按鈕
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 檢查是否有錯誤
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('聊天室'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _errorMessage = '';
                  });
                  _initializeChat();
                },
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    // 檢查是否有 View Resume 訊息
    final hasViewResumeMessage =
        _chatMessages.any((msg) => (msg['message'] ?? '').contains('申請已提交'));

    // 使用從資料庫載入的訊息列表
    int totalItemCount = (hasViewResumeMessage ? 1 : 0) +
        _chatMessages.length +
        (_pendingMessages.length);

    debugPrint(
        '🔍 Total messages: $totalItemCount (hasViewResume: ${hasViewResumeMessage ? 1 : 0}, chatMessages: ${_chatMessages.length})');

    Widget buildQuestionReplyBubble(String text) {
      final (avgRating, reviewsCount) = _getOpponentRating();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _opponentAvatarUrlCached != null
                      ? ImageHelper.getAvatarImage(_opponentAvatarUrlCached!)
                      : null,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.35),
                  child: _opponentAvatarUrlCached == null
                      ? Text(
                          _opponentNameCached.isNotEmpty
                              ? _opponentNameCached[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 250),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1. 頭像置中
                              CircleAvatar(
                                radius: 28,
                                backgroundImage:
                                    _opponentAvatarUrlCached != null
                                        ? ImageHelper.getAvatarImage(
                                            _opponentAvatarUrlCached!)
                                        : null,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.35),
                                child: _opponentAvatarUrlCached == null
                                    ? Text(
                                        _opponentNameCached.isNotEmpty
                                            ? _opponentNameCached[0]
                                                .toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondary,
                                            fontSize: 18),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              // 2. 名字（無 nickname 則全名）
                              Text(
                                _opponentNameCached,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              // 3. 五星評分與評論數
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${avgRating > 0 ? avgRating.toStringAsFixed(1) : '0.0'}  (${reviewsCount > 0 ? '$reviewsCount comments' : '0 comments'})',
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 12),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 16),
                              // 4. View Resume 按鈕置中
                              Align(
                                alignment: Alignment.center,
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View Resume'),
                                  onPressed: () => _showApplierResumeDialog(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        joinTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildOpponentBubble(String text, int? opponentUserId,
        {String? senderName, String? messageTime}) {
      // 先前的 opponentInfo 已不再使用，頭像/名稱以快取為準

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: _opponentAvatarUrlCached != null
                      ? ImageHelper.getAvatarImage(_opponentAvatarUrlCached!)
                      : null,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.35),
                  child: _opponentAvatarUrlCached == null
                      ? Text(
                          _opponentNameCached.isNotEmpty
                              ? _opponentNameCached[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                            child: _buildMessageContent(text),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        messageTime != null
                            ? _formatMessageTime(messageTime)
                            : joinTime,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildMyMessageBubble(Map<String, String> message,
        {bool showAvatar = false}) {
      final text = message['text'] ?? '';
      final time =
          message['time'] ?? DateFormat('HH:mm').format(DateTime.now());

      debugPrint(
          '🔍 [My Works] buildMyMessageBubble: text="$text", message=$message');

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 訊息氣泡 + 已讀標記
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 14),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 狀態圖示：read 顯示雙勾(藍)，sent 顯示單勾(灰)
                      Builder(builder: (_) {
                        final status = (message['status'] ?? '').toString();
                        final bool isRead =
                            status == 'read' || (message['read'] == 'true');
                        final cs = Theme.of(context).colorScheme;
                        return Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: isRead ? cs.primary : cs.secondary,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            // 可選的我方頭像（用於對稱設計）
            if (showAvatar) ...[
              const SizedBox(width: 8),
              FutureBuilder<Map<String, dynamic>?>(
                future: _getCurrentUserInfo(),
                builder: (context, snapshot) {
                  final userInfo = snapshot.data ?? {};
                  return CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        ImageHelper.getAvatarImage(userInfo['avatar_url']) ??
                            ImageHelper.getDefaultAvatar(),
                    child: ImageHelper.getAvatarImage(userInfo['avatar_url']) ==
                            null
                        ? Text(
                            (userInfo['name'] ?? 'Me')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

    final isInputDisabled = _task?['status']?['code'] == 'completed' ||
        _task?['status']?['code'] == 'rejected_tasker' ||
        _task?['status']?['code'] == 'completed_tasker';
    // --- ALERT BAR SWITCH-CASE 重構 ---
    // 預設 alert bar 不會顯示，只有在特定狀態下才顯示
    Widget? alertContent;
    final statusCode = _task?['status']?['code'];
    switch (statusCode) {
      case 'applying_tasker':
        alertContent = const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Waiting for poster to respond to your application.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        );
        break;
      case 'rejected_tasker':
        alertContent = const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Unfortunately, the poster has chosen another candidate or declined your application.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        );
        break;
      case 'pending_confirmation_tasker':
        alertContent = Column(
          children: [
            Text(
              '⏰ ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24).toString().padLeft(2, '0')}:${remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} until auto complete',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Dear Poster, please confirm as soon as possible that the Tasker has completed the task. Otherwise, after the countdown ends, the payment will be automatically transferred to the Tasker.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
        break;
      case 'pending_confirmation':
        alertContent = Column(
          children: [
            Text(
              '⏰ ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24).toString().padLeft(2, '0')}:${remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} until auto complete',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Dear Poster, please confirm as soon as possible that the Tasker has completed the task. Otherwise, after the countdown ends, the payment will be automatically transferred to the Tasker.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
        break;
      default:
        // 預設 alertContent 為 null, 不顯示 alert bar
        alertContent = null;
    }
    // --- END ALERT BAR SWITCH-CASE ---

    return Column(
      children: [
        // alertBar 置於 AppBar 下方
        if (alertContent != null)
          Container(
            color: Colors.grey[100],
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: alertContent,
          ),
        Expanded(
          child: Stack(
            children: [
              // 取消覆蓋背景色，讓底層全局背景可見
              ListView.builder(
                controller: _listController,
                padding: const EdgeInsets.all(16),
                itemCount: totalItemCount,
                itemBuilder: (context, index) {
                  if (hasViewResumeMessage && index == 0) {
                    return buildQuestionReplyBubble(
                        _chatMessages[0]['message']?.toString() ?? '');
                  }

                  int adjustedIndex = index - (hasViewResumeMessage ? 1 : 0);

                  // 使用從資料庫載入的訊息列表
                  if (adjustedIndex < _chatMessages.length) {
                    final messageData = _chatMessages[adjustedIndex];
                    final messageText =
                        messageData['content']?.toString() ?? 'No message';
                    final messageFromUserId = messageData['from_user_id'];
                    final messageTime =
                        messageData['created_at']?.toString() ?? '';
                    final senderName =
                        messageData['sender_name']?.toString() ?? 'Unknown';

                    // 添加除錯資訊
                    debugPrint(
                        '🔍 [Chat Detail] 訊息資料: messageData=$messageData');
                    debugPrint(
                        '🔍 [Chat Detail] 訊息文字: messageText="$messageText"');
                    debugPrint(
                        '🔍 [Chat Detail] 訊息來源: messageFromUserId=$messageFromUserId, currentUserId=$_currentUserId');

                    // 判斷這條訊息是否來自當前用戶
                    final isMyMessage = _currentUserId != null &&
                        messageFromUserId == _currentUserId;

                    // 根據是否為我方訊息決定氣泡樣式
                    if (isMyMessage) {
                      // 根據對方最後已讀訊息 ID 決定狀態：read 或 sent
                      final int msgId = (messageData['id'] is int)
                          ? messageData['id']
                          : int.tryParse('${messageData['id']}') ?? 0;
                      final int opponentReadId =
                          (resultOpponentLastReadId ?? 0);
                      final String status =
                          opponentReadId >= msgId ? 'read' : 'sent';
                      return buildMyMessageBubble({
                        'text': messageText,
                        'time': _formatMessageTime(messageTime),
                        'status': status,
                      });
                    } else {
                      return buildOpponentBubble(messageText, messageFromUserId,
                          senderName: senderName, messageTime: messageTime);
                    }
                  }

                  return const SizedBox.shrink();
                },
              ),
              if (_showNewMsgBanner)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showNewMsgBanner = false;
                          _unseenCount = 0;
                        });
                        _scrollToBottom();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _unseenCount > 0
                                  ? '有未讀訊息（$_unseenCount）— 點擊前往最新'
                                  : '有未讀訊息 — 點擊前往最新',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 移除狀態 Bar 顯示
        const Divider(
          height: 1,
          thickness: 2,
        ),
        // Action Bar 區域
        if (_showActionBar && _task != null)
          DynamicActionBar(
            taskStatus: ActionBarConfigManager.parseTaskStatus(
                _task!['status']?['code']),
            userRole: ActionBarConfigManager.parseUserRole(_userRole),
            actionCallbacks: _buildActionCallbacks(),
            showStatusBar: true,
            statusDisplayName: _task!['status']?['display_name'],
            progressRatio: double.tryParse(
                _task!['status']?['progress_ratio']?.toString() ?? '0'),
            backgroundColor: _glassNavColor(context),
          ),
        // ActionBar + Input 區塊採用與 AppBar 相同的背景/前景配色，並提供 hover/pressed/focus 覆蓋色
        Builder(builder: (context) {
          final theme = Theme.of(context);
          final bg =
              theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
          final fg =
              theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
          return Theme(
              data: theme.copyWith(
                iconButtonTheme: IconButtonThemeData(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return fg.withOpacity(0.5);
                      }
                      return fg;
                    }),
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return fg.withOpacity(0.12);
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return fg.withOpacity(0.08);
                      }
                      if (states.contains(WidgetState.focused)) {
                        return fg.withOpacity(0.10);
                      }
                      return null;
                    }),
                  ),
                ),
                inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                  filled: true,
                  fillColor: bg.withOpacity(0.08),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: fg.withOpacity(0.24)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: fg, width: 1.5),
                  ),
                  hintStyle: TextStyle(color: fg.withOpacity(0.6)),
                ),
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: fg,
                  selectionColor: fg.withOpacity(0.25),
                  selectionHandleColor: fg,
                ),
              ),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(color: _glassNavColor(context)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // plus 與 photo 置於最左側，位於輸入框之前
                        IconTheme(
                          data: IconThemeData(color: fg),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: _showActionBar ? 'Less' : 'More',
                                icon: Icon(
                                  _showActionBar
                                      ? Icons.remove_circle_outline
                                      : Icons.add_circle_outline,
                                ),
                                onPressed:
                                    isInputDisabled ? null : _toggleActionBar,
                              ),
                              IconButton(
                                tooltip: 'Photo',
                                icon: const Icon(Icons.photo_outlined),
                                onPressed:
                                    isInputDisabled ? null : _pickAndSendPhoto,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            // 固定高度以與 IconButton (預設 48) 視覺中心對齊
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: bg.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              enabled: !isInputDisabled,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (value) {
                                if (!isInputDisabled) _sendMessage();
                              },
                              onEditingComplete: () {
                                FocusScope.of(context).unfocus();
                              },
                              onTapOutside: (_) {
                                FocusScope.of(context).unfocus();
                              },
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                // 調整內邊距：左側加 8，並垂直置中
                                contentPadding: EdgeInsets.only(
                                    left: 8, top: 12, bottom: 12),
                                hintText: 'Type a message',
                              ),
                              style: TextStyle(color: fg),
                              cursorColor: fg,
                            ),
                          ),
                        ),
                        IconTheme(
                          data: IconThemeData(color: fg),
                          child: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: isInputDisabled ? null : _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ));
        }),
        // 移除底部重複的任務標題，避免與 AppBar 重複
        // 任務標題已在 AppBar 中顯示，這裡不需要重複
        // 任務狀態顯示
        // if (_task != null && _showStatusBar) ...[
        //   SlideTransition(
        //     position: _statusBarSlide,
        //     child: Container(
        //       width: double.infinity,
        //       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //       decoration: BoxDecoration(
        //         color: _getStatusBarColor(),
        //         borderRadius: BorderRadius.circular(8),
        //       ),
        //       child: Row(
        //         children: [
        //           Icon(
        //             _getStatusBarIcon(),
        //             color: Colors.white,
        //             size: 20,
        //           ),
        //           const SizedBox(width: 8),
        //           Expanded(
        //             child: Text(
        //               _getStatusBarText(),
        //               style: const TextStyle(
        //                 color: Colors.white,
        //                 fontWeight: FontWeight.w500,
        //               ),
        //             ),
        //           ),
        //           if (_task!['status']?['code'] ==
        //                   'pending_confirmation_tasker' ||
        //               _task!['status']?['code'] == 'pending_confirmation') ...[
        //             Text(
        //               '⏰ ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24).toString().padLeft(2, '0')}:${remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')} until auto complete',
        //               style: const TextStyle(
        //                   fontWeight: FontWeight.bold,
        //                   fontSize: 14,
        //                   color: Colors.red),
        //             ),
        //           ],
        //         ],
        //       ),
        //     ),
        //   ),
        //   const SizedBox(height: 8),
        // ],
      ],
    );
  }

  static Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 使用 IconTheme 繼承的顏色，避免硬編黑色
          Icon(icon),
          const SizedBox(height: 4),
          // 使用 DefaultTextStyle 繼承主題前景色
          Text(label),
        ],
      ),
    );
  }

  // Store applierChatItems in state for Accept button logic
  List<Map<String, dynamic>> applierChatItems = [];

  /// 構建動作回調映射
  Map<String, VoidCallback> _buildActionCallbacks() {
    return {
      'accept': () => _handleAcceptApplication(),
      'block': () => _handleBlockUser(),
      'report': () => _openReportSheet(),
      'pay': () => _openPayAndReview(),
      'complete': () => _handleCompleteTask(),
      'confirm': () => _handleConfirmCompletion(),
      'disagree': () => _handleDisagreeCompletion(),
      'paid_info': () => _showPaidInfo(),
      'review': () => _openReviewDialog(readOnlyIfExists: true),
      'dispute': () => _handleDispute(),
    };
  }

  /// 處理申訴
  Future<void> _handleDispute() async {
    if (_task == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DisputeDialog(
        taskId: _task!['id'].toString(),
        taskTitle: _task!['title']?.toString() ?? 'Unknown Task',
        onDisputeSubmitted: () {
          // 刷新任務資料
          _initializeChat();
        },
      ),
    );

    if (result == true) {
      // 申訴提交成功，刷新頁面資料
      await _initializeChat();
    }
  }

  /// 處理接受應徵
  Future<void> _handleAcceptApplication() async {
    if (_task != null) {
      await TaskService().updateTaskStatus(
        _task!['id'].toString(),
        TaskStatusConstants.TaskStatus.statusString['in_progress']!,
        statusCode: 'in_progress',
      );
      // 關閉其他申請聊天室
      GlobalChatRoom().removeRoomsByTaskIdExcept(
        _task!['id'].toString(),
        _currentRoomId ?? '',
      );
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task accepted. Now in progress.')),
        );
      }
    }
  }

  /// 處理封鎖用戶
  Future<void> _handleBlockUser() async {
    final opponentId = _getOpponentUserId();
    if (opponentId == null) return;

    try {
      await ChatService().blockUser(targetUserId: opponentId, block: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Block failed: $e')),
        );
      }
    }
  }

  /// 處理完成任務
  Future<void> _handleCompleteTask() async {
    if (_task != null) {
      _task!['pendingStart'] = DateTime.now().toIso8601String();
      await TaskService().updateTaskStatus(
        _task!['id'].toString(),
        TaskStatusConstants
            .TaskStatus.statusString['pending_confirmation_tasker']!,
        statusCode: 'pending_confirmation',
      );
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waiting for poster confirmation.')),
        );
      }
    }
  }

  /// 處理確認完成
  Future<void> _handleConfirmCompletion() async {
    try {
      if (_task != null) {
        await TaskService().confirmCompletion(taskId: _task!['id'].toString());
        if (mounted) setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task confirmed and paid.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirm failed: $e')),
        );
      }
    }
  }

  /// 處理不同意完成
  Future<void> _handleDisagreeCompletion() async {
    try {
      if (_task != null) {
        await TaskService().disagreeCompletion(taskId: _task!['id'].toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disagree submitted.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disagree failed: $e')),
        );
      }
    }
  }

  /// 舊的 Action Bar 構建方法（保留用於向後相容）
  List<Widget> _buildActionButtonsByStatus() {
    final status = (_task?['status']?['code'] ?? '').toString();
    final isCreator = _userRole == 'creator';

    // 模組化定義：通用動作
    Map<String, dynamic> actionDefs(
            String label, IconData icon, VoidCallback onTap) =>
        {'label': label, 'icon': icon, 'onTap': onTap};

    // 工具：開啟二次確認對話
    Future<void> confirmDialog(
        {required String title,
        required String content,
        required VoidCallback onConfirm}) async {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
                child: const Text('Confirm')),
          ],
        ),
      );
    }

    // 依狀態與角色組合動作
    final List<Map<String, dynamic>> actions = [];

    switch (status) {
      case 'open':
        if (isCreator) {
          actions.add(actionDefs('Accept', Icons.check, () async {
            await confirmDialog(
              title: 'Double Check',
              content:
                  'Are you sure you want to assign this applicant to this task?',
              onConfirm: () async {
                if (_task != null) {
                  await TaskService().updateTaskStatus(
                    _task!['id'].toString(),
                    TaskStatusConstants.TaskStatus.statusString['in_progress']!,
                    statusCode: 'in_progress',
                  );
                  // 關閉其他申請聊天室（舊全域資料結構保留）
                  GlobalChatRoom().removeRoomsByTaskIdExcept(
                    _task!['id'].toString(),
                    _currentRoomId ?? '',
                  );
                  if (mounted) setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Task accepted. Now in progress.')),
                  );
                }
              },
            );
          }));
          actions.add(actionDefs('Block', Icons.block, () async {
            await confirmDialog(
              title: 'Block User',
              content:
                  'Block this user from applying your tasks in the future?',
              onConfirm: () async {
                final opponentId = _getOpponentUserId();
                if (opponentId == null) return;
                try {
                  await ChatService()
                      .blockUser(targetUserId: opponentId, block: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User blocked.')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Block failed: $e')));
                  }
                }
              },
            );
          }));
        } else {
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
        }
        break;
      case 'in_progress':
        if (isCreator) {
          actions.add(actionDefs('Pay', Icons.payment, () {
            _openPayAndReview();
          }));
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
          actions.add(actionDefs('Block', Icons.block, () async {
            await confirmDialog(
                title: 'Block User',
                content: 'Block this user?',
                onConfirm: () async {
                  final opponentId = _getOpponentUserId();
                  if (opponentId == null) return;
                  try {
                    await ChatService()
                        .blockUser(targetUserId: opponentId, block: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User blocked.')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Block failed: $e')));
                    }
                  }
                });
          }));
        } else {
          actions.add(actionDefs('Completed', Icons.check_circle, () {
            confirmDialog(
              title: 'Double Check',
              content: 'Are you sure you have completed this task?',
              onConfirm: () async {
                if (_task != null) {
                  _task!['pendingStart'] = DateTime.now().toIso8601String();
                  await TaskService().updateTaskStatus(
                    _task!['id'].toString(),
                    TaskStatusConstants.TaskStatus
                        .statusString['pending_confirmation_tasker']!,
                    statusCode: 'pending_confirmation',
                  );
                  if (mounted) setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Waiting for poster confirmation.')));
                }
              },
            );
          }));
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
        }
        break;
      case 'pending_confirmation':
        if (isCreator) {
          actions.add(actionDefs('Confirm', Icons.check, () async {
            await confirmDialog(
              title: 'Double Check',
              content:
                  'Confirm this task and transfer reward points to the Tasker?',
              onConfirm: () async {
                try {
                  if (_task != null) {
                    await TaskService()
                        .confirmCompletion(taskId: _task!['id'].toString());
                    if (mounted) setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Task confirmed and paid.')));
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Confirm failed: $e')));
                  }
                }
              },
            );
          }));
          actions.add(actionDefs('Disagree', Icons.close, () async {
            await confirmDialog(
              title: 'Disagree',
              content: 'Disagree this task is completed?',
              onConfirm: () async {
                try {
                  if (_task != null) {
                    await TaskService()
                        .disagreeCompletion(taskId: _task!['id'].toString());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Disagree submitted.')));
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Disagree failed: $e')));
                  }
                }
              },
            );
          }));
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
        } else {
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
        }
        break;
      case 'dispute':
        actions.add(actionDefs('Report', Icons.article, () {
          _openReportSheet();
        }));
        break;
      case 'completed':
        if (isCreator) {
          actions.add(actionDefs('Paid', Icons.attach_money, () {
            _showPaidInfo();
          }));
          actions.add(actionDefs('Reviews', Icons.reviews, () {
            _openReviewDialog(readOnlyIfExists: true);
          }));
          actions.add(actionDefs('Block', Icons.block, () async {
            await confirmDialog(
                title: 'Block User',
                content: 'Block this user?',
                onConfirm: () async {
                  final opponentId = _getOpponentUserId();
                  if (opponentId == null) return;
                  try {
                    await ChatService()
                        .blockUser(targetUserId: opponentId, block: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User blocked.')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Block failed: $e')));
                    }
                  }
                });
          }));
        } else {
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
          actions.add(actionDefs('Block', Icons.block, () async {
            await confirmDialog(
                title: 'Block User',
                content: 'Block this user?',
                onConfirm: () async {
                  final opponentId = _getOpponentUserId();
                  if (opponentId == null) return;
                  try {
                    await ChatService()
                        .blockUser(targetUserId: opponentId, block: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User blocked.')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Block failed: $e')));
                    }
                  }
                });
          }));
        }
        break;
      default:
        // 其他（Rejected/Closed/Canceled）
        actions.add(actionDefs('Report', Icons.article, () {
          _openReportSheet();
        }));
        actions.add(actionDefs('Block', Icons.block, () async {
          await confirmDialog(
              title: 'Block User',
              content: 'Block this user?',
              onConfirm: () async {
                final opponentId = _getOpponentUserId();
                if (opponentId == null) return;
                try {
                  await ChatService()
                      .blockUser(targetUserId: opponentId, block: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User blocked.')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Block failed: $e')));
                  }
                }
              });
        }));
        break;
    }

    return actions
        .map((a) => _actionButton(a['icon'] as IconData, a['label'] as String,
            a['onTap'] as VoidCallback))
        .toList();
  }

  // ====== 以下為動作視窗（報告、支付+評論、已付款資訊）骨架 ======
  void _openReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final descriptionCtrl = TextEditingController();
        String? selectedReason;
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Report',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Reason'),
                  const SizedBox(height: 6),
                  StatefulBuilder(builder: (context, setState) {
                    Widget reasonTile(String value, String label) {
                      return RadioListTile<String>(
                        title: Text(label),
                        value: value,
                        groupValue: selectedReason,
                        onChanged: (v) => setState(() => selectedReason = v),
                      );
                    }

                    return Column(
                      children: [
                        reasonTile('abuse', 'Abusive behavior'),
                        reasonTile('spam', 'Spam or scam'),
                        reasonTile('harassment', 'Harassment'),
                        reasonTile('dispute', 'Request Dispute'),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text('Description (min 10 chars)'),
                  TextField(maxLines: 4, controller: descriptionCtrl),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo),
                      label: const Text('Upload evidence (coming soon)')),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        final roomId = _currentRoomId;
                        if (roomId == null ||
                            selectedReason == null ||
                            (descriptionCtrl.text.trim().length < 10)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Please select a reason and enter at least 10 characters description.')));
                          return;
                        }
                        try {
                          await ChatService().reportChat(
                            roomId: roomId,
                            reason: selectedReason!,
                            description: descriptionCtrl.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Report submitted.')));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Report failed: $e')));
                          }
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPayAndReview() {
    showDialog(
      context: context,
      builder: (context) {
        int service = 0, attitude = 0, experience = 0;
        final commentCtrl = TextEditingController();
        final code1 = TextEditingController();
        final code2 = TextEditingController();
        return StatefulBuilder(builder: (context, setState) {
          Widget buildStars(int value, ValueChanged<int> onChanged) {
            return Row(
              children: List.generate(
                  5,
                  (i) => IconButton(
                        icon: Icon(i < value ? Icons.star : Icons.star_border,
                            color: Colors.amber),
                        onPressed: () => onChanged(i + 1),
                      )),
            );
          }

          return AlertDialog(
            title: const Text('Review & Pay'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service'),
                  buildStars(service, (v) => setState(() => service = v)),
                  const Text('Attitude'),
                  buildStars(attitude, (v) => setState(() => attitude = v)),
                  const Text('Experience'),
                  buildStars(experience, (v) => setState(() => experience = v)),
                  const SizedBox(height: 8),
                  const Text('Comment (<= 100 chars)'),
                  TextField(
                      controller: commentCtrl, maxLength: 100, maxLines: 3),
                  const Divider(height: 24),
                  const Text('Payment Code (6 digits) — Enter twice'),
                  TextField(
                      controller: code1,
                      keyboardType: TextInputType.number,
                      maxLength: 6),
                  TextField(
                      controller: code2,
                      keyboardType: TextInputType.number,
                      maxLength: 6),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (!(code1.text.length == 6 && code1.text == code2.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Please enter two identical 6-digit codes.')));
                    return;
                  }
                  try {
                    if (_task != null) {
                      await TaskService().payAndReview(
                        taskId: _task!['id'].toString(),
                        ratingService: service,
                        ratingAttitude: attitude,
                        ratingExperience: experience,
                        comment: commentCtrl.text.trim().isEmpty
                            ? null
                            : commentCtrl.text.trim(),
                        paymentCode1: code1.text,
                        paymentCode2: code2.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Task completed and paid.')));
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Pay failed: $e')));
                    }
                  }
                },
                child: const Text('Pay'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showPaidInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paid Info'),
        content: const Text('Show paid timestamp and transfer details here.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _openReviewDialog({bool readOnlyIfExists = false}) {
    // 簡易評論視窗骨架（之後串接後端/查已有評論改為唯讀）
    int service = 0, attitude = 0, experience = 0;
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Widget buildStars(int value, ValueChanged<int> onChanged) {
            return Row(
              children: List.generate(
                5,
                (i) => IconButton(
                  icon: Icon(i < value ? Icons.star : Icons.star_border,
                      color: Colors.amber),
                  onPressed: readOnlyIfExists ? null : () => onChanged(i + 1),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Reviews'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service'),
                  buildStars(service, (v) => setState(() => service = v)),
                  const Text('Attitude'),
                  buildStars(attitude, (v) => setState(() => attitude = v)),
                  const Text('Experience'),
                  buildStars(experience, (v) => setState(() => experience = v)),
                  const SizedBox(height: 8),
                  const Text('Comment (<= 100 chars)'),
                  TextField(
                      controller: commentCtrl,
                      maxLength: 100,
                      maxLines: 3,
                      enabled: !readOnlyIfExists),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              if (!readOnlyIfExists)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (_task != null) {
                        await TaskService().submitReview(
                          taskId: _task!['id'].toString(),
                          ratingService: service,
                          ratingAttitude: attitude,
                          ratingExperience: experience,
                          comment: commentCtrl.text.trim().isEmpty
                              ? null
                              : commentCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Review submitted.')));
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Submit review failed: $e')));
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
            ],
          );
        },
      ),
    );
  }

  // 移除 _getStatusChipColor 方法，不再使用

  // 移除 _getStatusBackgroundColor 方法，不再使用

  /// 顯示圖片預覽對話框
  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            // 當用戶按返回鍵時，這裡會被調用
            // didPop 為 true 表示已經執行了 pop，不需要額外處理
          },
          child: Dialog.fullscreen(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                // 點擊背景關閉
                GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // 圖片預覽內容
                Center(
                  child: GestureDetector(
                    onTap: () {}, // 防止點擊圖片時關閉對話框
                    child: PhotoView(
                      imageProvider: NetworkImage(imageUrl),
                      backgroundDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3.0,
                      initialScale: PhotoViewComputedScale.contained,
                      loadingBuilder: (context, event) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.white, size: 64),
                            SizedBox(height: 16),
                            Text(
                              '圖片載入失敗',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 關閉按鈕 (左上角)
                Positioned(
                  top: MediaQuery.of(dialogContext).padding.top + 16,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ),
                // 下載按鈕 (右下角)
                Positioned(
                  bottom: MediaQuery.of(dialogContext).padding.bottom + 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('下載功能開發中')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 輔助方法：安全地獲取數據
  Map<String, dynamic>? get _task => _chatData?['task'];
  Map<String, dynamic>? get _room => _chatData?['chat_room'];
  Map<String, dynamic>? get _application => _chatData?['application'];
  Map<String, dynamic>? get _chatPartnerInfo => _chatData?['chat_partner_info'];
  List<Map<String, dynamic>> get _applicationQuestions =>
      (_chatData?['application_questions'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];

  // 輔助方法：根據名字生成頭像顏色
  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
    ];
    final index = name.hashCode % colors.length;
    return colors[index];
  }

  // 輔助方法：獲取名字的首字母
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // 狀態欄輔助方法
  Color _getStatusBarColor() {
    final statusCode = _task?['status']?['code'];
    switch (statusCode) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending_confirmation':
      case 'pending_confirmation_tasker':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusBarIcon() {
    final statusCode = _task?['status']?['code'];
    switch (statusCode) {
      case 'open':
        return Icons.work;
      case 'in_progress':
        return Icons.pending;
      case 'pending_confirmation':
      case 'pending_confirmation_tasker':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  // 移除 _getStatusBarText 方法，不再使用

  Widget _buildMessageItem(Map<String, dynamic> message) {
    // 檢查是否為 View Resume 訊息
    if ((message['message'] ?? '').contains('申請已提交')) {
      return _buildViewResumeBubble(message);
    }

    // 檢查是否為圖片訊息
    final content = message['content'] ?? message['message'] ?? '';
    final imageUrl = _extractFirstImageUrl(content);

    if (imageUrl != null) {
      return _buildImageMessage(message, imageUrl);
    }

    // 普通文字訊息
    return _buildTextMessage(message);
  }

  // 渲染 View Resume 氣泡
  Widget _buildViewResumeBubble(Map<String, dynamic> message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: _opponentAvatarUrlCached != null
                    ? ImageHelper.getAvatarImage(_opponentAvatarUrlCached!)
                    : null,
                backgroundColor:
                    Theme.of(context).colorScheme.secondary.withOpacity(0.35),
                child: _opponentAvatarUrlCached == null
                    ? Text(
                        _opponentNameCached.isNotEmpty
                            ? _opponentNameCached[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 250),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        message['message'] ?? '申請已提交',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showApplierResumeDialog,
                        icon: Icon(
                          Icons.description,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(
                          'View Resume',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 渲染圖片訊息
  Widget _buildImageMessage(Map<String, dynamic> message, String imageUrl) {
    final isFromMe = message['from_user_id'] == _currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: _opponentAvatarUrlCached != null
                  ? ImageHelper.getAvatarImage(_opponentAvatarUrlCached!)
                  : null,
              backgroundColor:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.35),
              child: _opponentAvatarUrlCached == null
                  ? Text(
                      _opponentNameCached.isNotEmpty
                          ? _opponentNameCached[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250),
              child: _buildMessageContent(
                  message['content'] ?? message['message'] ?? ''),
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: ImageHelper.getAvatarImage(''), // 使用當前用戶頭像
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }

  // 渲染文字訊息
  Widget _buildTextMessage(Map<String, dynamic> message) {
    final isFromMe = message['from_user_id'] == _currentUserId;
    final content = message['content'] ?? message['message'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: _opponentAvatarUrlCached != null
                  ? ImageHelper.getAvatarImage(_opponentAvatarUrlCached!)
                  : null,
              backgroundColor:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.35),
              child: _opponentAvatarUrlCached == null
                  ? Text(
                      _opponentNameCached.isNotEmpty
                          ? _opponentNameCached[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxWidth: 250),
              decoration: BoxDecoration(
                color: isFromMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                content,
                style: TextStyle(
                  color: isFromMe
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: ImageHelper.getAvatarImage(''), // 使用當前用戶頭像
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

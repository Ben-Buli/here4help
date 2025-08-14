import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/chat/services/global_chat_room.dart';
import 'package:flutter/scheduler.dart';
import 'package:here4help/services/task_status_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:here4help/utils/path_mapper.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.data});
  final Map<String, dynamic> data; // 接收傳入的資料

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  // 統一應徵者訊息的背景色
  final Color applierBubbleColor = Colors.grey.shade100;

  // 當前登入用戶 ID
  int? _currentUserId;
  //

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
  // 狀態 Bar 動畫控制
  late AnimationController _statusBarController;
  late Animation<Offset> _statusBarSlide;
  bool _showStatusBar = true;
  Timer? _statusBarTimer;

  // Socket.IO 服務
  final SocketService _socketService = SocketService();
  String? _currentRoomId;

  // 對方頭像與名稱（相對於當前使用者的聊天室對象）快取
  String? _opponentAvatarUrlCached;
  String _opponentNameCached = 'U';

  // 進度資料暫不使用，保留映射函式如需擴充再啟用

  String _taskStatusDisplay() {
    final task = widget.data['task'] as Map<String, dynamic>? ?? {};

    // 優先使用後端返回的顯示名稱
    final dynamic explicitDisplay =
        task['status_display'] ?? task['status_name'];
    if (explicitDisplay != null && '$explicitDisplay'.isNotEmpty) {
      return '$explicitDisplay';
    }

    // 使用動態狀態服務解析
    final statusService = context.read<TaskStatusService>();
    final identifier =
        task['status_id'] ?? task['status_code'] ?? task['status'];
    return statusService.getDisplayName(identifier);
  }

  /// 獲取當前任務狀態的樣式
  TaskStatusStyle _getStatusStyle() {
    final task = widget.data['task'] as Map<String, dynamic>? ?? {};
    final statusService = context.read<TaskStatusService>();
    final colorScheme = Theme.of(context).colorScheme;
    final identifier =
        task['status_id'] ?? task['status_code'] ?? task['status'];
    return statusService.getStatusStyle(identifier, colorScheme);
  }

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
    final imageUrl = _extractFirstImageUrl(text);
    if (imageUrl == null) {
      return Text(text);
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
      final room = widget.data['room'] as Map<String, dynamic>?;
      if (room == null) return null;
      final creatorId = room['creator_id'] ?? room['creatorId'];
      final participantId = room['participant_id'] ?? room['participantId'];
      if (_currentUserId == null) return null;
      final int? creator =
          (creatorId is int) ? creatorId : int.tryParse('$creatorId');
      final int? participant = (participantId is int)
          ? participantId
          : int.tryParse('$participantId');
      if (kDebugMode) {
        debugPrint(
            '👥 resolve opponent: currentUserId=$_currentUserId, creator=$creator, participant=$participant');
      }
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
      final room = widget.data['room'] as Map<String, dynamic>?;
      final task = widget.data['task'] as Map<String, dynamic>?;
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
      Map<String, dynamic>? source;
      final room = widget.data['room'] as Map<String, dynamic>?;
      final partner = room?['chat_partner'] as Map<String, dynamic>?;
      final userObj = room?['user'] as Map<String, dynamic>?;
      final chatPartnerInfo =
          widget.data['chatPartnerInfo'] as Map<String, dynamic>?;
      source = partner ?? userObj ?? chatPartnerInfo;

      double? tryNum(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse('$v');
      }

      int? tryInt(dynamic v) {
        if (v is num) return v.toInt();
        return int.tryParse('$v');
      }

      final candidatesAvg = [
        source?['avg_rating'],
        source?['average_rating'],
        source?['rating'],
        source?['stars'],
      ];
      for (final c in candidatesAvg) {
        final v = tryNum(c);
        if (v != null) {
          avg = v;
          break;
        }
      }

      final candidatesCount = [
        source?['review_count'],
        source?['reviews_count'],
        source?['comments_count'],
        source?['comments'],
      ];
      for (final c in candidatesCount) {
        final v = tryInt(c);
        if (v != null) {
          count = v;
          break;
        }
      }
    } catch (_) {}
    return (avg, count);
  }

  // 移除未使用的 _getRoomCreatorId 以消除警告

  // 移除未使用的 _getRoomParticipantId 以消除 linter 警告

  // 移除未使用的 _amCreatorInThisRoom 以消除警告

  /// 取得對方大頭貼 URL（依對方 userId 判斷應取哪一側欄位）
  String? _getOpponentAvatarUrl() {
    try {
      final room = widget.data['room'] as Map<String, dynamic>?;
      final task = widget.data['task'] as Map<String, dynamic>?;
      final partner = room?['chat_partner'] as Map<String, dynamic>?;
      final chatPartnerInfo =
          widget.data['chatPartnerInfo'] as Map<String, dynamic>?;
      if (room == null) return null;
      final int? opponentId = _getOpponentUserId();
      final int? participantId = (room['participant_id'] is int)
          ? room['participant_id']
          : int.tryParse('${room['participant_id']}');
      List<dynamic> candidates;
      if (opponentId != null &&
          participantId != null &&
          opponentId == participantId) {
        // 對方為 participant
        final participantObj = room['participant'] as Map<String, dynamic>?;
        candidates = [
          room['participant_avatar'],
          room['participant_avatar_url'],
          participantObj?['avatar_url'],
          room['applier_avatar'],
          chatPartnerInfo?['avatar_url'],
          chatPartnerInfo?['avatar'],
          task?['participant_avatar_url'],
          task?['participant_avatar'],
        ];
      } else {
        // 對方為 creator
        candidates = [
          room['creator_avatar'],
          room['creator_avatar_url'],
          partner?['avatar_url'],
          partner?['avatar'],
          chatPartnerInfo?['avatar_url'],
          chatPartnerInfo?['avatar'],
          task?['creator_avatar'],
          task?['creator_avatar_url'],
        ];
      }
      for (final c in candidates) {
        if (c is String && c.trim().isNotEmpty) return c;
      }
      return null;
    } catch (_) {
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

    // 先設置 roomId
    _currentRoomId = widget.data['room']['id']?.toString() ??
        widget.data['room']['roomId']?.toString();

    if (kDebugMode) {
      debugPrint('🔍 initState: 設置 _currentRoomId = $_currentRoomId');
    }

    _loadCurrentUserId().then((_) {
      if (mounted) {
        _initializeChat(); // 等待當前用戶 ID 載入完成後再初始化聊天室
      }
    });

    // 初始化狀態 Bar 動畫：顯示 3 秒後往下滑動消失
    _statusBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _statusBarSlide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
        .animate(CurvedAnimation(
            parent: _statusBarController, curve: Curves.linear));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _startStatusBarAutoDismiss());
    // 首次進入後解析一次對方身份（若資料稍後才齊，全局回調也會再觸發一次）
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _resolveOpponentIdentity());

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
    // 加強 pendingStart 處理，若不存在自動補上
    final currentStatus = widget.data['task']['status']?.toString() ?? '';

    if (currentStatus == 'pending_confirmation_tasker') {
      taskPendingStart =
          DateTime.tryParse(widget.data['task']['pendingStart'] ?? '') ??
              DateTime.now();
      widget.data['task']['pendingStart'] = taskPendingStart.toIso8601String();
      taskPendingEnd = taskPendingStart.add(const Duration(seconds: 5));
      remainingTime = taskPendingEnd.difference(DateTime.now());
      countdownTicker = Ticker(_onTick)..start();
    } else if (currentStatus == 'pending_confirmation') {
      taskPendingStart =
          DateTime.tryParse(widget.data['task']['pendingStart'] ?? '') ??
              DateTime.now();
      widget.data['task']['pendingStart'] = taskPendingStart.toIso8601String();
      taskPendingEnd = taskPendingStart.add(const Duration(days: 7));
      remainingTime = taskPendingEnd.difference(DateTime.now());
      countdownTicker = Ticker(_onTick)..start();
    } else {
      remainingTime = const Duration();
    }
  }

  void _startStatusBarAutoDismiss() {
    if (!mounted) return;
    setState(() => _showStatusBar = true);
    _statusBarTimer?.cancel();
    _statusBarTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        await _statusBarController.forward();
      } finally {
        if (!mounted) return;
        setState(() => _showStatusBar = false);
        _statusBarController.reset();
      }
    });
  }

  /// 載入當前登入用戶 ID
  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final currentAvatar = prefs.getString('user_avatarUrl') ?? '';
      if (mounted) {
        setState(() {
          _currentUserId = userId;
          // 根據當前用戶決定角色
          final creatorId = widget.data['task']['creator_id'];
          if (creatorId != null && userId != null) {
            _userRole = (creatorId == userId) ? 'creator' : 'participant';
          }
        });
        debugPrint(
            '🔍 current user avatar from prefs: ${currentAvatar.isNotEmpty ? currentAvatar : 'empty'}');
        // 當取得 userId 後再解析一次對方身份，避免因為 _currentUserId 為 null 造成角色判斷錯誤
        _resolveOpponentIdentity();
      }
      debugPrint('🔍 當前登入用戶 ID: $_currentUserId');
    } catch (e) {
      debugPrint('❌ 無法載入當前用戶 ID: $e');
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
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (_currentRoomId == null) throw Exception('room 未初始化');

      // Web 需使用 bytes 上傳；原生可用 path。這裡優先走 bytes，失敗再回退 path。
      Map<String, dynamic> upload;
      try {
        final bytes = await file.readAsBytes();
        upload = await ChatService().uploadAttachment(
          roomId: _currentRoomId!,
          bytes: bytes,
          fileName: file.name,
        );
      } catch (_) {
        upload = await ChatService().uploadAttachment(
          roomId: _currentRoomId!,
          filePath: file.path,
        );
      }
      final url = upload['url'] ?? upload['path'] ?? '';
      final fileName = file.name;
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
    if (_currentRoomId != null) {
      if (kDebugMode) {
        debugPrint('🔍 _initializeChat: 開始初始化聊天室，roomId = $_currentRoomId');
      }
      await _loadChatMessages();
      await _setupSocket();
    } else {
      if (kDebugMode) {
        debugPrint('❌ 無法取得 roomId，跳過聊天室初始化');
      }
    }
  }

  /// 設置 Socket.IO 連接
  Future<void> _setupSocket() async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 _setupSocket: 開始設置 Socket 連接');
      }

      // 設置事件監聽器（在連接前設置，確保不會錯過事件）
      _socketService.onMessageReceived = _onMessageReceived;
      _socketService.onUnreadUpdate = _onUnreadUpdate;

      // 連接 Socket.IO
      await _socketService.connect();

      // 等待連接完成
      int retryCount = 0;
      while (!_socketService.isConnected && retryCount < 10) {
        if (kDebugMode) {
          debugPrint('⏳ 等待 Socket 連接... 嘗試 $retryCount/10');
        }
        await Future.delayed(Duration(milliseconds: 500));
        retryCount++;
      }

      if (!_socketService.isConnected) {
        if (kDebugMode) {
          debugPrint('❌ Socket 連接超時');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ Socket 連接成功，開始加入房間');
      }

      // 加入當前聊天室
      if (_currentRoomId != null) {
        _socketService.joinRoom(_currentRoomId!);
        // 標記為已讀
        _socketService.markRoomAsRead(_currentRoomId!);
        // 每次建立/切換聊天室時，解析一次對方身份與頭像
        _resolveOpponentIdentity();

        if (kDebugMode) {
          debugPrint('✅ Socket setup completed for room: $_currentRoomId');
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ _currentRoomId 為 null，無法加入房間');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Socket setup failed: $e');
      }
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
      if (kDebugMode) {
        debugPrint(
            '🧩 Opponent resolved: id=${oppId ?? 'null'}, name=$_opponentNameCached, avatar=${_opponentAvatarUrlCached ?? 'null'}');
      }
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

      // 避免在初始化期間重複載入訊息
      if (!_isLoadingMessages) {
        _loadChatMessages();
      }
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
    _isLoadingMessages = true;

    try {
      final roomId = _currentRoomId;
      if (kDebugMode) {
        debugPrint(
            '🔍 _loadChatMessages: 開始載入，_currentRoomId = $_currentRoomId');
      }

      if (roomId == null || roomId.isEmpty) {
        if (kDebugMode) {
          debugPrint('❌ 無法取得 roomId');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('🔍 載入聊天訊息，roomId: $roomId');
      }

      final result = await ChatService().getMessages(roomId: roomId);

      // 只在調試模式下輸出詳細信息
      if (kDebugMode) {
        debugPrint('🔍 API 返回結果: $result');
        debugPrint('🔍 API 返回結果類型: ${result.runtimeType}');
        debugPrint('🔍 API 返回結果鍵: ${result.keys.toList()}');
      }

      final messages = result['messages'] as List<dynamic>? ?? [];

      if (kDebugMode) {
        debugPrint('🔍 解析後的訊息陣列: $messages');
        debugPrint('🔍 訊息數量: ${messages.length}');
        debugPrint('🔍 訊息陣列類型: ${messages.runtimeType}');
      }

      if (messages.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ 訊息陣列為空，檢查 API 返回結果');
          debugPrint('⚠️ result 內容: $result');
        }
      }

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
        // 在底部則保持自動滾到底
        if (_isAtBottom) {
          _scrollToBottom(delayed: true);
        }
      }

      if (kDebugMode) {
        debugPrint('✅ 成功載入 ${_chatMessages.length} 條訊息');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 載入聊天訊息失敗: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
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
        widget.data['task']['status'] = 'completed_tasker';
      });
      TaskService().updateTaskStatus(
        widget.data['task']['id'].toString(),
        'completed_tasker',
        statusCode: 'completed',
      );
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
      final roomId = widget.data['room']['id']?.toString() ??
          widget.data['room']['roomId']?.toString();
      final taskId = widget.data['task']['id']?.toString();

      if (roomId == null || roomId.isEmpty) {
        debugPrint('❌ 無法取得 roomId，無法發送訊息');
        return;
      }

      debugPrint('🔍 發送訊息到聊天室: $roomId, 內容: $text');

      // 先清空輸入框，提供即時回饋；並加入暫存訊息（顯示傳送中）
      _controller.clear();
      _focusNode.requestFocus();
      setState(() {
        _pendingMessages.add({
          'message': text,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      // 發送訊息到後端（HTTP API）
      final result = await ChatService().sendMessage(
        roomId: roomId,
        message: text,
        taskId: taskId,
      );

      debugPrint('✅ 訊息發送成功: ${result['message_id']}');

      // 透過 Socket.IO 廣播即時訊息（可選，後端 API 也會觸發）
      if (_socketService.isConnected && _currentRoomId != null) {
        _socketService.sendMessage(
          roomId: _currentRoomId!,
          text: text,
          messageId: result['message_id']?.toString(),
        );
      }

      // 重新載入訊息列表並移除暫存
      await _loadChatMessages();
      if (mounted) {
        setState(() {
          if (_pendingMessages.isNotEmpty) _pendingMessages.removeAt(0);
        });
      }
      // 我方發送後直接滾到底部並隱藏新訊息提示
      if (mounted) {
        setState(() {
          _showNewMsgBanner = false;
          _unseenCount = 0;
        });
        _scrollToBottom(delayed: true);
      }
    } catch (e) {
      debugPrint('❌ 發送訊息失敗: $e');

      // 發送失敗時，顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('發送訊息失敗: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // 離開聊天室
    if (_currentRoomId != null) {
      _socketService.leaveRoom(_currentRoomId!);
    }

    // 清理計時器
    final currentStatus = widget.data['task']['status']?.toString() ?? '';
    if (currentStatus == 'pending_confirmation_tasker' ||
        currentStatus == 'pending_confirmation') {
      countdownTicker.dispose();
    }

    _controller.dispose();
    _focusNode.dispose();
    _statusBarTimer?.cancel();
    _statusBarController.dispose();
    super.dispose();
  }

  /// 獲取應徵者的應徵資料
  Future<Map<String, dynamic>?> _getApplicationData(
      String taskId, int applicantId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.applicationsListByTaskUrl}?task_id=$taskId'),
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

  /// 顯示應徵者真實應徵資料的對話框
  void _showApplierResumeDialog(BuildContext context) async {
    // 顯示載入對話框（使用 rootNavigator，並確保關閉動作安全）
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    bool loaderClosed = false;
    void closeLoaderSafely() {
      if (loaderClosed || !mounted) return;
      loaderClosed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
        }
      });
    }

    try {
      // 獲取 taskId 和 applicantId（在整個方法中都需要）
      final taskId = widget.data['task']['id']?.toString() ?? '';
      final dynamic rawApplicantId = widget.data['room']['participant_id'] ??
          widget.data['room']['user_id'] ??
          widget.data['chatPartnerInfo']?['id'] ??
          0;
      final int applicantId = (rawApplicantId is int)
          ? rawApplicantId
          : int.tryParse(rawApplicantId.toString()) ?? 0;

      // 優先使用從 extra 傳遞的數據
      final coverLetter = widget.data['room']['coverLetter'];
      final answersJson = widget.data['room']['answersJson'];
      Map<String, dynamic> answers = {};

      if (answersJson != null) {
        try {
          if (answersJson is String && answersJson.isNotEmpty) {
            answers = jsonDecode(answersJson);
          } else if (answersJson is Map<String, dynamic>) {
            answers = answersJson;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ 解析 answers_json 失敗: $e');
          }
        }
      }

      // 如果沒有 answers_json，則嘗試從 API 獲取
      Map<String, dynamic>? applicationData;
      if (answers.isEmpty) {
        applicationData = await _getApplicationData(taskId, applicantId);
        if (applicationData != null) {
          // 解析 API 返回的 answers_json
          final dynamic raw = applicationData['answers_json'];
          try {
            if (raw != null) {
              if (raw is String && raw.isNotEmpty) {
                answers = jsonDecode(raw);
              } else if (raw is Map<String, dynamic>) {
                answers = raw;
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ 解析 API answers_json 失敗: $e');
            }
          }
        }
      }

      // 關閉載入對話框（安全）
      closeLoaderSafely();

      // 如果有 answers 數據，顯示對話框
      if (answers.isNotEmpty || applicationData != null) {
        // 使用已經解析好的 answers 變量，或者從 applicationData 獲取
        if (answers.isEmpty && applicationData != null) {
          final dynamic raw = applicationData['answers_json'];
          try {
            if (raw != null) {
              if (raw is String && raw.isNotEmpty) {
                answers = jsonDecode(raw);
              } else if (raw is Map<String, dynamic>) {
                answers = raw;
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error parsing answers_json: $e');
            }
          }
        }

        // 顯示真實的應徵資料（避免與上一個對話框同幀衝突）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            useRootNavigator: true,
            builder: (context) => AlertDialog(
              title: const Center(child: Text('Applicant Resume')),
              actions: [
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 應徵者基本資訊
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                applicationData?['applier_avatar'] != null
                                    ? (applicationData?['applier_avatar']
                                            .startsWith('http')
                                        ? NetworkImage(
                                            applicationData?['applier_avatar'])
                                        : AssetImage(applicationData?[
                                            'applier_avatar']) as ImageProvider)
                                    : null,
                            child: applicationData?['applier_avatar'] == null
                                ? Text(
                                    (applicationData?['applier_name'] ?? 'U')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  applicationData?['applier_name'] ??
                                      'Anonymous',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Application Time : ${applicationData?['created_at'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Self-recommendation（以 cover_letter 為主）
                      if ((applicationData?['cover_letter'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const Text(
                          'Self‑recommendation',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text((applicationData?['cover_letter'] ?? '')
                              .toString()),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 其他問題回答：逐一以「問題原文」作為標題
                      ...answers.keys
                          .where((key) =>
                              (answers[key]?.toString().trim().isNotEmpty ??
                                  false))
                          .map((key) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(answers[key]?.toString() ?? ''),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      } else {
        // 找不到應徵資料時的友善提示（關閉 loader 後再顯示）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            useRootNavigator: true,
            builder: (context) => AlertDialog(
              title: const Text('No application data found'),
              content: Text(
                  'No application data found for task (ID: $taskId) and user (ID: $applicantId).'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      // 關閉載入對話框（安全）
      closeLoaderSafely();

      // 顯示錯誤訊息（避免與 loader 衝突）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Error loading application data: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionReply = widget.data['room']['questionReply'] ?? '';
    // final applier = widget.data['room'];

    // 使用從資料庫載入的訊息列表
    int totalItemCount = (questionReply.isNotEmpty ? 1 : 0) +
        _chatMessages.length +
        (_pendingMessages.length);

    debugPrint(
        '🔍 Total messages: $totalItemCount (questionReply: ${questionReply.isNotEmpty ? 1 : 0}, chatMessages: ${_chatMessages.length})');

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
                                  onPressed: () =>
                                      _showApplierResumeDialog(context),
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
        {String? senderName,
        String? messageTime,
        bool isApplyMessage = false}) {
      // 先前的 opponentInfo 已不再使用，頭像/名稱以快取為準

      // 檢查是否為應徵訊息
      final isApplicationMessage = isApplyMessage ||
          text.contains('Self‑recommendation') ||
          text.contains('cover_letter') ||
          text.contains('answers_json') ||
          text.contains('Application Submitted');

      // 若是應徵訊息，只在氣泡中顯示 cover_letter，
      // 其餘 answers 內容改由 View Resume 視窗呈現
      String displayText = text;
      if (isApplicationMessage) {
        final List<String> answerMarkers = <String>[
          '應徵者回答：',
          'Applicant Answers:',
          'Answers:',
        ];
        for (final String marker in answerMarkers) {
          if (displayText.contains(marker)) {
            displayText = displayText.split(marker).first.trim();
            break;
          }
        }
      }

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 訊息氣泡
                            Container(
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 300),
                              decoration: BoxDecoration(
                                color: isApplicationMessage
                                    ? Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                    : Theme.of(context).colorScheme.secondary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: isApplicationMessage
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        width: 1)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 如果是應徵訊息，顯示特殊標識
                                  if (isApplicationMessage) ...[
                                    Row(
                                      children: [
                                        Icon(Icons.description,
                                            size: 16, color: Colors.amber[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Application Submitted',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Divider(
                                        height: 1, color: Colors.amber),
                                    const SizedBox(height: 4),
                                  ],

                                  // 訊息內容
                                  DefaultTextStyle.merge(
                                    style: TextStyle(
                                      color: isApplicationMessage
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSecondary,
                                    ),
                                    child: _buildMessageContent(displayText),
                                  ),
                                ],
                              ),
                            ),

                            // 如果是應徵訊息，顯示 View Resume 按鈕
                            if (isApplicationMessage) ...[
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () =>
                                        _showApplierResumeDialog(context),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.visibility,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer),
                                          const SizedBox(width: 6),
                                          Text(
                                            'View Resume',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                      child: _buildMessageContent(text),
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

    final currentStatus = widget.data['task']['status']?.toString() ?? '';
    final isInputDisabled = currentStatus == 'completed' ||
        currentStatus == 'rejected_tasker' ||
        currentStatus == 'completed_tasker';
    // --- ALERT BAR SWITCH-CASE 重構 ---
    // 預設 alert bar 不會顯示，只有在特定狀態下才顯示
    Widget? alertContent;
    switch (widget.data['task']['status']) {
      case 'Applying (Tasker)':
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
      case 'Rejected (Tasker)':
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
      case 'Pending Confirmation (Tasker)':
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
      case 'Pending Confirmation':
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
                  if (questionReply.isNotEmpty && index == 0) {
                    return buildQuestionReplyBubble(questionReply);
                  }

                  int adjustedIndex =
                      index - (questionReply.isNotEmpty ? 1 : 0);

                  // 使用從資料庫載入的訊息列表
                  if (adjustedIndex < _chatMessages.length) {
                    final messageData = _chatMessages[adjustedIndex];
                    final messageText =
                        messageData['message']?.toString() ?? '';
                    final messageKind = messageData['kind']?.toString();
                    final messageFromUserId = messageData['from_user_id'];
                    final messageTime =
                        messageData['created_at']?.toString() ?? '';
                    final senderName =
                        messageData['sender_name']?.toString() ?? 'Unknown';

                    // 判斷這條訊息是否來自當前用戶
                    final isMyMessage = _currentUserId != null &&
                        messageFromUserId == _currentUserId;

                    // debugPrint(
                    //     '🔍 Message judgment: messageFromUserId=$messageFromUserId, currentUserId=$_currentUserId, isMyMessage=$isMyMessage, text=$messageText');

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
                      return buildOpponentBubble(
                        messageText,
                        messageFromUserId,
                        senderName: senderName,
                        messageTime: messageTime,
                        isApplyMessage: (messageKind == 'applyMessage'),
                      );
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
        // 將 status bar 以覆蓋方式顯示 3 秒，再滑動消失
        if (_showStatusBar)
          SlideTransition(
            position: _statusBarSlide,
            child: Container(
              color: _getStatusStyle().backgroundColor,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _taskStatusDisplay(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _getStatusStyle().foregroundColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const Divider(
          height: 1,
          thickness: 2,
        ),
        if (_showActionBar)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _glassNavColor(context),
                ),
                // 將分隔線下方的間距改為 Action Bar 的內距（paddingTop）
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Row(
                  children: _buildActionButtonsByStatus()
                      .map((e) => Expanded(
                            child: IconTheme(
                              data: IconThemeData(
                                color: Theme.of(context)
                                        .appBarTheme
                                        .foregroundColor ??
                                    Colors.white,
                              ),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  color: Theme.of(context)
                                          .appBarTheme
                                          .foregroundColor ??
                                      Colors.white,
                                ),
                                child: e,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
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

  List<Widget> _buildActionButtonsByStatus() {
    final status = (widget.data['task']['status'] ?? '').toString();
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
      case 'Open':
        if (isCreator) {
          actions.add(actionDefs('Accept', Icons.check, () async {
            await confirmDialog(
              title: 'Double Check',
              content:
                  'Are you sure you want to assign this applicant to this task?',
              onConfirm: () async {
                await TaskService().updateTaskStatus(
                  widget.data['task']['id'].toString(),
                  'in_progress',
                  statusCode: 'in_progress',
                );
                // 關閉其他申請聊天室（舊全域資料結構保留）
                GlobalChatRoom().removeRoomsByTaskIdExcept(
                  widget.data['task']['id'].toString(),
                  widget.data['room']['roomId'].toString(),
                );
                if (mounted) setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Task accepted. Now in progress.')),
                );
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
      case 'In Progress':
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
                widget.data['task']['pendingStart'] =
                    DateTime.now().toIso8601String();
                await TaskService().updateTaskStatus(
                  widget.data['task']['id'].toString(),
                  'pending_confirmation_tasker',
                  statusCode: 'pending_confirmation',
                );
                if (mounted) setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Waiting for poster confirmation.')));
              },
            );
          }));
          actions.add(actionDefs('Report', Icons.article, () {
            _openReportSheet();
          }));
        }
        break;
      case 'Pending Confirmation':
        if (isCreator) {
          actions.add(actionDefs('Confirm', Icons.check, () async {
            await confirmDialog(
              title: 'Double Check',
              content:
                  'Confirm this task and transfer reward points to the Tasker?',
              onConfirm: () async {
                try {
                  await TaskService().confirmCompletion(
                      taskId: widget.data['task']['id'].toString());
                  if (mounted) setState(() {});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Task confirmed and paid.')));
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
                  await TaskService().disagreeCompletion(
                      taskId: widget.data['task']['id'].toString());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Disagree submitted.')));
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
      case 'Dispute':
        actions.add(actionDefs('Report', Icons.article, () {
          _openReportSheet();
        }));
        break;
      case 'Completed':
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
                    await TaskService().payAndReview(
                      taskId: widget.data['task']['id'].toString(),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Task completed and paid.')));
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
                      await TaskService().submitReview(
                        taskId: widget.data['task']['id'].toString(),
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
                            const SnackBar(content: Text('Review submitted.')));
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

  Color _getStatusChipColor(String status) {
    final statusService = context.read<TaskStatusService>();
    final colorScheme = Theme.of(context).colorScheme;
    final style = statusService.getStatusStyle(status, colorScheme);
    return style.foregroundColor;
  }

  Color _getStatusBackgroundColor(String status) {
    final statusService = context.read<TaskStatusService>();
    final colorScheme = Theme.of(context).colorScheme;
    final style = statusService.getStatusStyle(status, colorScheme);
    return style.backgroundColor;
  }

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
                      onPressed: () async {
                        try {
                          // 顯示下載中提示
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('正在下載圖片...'),
                              duration: Duration(seconds: 2),
                            ),
                          );

                          // 下載圖片
                          final response = await http.get(Uri.parse(imageUrl));
                          if (response.statusCode == 200) {
                            // 獲取檔案名稱
                            final fileName = imageUrl.split('/').last;

                            // 在 Web 環境中，使用瀏覽器的下載功能
                            if (kIsWeb) {
                              final blob = html.Blob([response.bodyBytes]);
                              final url =
                                  html.Url.createObjectUrlFromBlob(blob);
                              final anchor = html.AnchorElement(href: url)
                                ..setAttribute('download', fileName)
                                ..click();
                              html.Url.revokeObjectUrl(url);

                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('圖片已下載: $fileName'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              // 在原生環境中，保存到相冊
                              // 這裡需要添加相冊權限和保存邏輯
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('原生環境下載功能開發中'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } else {
                            throw Exception('下載失敗: ${response.statusCode}');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text('下載失敗: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
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

  /// 構建聊天訊息項目
  Widget _buildMessageItem(Map<String, dynamic> message, int index) {
    final isMe =
        message['from_user_id']?.toString() == _currentUserId?.toString();
    final messageText = message['message'] ?? '';
    final messageTime = message['created_at'] ?? '';
    final isApplicationMessage = message['is_application_message'] == true ||
        (messageText.contains('Self‑recommendation') ||
            messageText.contains('cover_letter') ||
            messageText.contains('answers_json'));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            // 對方頭像
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: _opponentAvatarUrlCached != null &&
                        _opponentAvatarUrlCached!.isNotEmpty
                    ? ((_opponentAvatarUrlCached!.startsWith('http')
                            ? NetworkImage(_opponentAvatarUrlCached!)
                            : AssetImage(_opponentAvatarUrlCached!))
                        as ImageProvider)
                    : null,
                backgroundColor: Colors.grey[400],
                child: _opponentAvatarUrlCached == null ||
                        _opponentAvatarUrlCached!.isEmpty
                    ? Text(
                        _opponentNameCached.isNotEmpty
                            ? _opponentNameCached[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
            ),
          ],

          // 訊息氣泡
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 訊息內容
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).colorScheme.primary
                        : (isApplicationMessage
                            ? Colors.amber[50]
                            : applierBubbleColor),
                    borderRadius: BorderRadius.circular(16),
                    border: isApplicationMessage
                        ? Border.all(color: Colors.amber[300]!, width: 1)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 如果是應徵訊息，顯示特殊標識
                      if (isApplicationMessage) ...[
                        Row(
                          children: [
                            Icon(Icons.description,
                                size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Application Submitted',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Divider(height: 1, color: Colors.amber),
                        const SizedBox(height: 4),
                      ],

                      // 訊息文字
                      Text(
                        messageText,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : (isApplicationMessage
                                  ? Colors.grey[800]
                                  : Colors.black87),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // 時間戳記
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatMessageTime(messageTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),

                // 如果是應徵訊息且不是自己發的，顯示 View Resume 按鈕
                if (isApplicationMessage && !isMe) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[300]!),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showApplierResumeDialog(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility,
                                  size: 16, color: Colors.amber[800]),
                              const SizedBox(width: 6),
                              Text(
                                'View Resume',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (isMe) ...[
            // 我的頭像
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  'Me',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

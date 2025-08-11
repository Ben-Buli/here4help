import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/chat/services/global_chat_room.dart';
import 'package:flutter/scheduler.dart';
import 'package:here4help/constants/task_status.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:image_picker/image_picker.dart';

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
  List<Map<String, dynamic>> _pendingMessages = [];
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

  // 進度資料暫不使用，保留映射函式如需擴充再啟用

  String _taskStatusDisplay() {
    final task = widget.data['task'] as Map<String, dynamic>? ?? {};
    final dynamic explicitDisplay =
        task['status_display'] ?? task['status_name'];
    if (explicitDisplay != null && '$explicitDisplay'.isNotEmpty) {
      return '$explicitDisplay';
    }
    final dynamic code = task['status_code'] ?? task['status'];
    if (code != null) {
      final codeStr = '$code';
      // 若已是顯示文字，直接回傳；若是代碼，用映射轉為顯示文字
      final mapped = TaskStatus.statusString[codeStr];
      if (mapped != null) return mapped;
      // 嘗試從顯示文字反推代碼（以值比對）
      final entry = TaskStatus.statusString.entries.firstWhere(
          (e) => e.value == codeStr,
          orElse: () => const MapEntry('', ''));
      if (entry.key.isNotEmpty) return entry.value;
      return codeStr;
    }
    return '';
  }

  // _taskStatusCode() 暫不使用（資料以顯示文字流程處理）

  int? _getOpponentUserId() {
    try {
      final room = widget.data['room'] as Map<String, dynamic>?;
      if (room == null) return null;
      final creatorId = room['creator_id'] ?? room['creatorId'];
      final participantId = room['participant_id'] ?? room['participantId'];
      if (_currentUserId == null) return null;
      if (creatorId == _currentUserId) {
        return participantId is int
            ? participantId
            : int.tryParse('$participantId');
      } else {
        return creatorId is int ? creatorId : int.tryParse('$creatorId');
      }
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
    _loadCurrentUserId();
    _initializeChat(); // 載入當前用戶 ID

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
    if (widget.data['task']['status'] ==
        TaskStatus.statusString['pending_confirmation_tasker']) {
      taskPendingStart =
          DateTime.tryParse(widget.data['task']['pendingStart'] ?? '') ??
              DateTime.now();
      widget.data['task']['pendingStart'] = taskPendingStart.toIso8601String();
      taskPendingEnd = taskPendingStart.add(const Duration(seconds: 5));
      remainingTime = taskPendingEnd.difference(DateTime.now());
      countdownTicker = Ticker(_onTick)..start();
    } else if (widget.data['task']['status'] ==
        TaskStatus.statusString['pending_confirmation']) {
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
      if (mounted) {
        setState(() {
          _currentUserId = userId;
          // 根據當前用戶決定角色
          final creatorId = widget.data['task']['creator_id'];
          if (creatorId != null && userId != null) {
            _userRole = (creatorId == userId) ? 'creator' : 'participant';
          }
        });
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

      final upload = await ChatService().uploadAttachment(
        roomId: _currentRoomId!,
        filePath: file.path,
      );
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
    await _loadChatMessages();
    await _setupSocket();
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
      _currentRoomId = widget.data['room']['id']?.toString() ??
          widget.data['room']['roomId']?.toString();

      if (_currentRoomId != null) {
        _socketService.joinRoom(_currentRoomId!);
        // 標記為已讀
        _socketService.markRoomAsRead(_currentRoomId!);
      }

      debugPrint('✅ Socket setup completed for room: $_currentRoomId');
    } catch (e) {
      debugPrint('❌ Socket setup failed: $e');
    }
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
          (fromUserId == _currentUserId ||
              '${fromUserId}' == '${_currentUserId}');
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
    debugPrint('🔔 Unread update: $unreadData');
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

      final roomId = widget.data['room']['id']?.toString() ??
          widget.data['room']['roomId']?.toString();

      if (roomId == null || roomId.isEmpty) {
        debugPrint('❌ 無法取得 roomId');
        return;
      }

      debugPrint('🔍 載入聊天訊息，roomId: $roomId');

      final result = await ChatService().getMessages(roomId: roomId);
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
        widget.data['task']['status'] =
            TaskStatus.statusString['completed_tasker'];
      });
      TaskService().updateTaskStatus(
        widget.data['task']['id'].toString(),
        TaskStatus.statusString['completed_tasker']!,
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
    if (widget.data['task']['status'] ==
            TaskStatus.statusString['pending_confirmation_tasker'] ||
        widget.data['task']['status'] ==
            TaskStatus.statusString['pending_confirmation']) {
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
      final taskId = widget.data['task']['id']?.toString() ?? '';
      // 嘗試從多個來源推斷 applicantId（優先 room.participant_id）
      final dynamic rawApplicantId = widget.data['room']['participant_id'] ??
          widget.data['room']['user_id'] ??
          widget.data['chatPartnerInfo']?['id'] ??
          0;
      final int applicantId = (rawApplicantId is int)
          ? rawApplicantId
          : int.tryParse(rawApplicantId.toString()) ?? 0;

      final applicationData = await _getApplicationData(taskId, applicantId);
      // 關閉載入對話框（安全）
      closeLoaderSafely();

      if (applicationData != null) {
        // 安全解析 answers_json（可能為字串或已是物件），鍵為「問題原文」
        Map<String, dynamic> answers = {};
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
          debugPrint('Error parsing answers_json: $e');
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
                                applicationData['applier_avatar'] != null
                                    ? (applicationData['applier_avatar']
                                            .startsWith('http')
                                        ? NetworkImage(
                                            applicationData['applier_avatar'])
                                        : AssetImage(applicationData[
                                            'applier_avatar']) as ImageProvider)
                                    : null,
                            child: applicationData['applier_avatar'] == null
                                ? Text(
                                    (applicationData['applier_name'] ?? 'U')[0]
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
                                  applicationData['applier_name'] ??
                                      'Anonymous',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Application Time : ${applicationData['created_at'] ?? 'Unknown'}',
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
                      if ((applicationData['cover_letter'] ?? '')
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
                          child: Text((applicationData['cover_letter'] ?? '')
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
    final room = widget.data['room'];
    final applier = widget.data['room'];

    // 使用從資料庫載入的訊息列表
    int totalItemCount = (questionReply.isNotEmpty ? 1 : 0) +
        _chatMessages.length +
        (_pendingMessages.length);

    debugPrint(
        '🔍 Total messages: $totalItemCount (questionReply: ${questionReply.isNotEmpty ? 1 : 0}, chatMessages: ${_chatMessages.length})');

    Widget buildQuestionReplyBubble(String text) {
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
                  backgroundImage: (room['user']?['avatar_url'] ??
                              applier['avatar_url']) !=
                          null
                      ? NetworkImage(
                          room['user']?['avatar_url'] ?? applier['avatar_url'])
                      : null,
                  child: ((room['user']?['avatar_url'] ??
                              applier['avatar_url']) ==
                          null)
                      ? Text(
                          (room['user']?['name'] ?? applier['name'] ?? 'U')[0]
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      _showApplierResumeDialog(context),
                                  child: const Text('View Resume'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        joinTime,
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

    Widget buildOpponentBubble(String text, int? opponentUserId,
        {String? senderName, String? messageTime}) {
      // 根據對方身份獲取對應的用戶資訊
      Map<String, dynamic> opponentInfo = {};

      // 檢查是否為任務發布者
      final taskCreatorId = widget.data['task']['creator_id'];
      if (opponentUserId == taskCreatorId) {
        // 對方是任務發布者
        opponentInfo = {
          'name': widget.data['task']['creator_name'] ??
              room['chat_partner']?['name'] ??
              'Task Creator',
          'avatar_url': widget.data['task']['creator_avatar'] ??
              room['chat_partner']?['avatar_url'] ??
              '',
        };
      } else {
        // 對方是應徵者，從 room 中獲取
        opponentInfo = {
          'name':
              room['user']?['name'] ?? room['participant_name'] ?? 'Applicant',
          'avatar_url': room['user']?['avatar_url'] ??
              room['participant_avatar'] ??
              room['avatar'] ??
              '',
        };
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
                  backgroundImage:
                      ImageHelper.getAvatarImage(opponentInfo['avatar_url']),
                  child:
                      ImageHelper.getAvatarImage(opponentInfo['avatar_url']) ==
                              null
                          ? Text(
                              (opponentInfo['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
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
                          child: Text(text),
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
                    child: Text(text),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(width: 6),
                      // 依賴 _opponentLastReadMessageId 與本訊息 id 比較（於列表組裝時傳入）
                      if (message.containsKey('read'))
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: (message['read'] == 'true')
                              ? Colors.blueAccent
                              : Colors.grey,
                        ),
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

    final isInputDisabled =
        widget.data['task']['status'] == TaskStatus.statusString['completed'] ||
            widget.data['task']['status'] ==
                TaskStatus.statusString['rejected_tasker'] ||
            widget.data['task']['status'] ==
                TaskStatus.statusString['completed_tasker'];
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
              '⏰ ${remainingTime.inDays}d ${remainingTime.inHours.remainder(24).toString().padLeft(2, '0')}:${remainingTime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'If the poster does not confirm within 7 days, the task will be automatically marked as completed and the payment will be transferred.',
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
                    final messageFromUserId = messageData['from_user_id'];
                    final messageTime =
                        messageData['created_at']?.toString() ?? '';
                    final senderName =
                        messageData['sender_name']?.toString() ?? 'Unknown';

                    // 判斷這條訊息是否來自當前用戶
                    final isMyMessage = _currentUserId != null &&
                        messageFromUserId == _currentUserId;

                    debugPrint(
                        '🔍 Message judgment: messageFromUserId=$messageFromUserId, currentUserId=$_currentUserId, isMyMessage=$isMyMessage, text=$messageText');

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
        // 將 status bar 以覆蓋方式顯示 3 秒，再滑動消失
        if (_showStatusBar)
          SlideTransition(
            position: _statusBarSlide,
            child: Container(
              color: TaskStatus.themedColors(
                          Theme.of(context).colorScheme)[_taskStatusDisplay()]
                      ?.bg ??
                  _getStatusBackgroundColor(_taskStatusDisplay()),
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _taskStatusDisplay(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: TaskStatus.themedColors(Theme.of(context).colorScheme)[
                              _taskStatusDisplay()]
                          ?.fg ??
                      _getStatusChipColor(_taskStatusDisplay()),
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
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            // 將分隔線下方的間距改為 Action Bar 的內距（paddingTop）
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: Row(
              children: _buildActionButtonsByStatus()
                  .map((e) => Expanded(
                        child: IconTheme(
                          data: IconThemeData(
                            color:
                                Theme.of(context).appBarTheme.foregroundColor ??
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
                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.disabled))
                      return fg.withOpacity(0.5);
                    return fg;
                  }),
                  overlayColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed))
                      return fg.withOpacity(0.12);
                    if (states.contains(MaterialState.hovered))
                      return fg.withOpacity(0.08);
                    if (states.contains(MaterialState.focused))
                      return fg.withOpacity(0.10);
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
            child: Container(
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          onPressed: isInputDisabled ? null : _toggleActionBar,
                        ),
                        IconButton(
                          tooltip: 'Photo',
                          icon: const Icon(Icons.photo_outlined),
                          onPressed: isInputDisabled ? null : _pickAndSendPhoto,
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
                          contentPadding:
                              EdgeInsets.only(left: 8, top: 12, bottom: 12),
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
          );
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
                  TaskStatus.statusString['in_progress']!,
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
                  TaskStatus.statusString['pending_confirmation_tasker']!,
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
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    switch (displayStatus) {
      case 'Open':
        return Colors.blue[800]!;
      case 'In Progress':
        return Colors.orange[800]!;
      case 'In Progress (Tasker)':
        return Colors.orange[800]!;
      case 'Applying (Tasker)':
        return Colors.blue[800]!;
      case 'Rejected (Tasker)':
        return Colors.grey[800]!;
      case 'Dispute':
        return Colors.brown[800]!;
      case 'Pending Confirmation':
        return Colors.purple[800]!;
      case 'Pending Confirmation (Tasker)':
        return Colors.purple[800]!;
      case 'Completed':
        return Colors.grey[800]!;
      case 'Completed (Tasker)':
        return Colors.grey[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    switch (displayStatus) {
      case 'Open':
        return Colors.blue[50]!;
      case 'In Progress':
        return Colors.orange[50]!;
      case 'In Progress (Tasker)':
        return Colors.orange[50]!;
      case 'Applying (Tasker)':
        return Colors.blue[50]!;
      case 'Rejected (Tasker)':
        return Colors.grey[200]!;
      case 'Dispute':
        return Colors.brown[50]!;
      case 'Pending Confirmation':
        return Colors.purple[50]!;
      case 'Pending Confirmation (Tasker)':
        return Colors.purple[50]!;
      case 'Completed':
        return Colors.grey[200]!;
      case 'Completed (Tasker)':
        return Colors.grey[200]!;
      default:
        return Colors.grey[200]!;
    }
  }
}

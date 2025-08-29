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
import 'package:here4help/task/models/resume_data.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/services/rating_service.dart';
import 'package:here4help/chat/services/socket_service.dart';

import 'package:photo_view/photo_view.dart';
import 'package:here4help/utils/path_mapper.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'dart:ui';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/widgets/dispute_dialog.dart';
import 'package:here4help/chat/widgets/disagree_completion_dialog.dart';
import 'package:here4help/chat/widgets/confirm_completion_dialog.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:here4help/chat/models/image_tray_item.dart';
import 'package:here4help/chat/models/pending_image_message.dart';
import 'package:here4help/chat/services/image_upload_manager.dart';
import 'package:here4help/chat/services/image_processing_service.dart';
import 'package:here4help/chat/widgets/image_tray.dart';
import 'package:here4help/chat/widgets/pending_image_message.dart';
import 'package:here4help/utils/error_message_mapper.dart';

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
  int? _myLastReadMessageId; // 我的最後已讀訊息 ID
  bool _showScrollToBottomButton = false; // 是否顯示滾動到底部按鈕
  bool _isInitialLoad = true; // 是否為初次載入
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

  // 圖片托盤相關
  ImageUploadManager? _imageUploadManager;
  final ImageProcessingService _imageProcessingService =
      ImageProcessingService();
  List<ImageTrayItem> _imageTrayItems = [];

  // 暫存圖片訊息相關
  final List<PendingImageMessage> _pendingImageMessages = [];

  // 對方頭像與名稱（相對於當前使用者的聊天室對象）快取
  String? _opponentAvatarUrlCached;
  String _opponentNameCached = 'U';
  double _opponentAvgRating = 0;
  int _opponentReviewsCount = 0;

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
    debugPrint('🔍 [ChatDetailPage] _getOpponentUserId() 開始');
    debugPrint('  - _currentUserId: $_currentUserId');
    debugPrint('  - _chatData: ${_chatData != null ? 'not null' : 'null'}');
    debugPrint('  - _room: ${_room != null ? 'not null' : 'null'}');

    try {
      final room = _room;
      if (room == null) {
        debugPrint('❌ [ChatDetailPage] _room 為 null');
        return null;
      }

      debugPrint('  - room 內容: ${room.keys.toList()}');
      debugPrint('  - room 原始數據: $room');

      final creatorId = room['creator_id'] ?? room['creatorId'];
      final participantId = room['participant_id'] ?? room['participantId'];

      debugPrint(
          '  - creatorId (原始): $creatorId (類型: ${creatorId.runtimeType})');
      debugPrint(
          '  - participantId (原始): $participantId (類型: ${participantId.runtimeType})');

      if (_currentUserId == null) {
        debugPrint('❌ [ChatDetailPage] _currentUserId 為 null');
        return null;
      }

      final int? creator =
          (creatorId is int) ? creatorId : int.tryParse('$creatorId');
      final int? participant = (participantId is int)
          ? participantId
          : int.tryParse('$participantId');

      debugPrint('  - creator (解析後): $creator');
      debugPrint('  - participant (解析後): $participant');
      debugPrint('  - currentUserId: $_currentUserId');

      if (creator == _currentUserId) {
        debugPrint(
            '✅ [ChatDetailPage] 當前用戶是 creator，返回 participant: $participant');
        return participant;
      }
      if (participant == _currentUserId) {
        debugPrint('✅ [ChatDetailPage] 當前用戶是 participant，返回 creator: $creator');
        return creator;
      }

      // 如果都不匹配，返回 participant 或 creator
      final result = participant ?? creator;
      debugPrint('⚠️ [ChatDetailPage] 用戶角色不匹配，返回預設值: $result');
      return result;
    } catch (e) {
      debugPrint('❌ [ChatDetailPage] _getOpponentUserId error: $e');
      debugPrint('  - 錯誤堆疊: ${e.toString()}');
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
    return (_opponentAvgRating, _opponentReviewsCount);
  }

  // 移除未使用的 _getRoomCreatorId 以消除警告

  // 移除未使用的 _getRoomParticipantId 以消除 linter 警告

  // 移除未使用的 _amCreatorInThisRoom 以消除警告

  /// 取得對方頭像 URL
  String? _getOpponentAvatarUrl() {
    try {
      final chatPartnerInfo = _chatPartnerInfo;
      if (chatPartnerInfo != null) {
        final raw = chatPartnerInfo['avatar_url'] ?? chatPartnerInfo['avatar'];
        if (raw is String && raw.trim().isNotEmpty) return raw;
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

  /// 滾動到未讀訊息分隔線位置（螢幕中央）
  void _scrollToUnreadSeparator({bool delayed = false}) {
    void run() {
      if (!_listController.hasClients) return;

      // 找到未讀分隔線的索引
      final unreadSeparatorIndex = _findUnreadSeparatorIndex();
      if (unreadSeparatorIndex == -1) {
        // 如果沒有未讀訊息，直接滾動到底部
        _scrollToBottom();
        return;
      }

      // 計算分隔線的大概位置（每個 item 平均高度約 80px）
      const estimatedItemHeight = 80.0;
      final targetOffset = unreadSeparatorIndex * estimatedItemHeight;

      // 獲取螢幕高度的一半，讓分隔線顯示在中央
      final screenHeight = MediaQuery.of(context).size.height;
      final halfScreenHeight = screenHeight / 2;

      final finalOffset = (targetOffset - halfScreenHeight)
          .clamp(0.0, _listController.position.maxScrollExtent);

      _listController.animateTo(
        finalOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    if (delayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    } else {
      run();
    }
  }

  /// 找到未讀分隔線在 ListView 中的索引
  int _findUnreadSeparatorIndex() {
    if (_myLastReadMessageId == null || _chatMessages.isEmpty) return -1;

    // 找到第一個對方發送的未讀訊息的位置
    for (int i = 0; i < _chatMessages.length; i++) {
      final message = _chatMessages[i];
      final messageId = message['id'];
      final msgId =
          (messageId is int) ? messageId : int.tryParse('$messageId') ?? 0;

      // 只有對方發送的訊息才算未讀
      final isFromMe =
          _currentUserId != null && message['from_user_id'] == _currentUserId;

      if (msgId > (_myLastReadMessageId ?? 0) && !isFromMe) {
        // 返回分隔線的索引（在第一個未讀訊息之前）
        debugPrint(
            '🔍 找到未讀分隔線位置: index=$i, messageId=$msgId, isFromMe=$isFromMe');
        return i;
      }
    }

    return -1; // 沒有未讀訊息
  }

  /// 檢查是否有未讀訊息
  bool _hasUnreadMessages() {
    if (_myLastReadMessageId == null || _chatMessages.isEmpty) return false;

    // 檢查是否有訊息 ID 大於我的最後已讀 ID，且不是我發送的訊息
    return _chatMessages.any((message) {
      final messageId = message['id'];
      final msgId =
          (messageId is int) ? messageId : int.tryParse('$messageId') ?? 0;

      // 只有對方發送的訊息才算未讀
      final isFromMe =
          _currentUserId != null && message['from_user_id'] == _currentUserId;

      return msgId > (_myLastReadMessageId ?? 0) && !isFromMe;
    });
  }

  /// 建立未讀分隔線 UI
  Widget _buildUnreadSeparator() {
    debugPrint('🔍 渲染未讀分隔線 UI');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.orange.shade300,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Text(
              'Unread Messages Below',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.orange.shade300,
            ),
          ),
        ],
      ),
    );
  }

  /// 滾動到底部並標記所有訊息為已讀
  Future<void> _scrollToBottomAndMarkAllRead() async {
    // 滾動到底部
    _scrollToBottom();

    // 標記所有訊息為已讀
    if (_chatMessages.isNotEmpty && _currentRoomId != null) {
      try {
        final lastMessage = _chatMessages.last;
        final lastMessageId = lastMessage['id'];
        final msgId = (lastMessageId is int)
            ? lastMessageId
            : int.tryParse('$lastMessageId') ?? 0;

        if (msgId > 0) {
          // 調用標記已讀 API
          await NotificationCenter()
              .service
              .markRoomRead(roomId: _currentRoomId!, upToMessageId: '$msgId');

          // 更新本地狀態
          setState(() {
            _myLastReadMessageId = msgId;
            _showScrollToBottomButton = false;
          });

          debugPrint('✅ 標記所有訊息為已讀，最後訊息 ID: $msgId');
        }
      } catch (e) {
        debugPrint('❌ 標記已讀失敗: $e');
      }
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
    debugPrint('🔍 ChatDetailPage.initState() 開始');
    debugPrint('🔍 widget.data: ${widget.data}');

    // 如果有 widget.data，先設置初始狀態
    if (widget.data != null) {
      setState(() {
        // 設置初始的 _chatData，讓 AppBar 能立即顯示
        _chatData = widget.data;
      });
      debugPrint('✅ 設置初始 _chatData: ${widget.data}');
    }

    _initializeChat(); // 先初始化聊天室，再載入用戶ID

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
            _showScrollToBottomButton = false; // 在底部時隱藏按鈕
          } else {
            // 不在底部且有未讀訊息時顯示按鈕
            if (_hasUnreadMessages()) {
              _showScrollToBottomButton = true;
            }
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
    debugPrint('🔍 [ChatDetailPage] _loadCurrentUserId() 開始');
    debugPrint('  - 當前 _currentUserId: $_currentUserId');

    try {
      // 優先從 UserService 獲取當前用戶
      debugPrint('🔍 [ChatDetailPage] 嘗試從 UserService 獲取用戶');
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.ensureUserLoaded();
      debugPrint('  - UserService 載入完成');

      if (userService.currentUser != null) {
        debugPrint('✅ [ChatDetailPage] UserService 有當前用戶');
        debugPrint('  - 用戶ID: ${userService.currentUser!.id}');
        debugPrint('  - 用戶名稱: ${userService.currentUser!.name}');
        debugPrint('  - 用戶頭像: ${userService.currentUser!.avatar_url}');

        if (mounted) {
          setState(() {
            _currentUserId = userService.currentUser!.id;
          });
          debugPrint(
              '✅ [ChatDetailPage] 從 UserService 載入當前用戶 ID: $_currentUserId');

          // 重新解析對方身份
          _resolveOpponentIdentity();
        }
        return;
      } else {
        debugPrint(
            '⚠️ [ChatDetailPage] UserService 沒有當前用戶，嘗試 SharedPreferences');
      }

      // 備用方案：從 SharedPreferences 讀取
      debugPrint('🔍 [ChatDetailPage] 嘗試從 SharedPreferences 讀取');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final currentAvatar = prefs.getString('user_avatarUrl') ?? '';

      debugPrint('  - SharedPreferences user_id: $userId');
      debugPrint(
          '  - SharedPreferences user_avatarUrl: ${currentAvatar.isNotEmpty ? currentAvatar : 'empty'}');

      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
        debugPrint('⚠️ [ChatDetailPage] 從 SharedPreferences 載入用戶 ID: $userId');

        // 重新解析對方身份
        _resolveOpponentIdentity();
      }
    } catch (e) {
      debugPrint('❌ [ChatDetailPage] 載入當前用戶 ID 失敗: $e');
      debugPrint('  - 錯誤類型: ${e.runtimeType}');
      debugPrint('  - 錯誤堆疊: ${e.toString()}');
    }
  }

  // 已有下方 dispose，避免重覆定義（保留於 520 行段落）

  void _toggleActionBar() {
    setState(() {
      _showActionBar = !_showActionBar;
    });
  }

  /// 初始化圖片上傳管理器
  void _initImageUploadManager() {
    if (_currentRoomId == null) return;

    _imageUploadManager?.dispose();
    _imageUploadManager = ImageUploadManager(_currentRoomId!);

    // 設置回調
    _imageUploadManager!.onItemsUpdated = (items) {
      if (mounted) {
        setState(() {
          _imageTrayItems = items;
        });
      }
    };

    _imageUploadManager!.onItemError = (item, error) {
      if (mounted) {
        // 更新暫存訊息為失敗狀態
        setState(() {
          final index = _pendingImageMessages
              .indexWhere((msg) => msg.localId == item.localId);
          if (index != -1) {
            _pendingImageMessages[index] =
                _pendingImageMessages[index].copyWith(
              status: PendingImageStatus.failed,
              errorMessage: error,
            );
          }
        });

        // 根據錯誤類型顯示不同的提示
        final String errorMessage = getImageUploadErrorMessage(error);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '重試',
              textColor: Colors.white,
              onPressed: () => _retryImageUpload(item.localId),
            ),
          ),
        );
      }
    };

    _imageUploadManager!.onItemSuccess = (item) {
      debugPrint('✅ 圖片上傳成功: ${item.localId}');
      // 圖片上傳成功後，移除暫存訊息並重新載入聊天訊息
      if (mounted) {
        setState(() {
          _pendingImageMessages
              .removeWhere((msg) => msg.localId == item.localId);
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadChatMessagesFromDatabase();
        });
      }
    };

    _imageUploadManager!.onProgressUpdate = (localId, progress) {
      if (mounted) {
        setState(() {
          final index =
              _pendingImageMessages.indexWhere((msg) => msg.localId == localId);
          if (index != -1) {
            _pendingImageMessages[index] =
                _pendingImageMessages[index].copyWith(
              uploadProgress: progress,
            );
          }
        });
      }
    };
  }

  /// 選擇並添加圖片到托盤
  Future<void> _pickAndAddImages() async {
    try {
      if (_imageUploadManager == null) {
        throw Exception('圖片管理器未初始化');
      }

      final items = await _imageProcessingService.pickMultipleImages(
        maxImages: 9 - _imageTrayItems.length,
      );

      if (items.isNotEmpty) {
        final files = items.map((item) => item.originalFile).toList();
        await _imageUploadManager!.addImages(files);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = getImageUploadErrorMessage(e.toString());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 從托盤移除圖片
  void _removeImageFromTray(String localId) {
    _imageUploadManager?.removeImage(localId);
  }

  /// 重試圖片上傳
  Future<void> _retryImageUpload(String localId) async {
    try {
      // 更新暫存訊息為上傳中狀態
      setState(() {
        final index =
            _pendingImageMessages.indexWhere((msg) => msg.localId == localId);
        if (index != -1) {
          _pendingImageMessages[index] = _pendingImageMessages[index].copyWith(
            status: PendingImageStatus.uploading,
            uploadProgress: 0.0,
            errorMessage: null,
          );
        }
      });

      final item = _imageTrayItems.firstWhere(
        (item) => item.localId == localId,
        orElse: () => throw Exception('找不到指定的圖片'),
      );

      await _imageUploadManager?.retryUpload(item);
    } catch (e) {
      debugPrint('❌ 重試上傳失敗: $e');
      if (mounted) {
        // 更新暫存訊息為失敗狀態
        setState(() {
          final index =
              _pendingImageMessages.indexWhere((msg) => msg.localId == localId);
          if (index != -1) {
            _pendingImageMessages[index] =
                _pendingImageMessages[index].copyWith(
              status: PendingImageStatus.failed,
              errorMessage: e.toString(),
            );
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getImageUploadErrorMessage(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 刪除暫存圖片訊息
  void _deletePendingImageMessage(String localId) {
    setState(() {
      _pendingImageMessages.removeWhere((msg) => msg.localId == localId);
    });
  }

  /// 發送訊息（包含圖片和文字的順序處理）
  Future<void> _sendMessageWithImages() async {
    final text = _controller.text.trim();

    // 先清空輸入框
    _controller.clear();

    try {
      // 1. 先創建暫存圖片訊息
      if (_imageTrayItems.isNotEmpty) {
        setState(() {
          for (final item in _imageTrayItems) {
            final pendingMessage = PendingImageMessage.fromImageTrayItem(item);
            _pendingImageMessages.add(pendingMessage);
          }
        });

        // 開始批量上傳
        final uploadedMessageIds =
            await _imageUploadManager!.startBatchUpload();
        debugPrint('✅ 批量上傳完成，訊息 IDs: $uploadedMessageIds');

        // 更新我的最後已讀訊息 ID（我發送的圖片訊息自動標記為已讀）
        if (uploadedMessageIds.isNotEmpty) {
          final lastUploadedId = uploadedMessageIds.last;
          final msgId = int.tryParse(lastUploadedId) ?? 0;
          if (msgId > 0 && msgId > (_myLastReadMessageId ?? 0)) {
            setState(() {
              _myLastReadMessageId = msgId;
            });
            debugPrint('✅ 更新我的最後已讀訊息 ID (圖片): $_myLastReadMessageId');
          }
        }

        // 清空托盤
        _imageUploadManager!.clearAll();

        // 重新載入聊天訊息以顯示新上傳的圖片
        if (mounted) {
          await _loadChatMessagesFromDatabase();
        }
      }

      // 2. 最後發送文字訊息（如果有）
      if (text.isNotEmpty) {
        await _sendMessage(textOverride: text);
      }
    } catch (e) {
      debugPrint('❌ 發送訊息失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('發送失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 已移除 _pickAndSendPhoto - 使用新的圖片上傳邏輯

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

      // 驗證返回的數據
      if (chatData.isEmpty) {
        debugPrint('❌ ChatService.getChatDetailData 返回空數據');
        setState(() {
          _hasError = true;
          _errorMessage = '無法載入聊天室數據，請稍後重試';
        });
        return;
      }

      debugPrint('✅ 成功獲取聊天室數據: ${chatData.keys}');

      if (mounted) {
        setState(() {
          // 更新聊天室數據
          _chatData = chatData;
          _userRole = chatData['user_role'] ?? 'participant';
          _currentRoomId = roomId;
        });

        // 初始化圖片上傳管理器
        _initImageUploadManager();

        // 提前嘗試加入房間（即便尚未連上 socket，會先排入佇列）
        try {
          _socketService.joinRoom(roomId);
        } catch (_) {}

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

        // 載入當前用戶ID
        await _loadCurrentUserId();

        // 設置 Socket.IO
        await _setupSocket();

        // 解析對方身份（在載入用戶ID後）
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

      // 加入當前聊天室（保險：立即與延時重試）
      if (_currentRoomId != null) {
        final rid = _currentRoomId!;
        _socketService.joinRoom(rid);
        _socketService.markRoomAsRead(rid);
        // 每次建立/切換聊天室時，解析一次對方身份與頭像
        _resolveOpponentIdentity();
        // 延時重試一次（若初次連線仍在建立中）
        Future.delayed(const Duration(milliseconds: 400), () {
          _socketService.joinRoom(rid);
          _socketService.markRoomAsRead(rid);
        });
        // 再延時一次 1 秒做最終保險
        Future.delayed(const Duration(seconds: 1), () {
          _socketService.joinRoom(rid);
          _socketService.markRoomAsRead(rid);
        });
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

      // 詳細除錯資訊
      debugPrint('🔍 解析對方身份 - 當前用戶ID: $_currentUserId');
      debugPrint('🔍 聊天室資料: $_room');
      debugPrint('🔍 聊天夥伴資訊: $_chatPartnerInfo');

      final name = _getOpponentDisplayName().trim();
      final url = _getOpponentAvatarUrl();
      final oppId = _getOpponentUserId();

      debugPrint('🔍 解析結果 - 對方ID: $oppId, 姓名: $name, 頭像URL: $url');

      setState(() {
        _opponentNameCached = name.isNotEmpty ? name : 'U';
        _opponentAvatarUrlCached =
            (url != null && url.trim().isNotEmpty) ? url : null;
      });
      // 另外請求對方評分資訊
      if (oppId != null) {
        RatingService.getUserRatingStats(userId: oppId).then((stats) {
          if (!mounted || stats == null) return;
          setState(() {
            _opponentAvgRating = stats.avgRating;
            _opponentReviewsCount = stats.totalReviews;
          });
        }).catchError((_) {});
      }
      debugPrint(
          '🧩 Opponent resolved: id=${oppId ?? 'null'}, name=$_opponentNameCached, avatar=${_opponentAvatarUrlCached ?? 'null'}');
    } catch (e) {
      debugPrint('❌ 解析對方身份失敗: $e');
    }
  }

  /// 處理收到的即時訊息
  void _onMessageReceived(Map<String, dynamic> messageData) {
    debugPrint('📨 Received real-time message: $messageData');
    debugPrint('🔍 Current room ID: $_currentRoomId');
    debugPrint('🔍 Current user ID: $_currentUserId');

    // 檢查是否為當前聊天室的訊息
    final roomId = messageData['roomId']?.toString();
    final fromUserId = messageData['fromUserId'];

    debugPrint('🔍 Message room ID: $roomId');
    debugPrint('🔍 Message from user ID: $fromUserId');
    debugPrint('🔍 Room match: ${roomId == _currentRoomId}');

    if (roomId == _currentRoomId) {
      // 不是自己發的且不在底部時，顯示新訊息提示
      final isFromMe = _currentUserId != null &&
          (fromUserId == _currentUserId || '$fromUserId' == '$_currentUserId');

      debugPrint('🔍 Is message from me: $isFromMe');
      debugPrint('🔍 Is at bottom: $_isAtBottom');

      if (!isFromMe && !_isAtBottom) {
        setState(() {
          _unseenCount += 1;
          _showNewMsgBanner = true;
        });
        debugPrint('🔔 Added unseen message banner');
      }

      debugPrint('🔄 Reloading messages from database...');
      // 添加短暫延遲確保資料庫已更新
      Future.delayed(const Duration(milliseconds: 300), () {
        // 強制從資料庫重新載入最新訊息（不使用快取）
        _loadChatMessagesFromDatabase();
      });
    } else {
      debugPrint('⚠️ Message not for current room, ignoring');
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

      // 讀取我的最後已讀訊息 ID
      _myLastReadMessageId = (result['my_last_read_message_id'] is int)
          ? result['my_last_read_message_id']
          : int.tryParse('${result['my_last_read_message_id']}') ?? 0;

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
        // 只有在初次載入時才自動滾動到未讀位置
        if (_isInitialLoad) {
          // 根據是否有未讀訊息決定滾動位置
          if (_hasUnreadMessages()) {
            _scrollToUnreadSeparator(delayed: true);
            setState(() {
              _showScrollToBottomButton = true;
            });
          } else {
            _scrollToBottom(delayed: true);
          }
          _isInitialLoad = false; // 標記為非初次載入
        } else if (_isAtBottom) {
          // 非初次載入且用戶在底部時才滾動
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

  /// 強制從資料庫重新載入聊天訊息（不使用快取）
  Future<void> _loadChatMessagesFromDatabase() async {
    if (_isLoadingMessages) return;

    try {
      setState(() {
        _isLoadingMessages = true;
      });

      if (_currentRoomId == null || _currentRoomId!.isEmpty) {
        debugPrint('❌ 無法取得 roomId');
        return;
      }

      debugPrint('🔍 強制從資料庫載入最新聊天訊息，roomId: $_currentRoomId');

      // 直接從 API 獲取最新訊息，不使用快取
      final result = await ChatService().getMessages(roomId: _currentRoomId!);
      final messages = result['messages'] as List<dynamic>? ?? [];
      // 讀取對方最後已讀訊息 ID 供渲染使用
      resultOpponentLastReadId =
          (result['opponent_last_read_message_id'] is int)
              ? result['opponent_last_read_message_id']
              : int.tryParse('${result['opponent_last_read_message_id']}') ?? 0;

      // 讀取我的最後已讀訊息 ID
      _myLastReadMessageId = (result['my_last_read_message_id'] is int)
          ? result['my_last_read_message_id']
          : int.tryParse('${result['my_last_read_message_id']}') ?? 0;

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
        // Socket 訊息更新時不自動滾動，保持用戶當前位置
        // 只更新滾動按鈕的顯示狀態
        if (_hasUnreadMessages() && !_isAtBottom) {
          setState(() {
            _showScrollToBottomButton = true;
          });
        } else if (_isAtBottom) {
          setState(() {
            _showScrollToBottomButton = false;
          });
        }
      }

      debugPrint('✅ 強制載入 ${_chatMessages.length} 條最新聊天訊息');
    } catch (e) {
      debugPrint('❌ 強制載入聊天訊息失敗: $e');
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

  // 已移除 _getCurrentUserInfo - 使用 UserService 替代

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
  Future<void> _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _controller.text.trim();
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

      // 只在沒有 textOverride 時才清空輸入框
      if (textOverride == null) {
        _controller.clear();
      }

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

      // 透過 Socket 立即回寫泡泡（讓對方即時看到）
      try {
        _socketService.sendMessage(
          roomId: _currentRoomId!,
          text: text,
          messageId: pendingMessage['id'].toString(),
        );
      } catch (_) {}

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

          // 添加真實訊息（ChatService 已經返回 data['data']，直接使用）
          final realMessage = {
            'id': result['message_id'],
            'room_id': result['room_id'],
            'from_user_id': result['from_user_id'] ?? _currentUserId,
            'message': result['message'],
            'content': result['content'] ?? result['message'], // 兼容性
            'kind': result['kind'] ?? 'text', // 支援 kind 欄位
            'created_at': DateTime.now().toIso8601String(),
          };
          _chatMessages.add(realMessage);

          // 更新我的最後已讀訊息 ID（我發送的訊息自動標記為已讀）
          final messageId = result['message_id'];
          if (messageId != null) {
            final msgId = (messageId is int)
                ? messageId
                : int.tryParse('$messageId') ?? 0;
            if (msgId > 0) {
              _myLastReadMessageId = msgId;
              debugPrint('✅ 更新我的最後已讀訊息 ID: $_myLastReadMessageId');
            }
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

    // 清理圖片上傳管理器
    _imageUploadManager?.dispose();

    // 移除狀態 Bar 相關清理
    super.dispose();
  }

  // 已移除 _getApplicationData - 使用聚合 API 數據

  /// 顯示新的結構化 Resume 對話框
  void _showResumeDialog(ResumeData resumeData) {
    final (avgRating, reviewsCount) = _getOpponentRating();

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

              // 上半部：應徵者資訊
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: _opponentAvatarUrlCached != null
                        ? ImageHelper.getAvatarImage(_opponentAvatarUrlCached!)
                        : null,
                    backgroundColor: _getAvatarColor(_opponentNameCached),
                    child: _opponentAvatarUrlCached == null
                        ? Text(
                            _getInitials(_opponentNameCached),
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
                          _opponentNameCached,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingBarIndicator(
                              rating: avgRating,
                              itemBuilder: (context, index) => const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              itemCount: 5,
                              itemSize: 16.0,
                              direction: Axis.horizontal,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${avgRating > 0 ? avgRating.toStringAsFixed(1) : '0.0'} ($reviewsCount reviews)',
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
              const Divider(),

              // 下半部：問題回覆列表
              Expanded(
                child: ListView(
                  children: [
                    // Self Introduction
                    if (resumeData.applyIntroduction.trim().isNotEmpty)
                      _buildResumeItem(
                        'Self Introduction',
                        resumeData.applyIntroduction,
                      ),

                    // Application Questions & Answers
                    ...resumeData.applyResponses
                        .map((response) => _buildResumeItem(
                              response.applyQuestion,
                              response.applyReply,
                            )),
                  ],
                ),
              ),

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

  /// 建立 Resume 項目組件
  Widget _buildResumeItem(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 顯示應徵者履歷對話框（舊版，向後兼容）
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
                            RatingBarIndicator(
                              rating: averageRating.toDouble(),
                              itemBuilder: (context, index) => const Icon(
                                Icons.star,
                                color: Colors.amber,
                              ),
                              itemCount: 5,
                              itemSize: 16.0,
                              direction: Axis.horizontal,
                            ),
                            const SizedBox(width: 8),
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

    // 計算未讀分隔線位置
    final unreadSeparatorIndex = _findUnreadSeparatorIndex();
    final hasUnreadSeparator = unreadSeparatorIndex != -1;

    // 使用從資料庫載入的訊息列表
    int totalItemCount = (hasViewResumeMessage ? 1 : 0) +
        _chatMessages.length +
        (_pendingMessages.length) +
        _pendingImageMessages.length + // 加入暫存圖片訊息
        (hasUnreadSeparator ? 1 : 0); // 加入未讀分隔線

    debugPrint(
        '🔍 Total messages: $totalItemCount (hasViewResume: ${hasViewResumeMessage ? 1 : 0}, chatMessages: ${_chatMessages.length}, pendingMessages: ${_pendingMessages.length}, pendingImageMessages: ${_pendingImageMessages.length}, unreadSeparator: ${hasUnreadSeparator ? 1 : 0})');
    debugPrint(
        '🔍 未讀分隔線調試: _myLastReadMessageId=$_myLastReadMessageId, _currentUserId=$_currentUserId');
    debugPrint(
        '🔍 未讀分隔線調試: unreadSeparatorIndex=$unreadSeparatorIndex, hasUnreadSeparator=$hasUnreadSeparator');

    // 已移除 buildQuestionReplyBubble - 使用 _buildViewResumeBubble 替代

    // 已移除 buildOpponentBubble - 使用 _buildTextMessage 替代

    // 已移除 buildMyMessageBubble - 使用 _buildTextMessage 替代

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
                    // 使用統一的訊息渲染邏輯
                    return _buildMessageItem(_chatMessages[0]);
                  }

                  int adjustedIndex = index - (hasViewResumeMessage ? 1 : 0);

                  // 檢查是否為未讀分隔線位置
                  if (hasUnreadSeparator &&
                      adjustedIndex == unreadSeparatorIndex) {
                    return _buildUnreadSeparator();
                  }

                  // 如果有未讀分隔線且當前索引在分隔線之後，需要調整索引
                  if (hasUnreadSeparator &&
                      adjustedIndex > unreadSeparatorIndex) {
                    adjustedIndex -= 1;
                  }

                  // 使用從資料庫載入的訊息列表
                  if (adjustedIndex < _chatMessages.length) {
                    final messageData = _chatMessages[adjustedIndex];

                    // 添加除錯資訊
                    debugPrint(
                        '🔍 [Chat Detail] 訊息資料: messageData=$messageData');
                    debugPrint(
                        '🔍 [Chat Detail] 訊息來源: messageFromUserId=${messageData['from_user_id']}, currentUserId=$_currentUserId');

                    // 檢查是否為我發送的訊息
                    final isFromMe = _currentUserId != null &&
                        messageData['from_user_id'] == _currentUserId;
                    debugPrint('🔍 [Chat Detail] 是否為我的訊息: $isFromMe');

                    // 使用新的統一訊息渲染方法
                    return _buildMessageItem(messageData);
                  }

                  // 檢查是否為暫存圖片訊息
                  final pendingImageIndex =
                      adjustedIndex - _chatMessages.length;
                  if (pendingImageIndex >= 0 &&
                      pendingImageIndex < _pendingImageMessages.length) {
                    final pendingMessage =
                        _pendingImageMessages[pendingImageIndex];
                    return PendingImageMessageBubble(
                      message: pendingMessage,
                      isFromMe: true, // 暫存訊息都是自己發送的
                      onRetry: () => _retryImageUpload(pendingMessage.localId),
                      onDelete: () =>
                          _deletePendingImageMessage(pendingMessage.localId),
                    );
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
              // 滾動到底部按鈕
              if (_showScrollToBottomButton)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    onPressed: _scrollToBottomAndMarkAllRead,
                    child: const Icon(Icons.keyboard_arrow_down, size: 20),
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // 圖片托盤
                      if (_imageTrayItems.isNotEmpty) ...[
                        ImageTray(
                          items: _imageTrayItems,
                          onAddImages: _pickAndAddImages,
                          onRemoveImage: _removeImageFromTray,
                          onRetryUpload: _retryImageUpload,
                          isUploading:
                              _imageUploadManager?.isUploading ?? false,
                        ),
                        // 托盤統計信息
                        ImageTrayStats(
                          items: _imageTrayItems,
                          isUploading:
                              _imageUploadManager?.isUploading ?? false,
                        ),
                      ],
                      // 輸入區域
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
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
                                    onPressed: isInputDisabled
                                        ? null
                                        : _toggleActionBar,
                                  ),
                                  IconButton(
                                    tooltip: 'Photo',
                                    icon: const Icon(Icons.photo_outlined),
                                    onPressed: isInputDisabled
                                        ? null
                                        : _pickAndAddImages,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                // 固定高度以與 IconButton (預設 48) 視覺中心對齊
                                height: 48,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                                    if (!isInputDisabled) {
                                      _sendMessageWithImages();
                                    }
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
                                onPressed: isInputDisabled
                                    ? null
                                    : _sendMessageWithImages,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
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
    debugPrint('🔍 [ChatDetailPage] _handleAcceptApplication() 開始');
    debugPrint('  - _task: ${_task != null ? 'not null' : 'null'}');
    debugPrint('  - _chatData: ${_chatData != null ? 'not null' : 'null'}');
    debugPrint('  - _room: ${_room != null ? 'not null' : 'null'}');

    if (_task == null) {
      debugPrint('❌ [ChatDetailPage] _task 為 null，無法處理接受應徵');
      return;
    }

    try {
      debugPrint('🔍 [ChatDetailPage] 開始載入當前用戶ID');

      // 確保當前用戶ID已載入
      if (_currentUserId == null) {
        debugPrint('  - _currentUserId 為 null，開始載入');
        await _loadCurrentUserId();
        debugPrint('  - 載入後 _currentUserId: $_currentUserId');
      } else {
        debugPrint('  - _currentUserId 已存在: $_currentUserId');
      }

      if (_currentUserId == null) {
        debugPrint('❌ [ChatDetailPage] 載入後仍無法獲取當前用戶ID');
        throw Exception('Unable to get current user ID');
      }

      // 檢查聊天室數據是否已載入
      debugPrint('🔍 [ChatDetailPage] 檢查聊天室數據');
      debugPrint('  - _chatData: ${_chatData != null ? 'not null' : 'null'}');
      if (_chatData != null) {
        debugPrint('  - _chatData 內容: ${_chatData!.keys.toList()}');
      }

      if (_chatData == null || _chatData!.isEmpty) {
        debugPrint('❌ [ChatDetailPage] _chatData 為空，無法獲取對手用戶ID');
        throw Exception('Chat data not loaded. Please refresh the page.');
      }

      // 獲取對手用戶ID（應徵者）
      debugPrint('🔍 [ChatDetailPage] 開始獲取對手用戶ID');
      final opponentId = _getOpponentUserId();
      debugPrint('  - 獲取到的 opponentId: $opponentId');

      if (opponentId == null) {
        debugPrint('❌ [ChatDetailPage] 無法獲取對手用戶ID');
        debugPrint('  - _room: $_room');
        debugPrint('  - _chatData: $_chatData');
        throw Exception(
            'Unable to get opponent user ID. Please check chat room data.');
      }

      debugPrint(
          '✅ 準備接受應徵 - Task: ${_task!['id']}, User: $opponentId, Poster: $_currentUserId');

      // 呼叫新的 Application Accept API
      final result = await TaskService().acceptApplication(
        taskId: _task!['id'].toString(),
        userId: opponentId.toString(),
        posterId: _currentUserId.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Congratulations! You’ve been selected as the tasker for this task. Let’s get started!'),
          ),
        );
      }

      // 關閉其他申請聊天室
      GlobalChatRoom().removeRoomsByTaskIdExcept(
        _task!['id'].toString(),
        _currentRoomId ?? '',
      );

      // 刷新頁面資料
      await _initializeChat();

      // 調試：檢查任務狀態是否已更新
      debugPrint('🔍 [Accept] 刷新後任務狀態檢查:');
      debugPrint('  - _chatData: ${_chatData != null ? 'not null' : 'null'}');
      if (_chatData != null && _chatData!['task'] != null) {
        final task = _chatData!['task'];
        debugPrint('  - task status code: ${task['status']?['code']}');
        debugPrint(
            '  - task status display: ${task['status']?['display_name']}');
        debugPrint('  - task participant_id: ${task['participant_id']}');
      }

      // 強制更新 UI 狀態（多次調用確保更新）
      if (mounted) {
        setState(() {});
        debugPrint('✅ [Accept] setState() 已調用');

        // 延遲再次更新，確保 UI 完全刷新
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
            debugPrint('✅ [Accept] 延遲 setState() 已調用');
          }
        });
      }

      // 通知 Provider 刷新聊天列表數據
      if (mounted && context.mounted) {
        try {
          final provider = context.read<ChatListProvider>();
          if (provider != null) {
            // 根據用戶角色刷新對應的標籤頁
            if (_userRole == 'creator') {
              provider
                  .checkAndTriggerTabLoad(ChatListProvider.TAB_POSTED_TASKS);
              debugPrint('✅ [Accept] 已通知 Provider 刷新 POSTED_TASKS');
            } else {
              provider.checkAndTriggerTabLoad(ChatListProvider.TAB_MY_WORKS);
              debugPrint('✅ [Accept] 已通知 Provider 刷新 MY_WORKS');
            }
            // 強制刷新快取
            provider.forceRefreshCache();
            debugPrint('✅ [Accept] 已強制刷新快取');

            // 新增：通知兩個分頁的分頁控制器刷新（若上層有監聽）
            try {
              // 透過 Provider 的事件機制定義：這裡只呼叫既有方法，
              // 具體分頁元件會在 build 中使用 RefreshIndicator 與 PagingController.refresh()
              // 因此這裡不直接持有 controller，避免相依。
              provider
                  .checkAndTriggerTabLoad(ChatListProvider.TAB_POSTED_TASKS);
              provider.checkAndTriggerTabLoad(ChatListProvider.TAB_MY_WORKS);
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('❌ 通知 Provider 刷新失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Accept application failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept application: $e')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waiting for poster confirmation.')),
        );
      }

      // 刷新頁面資料以更新任務狀態
      await _initializeChat();
    }
  }

  /// 處理確認完成
  Future<void> _handleConfirmCompletion() async {
    if (_task == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmCompletionDialog(
        taskId: _task!['id'].toString(),
        taskTitle: _task!['title']?.toString() ?? 'Unknown Task',
        onPreview: () => TaskService().confirmCompletion(
          taskId: _task!['id'].toString(),
          preview: true,
        ),
        onConfirm: () async {
          await TaskService().confirmCompletion(
            taskId: _task!['id'].toString(),
            preview: false,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task confirmed and paid.')),
            );
          }
        },
      ),
    );

    if (result == true) {
      // 確認完成成功，刷新頁面資料
      await _initializeChat();
    }
  }

  /// 處理不同意完成
  Future<void> _handleDisagreeCompletion() async {
    if (_task == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DisagreeCompletionDialog(
        taskId: _task!['id'].toString(),
        taskTitle: _task!['title']?.toString() ?? 'Unknown Task',
        onDisagreeSubmitted: (String reason) async {
          await TaskService().disagreeCompletion(
            taskId: _task!['id'].toString(),
            reason: reason,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disagree submitted.')),
            );
          }
        },
      ),
    );

    if (result == true) {
      // 駁回完成成功，刷新頁面資料
      await _initializeChat();
    }
  }

  // 已移除 _buildActionButtonsByStatus - 使用 DynamicActionBar 替代

  // 保留方法簽名以避免編譯錯誤，但標記為已棄用
  @deprecated
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
        // 其他（Rejected/Closed/Cancelled）
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
                      onPressed: () => _downloadImage(imageUrl),
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

  /// 下載圖片功能
  Future<void> _downloadImage(String imageUrl) async {
    try {
      // 顯示下載開始的提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('正在下載圖片...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // 這裡可以實作實際的下載邏輯
      // 由於跨平台下載需要額外的權限和套件，這裡先提供基礎框架

      // 模擬下載過程
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text('圖片下載完成'),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下載失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 輔助方法：安全地獲取數據
  Map<String, dynamic>? get _task => _chatData?['task'];
  Map<String, dynamic>? get _room {
    final room = _chatData?['room'] ?? _chatData?['chat_room'];
    // debugPrint(
    //     '🔍 [ChatDetailPage] _room getter - _chatData keys: ${_chatData?.keys.toList()}');
    // debugPrint(
    //     '🔍 [ChatDetailPage] _room getter - room from "room": ${_chatData?['room']}');
    // debugPrint(
    //     '🔍 [ChatDetailPage] _room getter - room from "chat_room": ${_chatData?['chat_room']}');
    // debugPrint('🔍 [ChatDetailPage] _room getter - final result: $room');
    return room;
  }

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

  /// 已移除狀態欄輔助方法 - 使用 DynamicActionBar 替代
  @deprecated
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

  @deprecated
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
    final kind = message['kind'] ?? 'text';

    // 根據 kind 類型決定渲染方式
    switch (kind) {
      case 'resume':
        return _buildResumeBubble(message);
      case 'image':
        return _buildImageBubble(message);
      case 'system':
        return _buildSystemMessage(message);
      case 'text':
      default:
        // 向後兼容：檢查是否為舊的 View Resume 訊息
        if ((message['message'] ?? '').contains('申請已提交') ||
            (message['content'] ?? '').contains('The task has been applied')) {
          return _buildViewResumeBubble(message);
        }

        // 檢查是否為圖片訊息（向後兼容）
        final content = message['content'] ?? message['message'] ?? '';
        final imageUrl = _extractFirstImageUrl(content);

        if (imageUrl != null) {
          return _buildImageMessage(message, imageUrl);
        }

        // 普通文字訊息
        return _buildTextMessage(message);
    }
  }

  // 渲染新的 Resume 氣泡
  Widget _buildResumeBubble(Map<String, dynamic> message) {
    final resumeJsonString = message['content'] ?? message['message'] ?? '{}';
    final resumeData = ResumeData.fromJsonString(resumeJsonString);
    final isFromMe =
        _currentUserId != null && message['from_user_id'] == _currentUserId;

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
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: isFromMe
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顯示摘要內容
                  Text(
                    resumeData.summary,
                    style: TextStyle(
                      color: isFromMe
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // View Resume 按鈕
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _showResumeDialog(resumeData),
                      icon: Icon(
                        Icons.visibility,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        'View Resume',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 我方訊息：不顯示我方頭像
        ],
      ),
    );
  }

  // 渲染舊的 View Resume 氣泡（向後兼容）
  Widget _buildViewResumeBubble(Map<String, dynamic> message) {
    // 提取實際的自我介紹內容（移除 '申請已提交' 標記）
    final fullMessage = message['content'] ?? message['message'] ?? '';
    final actualContent =
        fullMessage.replaceFirst('The task has been applied\n', '').trim();

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
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顯示實際的自我介紹內容
                      if (actualContent.isNotEmpty) ...[
                        Text(
                          actualContent,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // View Resume 按鈕
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _showApplierResumeDialog,
                          icon: Icon(
                            Icons.visibility,
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

  // 渲染新的圖片訊息氣泡（基於 kind='image'）
  Widget _buildImageBubble(Map<String, dynamic> message) {
    final isFromMe =
        _currentUserId != null && message['from_user_id'] == _currentUserId;

    // 優先從 content 獲取圖片 URL（圖片上傳後 URL 存儲在 content 中）
    String finalImageUrl = '';
    final content = message['content'] ?? message['message'] ?? '';

    // 如果是 kind='image' 的訊息，content 就是圖片 URL
    if (message['kind'] == 'image') {
      finalImageUrl = content;
    } else {
      // 否則嘗試從 content 中解析圖片 URL
      finalImageUrl = _extractFirstImageUrl(content) ?? '';
    }

    // 如果還是沒有，嘗試從 media_url 獲取
    if (finalImageUrl.isEmpty) {
      finalImageUrl = message['media_url'] ?? '';
    }

    // 使用 PathMapper 處理圖片 URL
    if (finalImageUrl.isNotEmpty) {
      finalImageUrl = PathMapper.mapDatabasePathToUrl(finalImageUrl);
    }

    if (finalImageUrl.isEmpty) {
      // 如果還是沒有圖片，顯示錯誤訊息
      return _buildTextMessage(message);
    }

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
              constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
              child: GestureDetector(
                onTap: () => _showImagePreview(finalImageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    finalImageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Image failed to load',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 我方訊息：不顯示我方頭像
        ],
      ),
    );
  }

  // 渲染舊的圖片訊息（向後兼容）
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
          // 我方訊息：不顯示我方頭像
        ],
      ),
    );
  }

  // 渲染文字訊息
  Widget _buildTextMessage(Map<String, dynamic> message) {
    final isFromMe =
        _currentUserId != null && message['from_user_id'] == _currentUserId;
    final content = message['content'] ?? message['message'] ?? '';
    final messageTime = message['created_at']?.toString() ?? '';

    if (isFromMe) {
      // 我方訊息：使用原有的樣式和狀態顯示
      final int msgId = (message['id'] is int)
          ? message['id']
          : int.tryParse('${message['id']}') ?? 0;
      final int opponentReadId = (resultOpponentLastReadId ?? 0);
      // 已讀狀態暫時不使用
      // final String status = opponentReadId >= msgId ? 'read' : 'sent';

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
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 14,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(messageTime),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      // 已讀標記：先不做
                      // Icon(
                      //   status == 'read' ? Icons.done_all : Icons.done,
                      //   size: 12,
                      //   color: status == 'read' ? Colors.blue : Colors.grey,
                      // ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 我方頭像 不顯示
            // CircleAvatar(
            //   radius: 16,
            //   backgroundImage: Provider.of<UserService>(context, listen: false)
            //                   .currentUser
            //                   ?.avatar_url !=
            //               null &&
            //           Provider.of<UserService>(context, listen: false)
            //               .currentUser!
            //               .avatar_url
            //               .isNotEmpty
            //       ? ImageHelper.getAvatarImage(
            //           Provider.of<UserService>(context, listen: false)
            //               .currentUser!
            //               .avatar_url)
            //       : null,
            //   backgroundColor: Theme.of(context).colorScheme.primary,
            //   child: Provider.of<UserService>(context, listen: false)
            //                   .currentUser
            //                   ?.avatar_url ==
            //               null ||
            //           Provider.of<UserService>(context, listen: false)
            //               .currentUser!
            //               .avatar_url
            //               .isEmpty
            //       ? Text(
            //           () {
            //             final user =
            //                 Provider.of<UserService>(context, listen: false)
            //                     .currentUser;
            //             final name = user?.name ?? '';
            //             return name.isNotEmpty ? name[0].toUpperCase() : 'U';
            //           }(),
            //           style: const TextStyle(
            //             color: Colors.white,
            //             fontSize: 12,
            //             fontWeight: FontWeight.bold,
            //           ),
            //         )
            //       : null,
            // ),
          ],
        ),
      );
    } else {
      // 對方訊息：使用對方的樣式
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        fontSize: 14,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatMessageTime(messageTime),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

// #region 渲染系統訊息
  Widget _buildSystemMessage(Map<String, dynamic> message) {
    final isFromMe =
        _currentUserId != null && message['from_user_id'] == _currentUserId;
    final content = message['content'] ?? message['message'] ?? '';
    final messageTime = message['created_at']?.toString() ?? '';

    if (isFromMe) {
      // 我方訊息：使用原有的樣式和狀態顯示
      final int msgId = (message['id'] is int)
          ? message['id']
          : int.tryParse('${message['id']}') ?? 0;
      final int opponentReadId = (resultOpponentLastReadId ?? 0);
      // 已讀狀態暫時不使用
      // final String status = opponentReadId >= msgId ? 'read' : 'sent';

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
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                        fontSize: 14,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(messageTime),
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(width: 4),
                      // 已讀標記：先不做
                      // Icon(
                      //   status == 'read' ? Icons.done_all : Icons.done,
                      //   size: 12,
                      //   color: status == 'read' ? Colors.blue : Colors.grey,
                      // ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    } else {
      // 對方訊息：使用對方的樣式
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        fontSize: 14,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatMessageTime(messageTime),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
// #endregion
}

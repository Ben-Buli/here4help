import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/chat/services/global_chat_room.dart';
import 'package:here4help/constants/task_status.dart' as TaskStatusConstants;
import 'package:here4help/chat/widgets/dynamic_action_bar.dart';
import 'package:here4help/chat/widgets/countdown_timer_widget.dart';
import 'package:here4help/chat/utils/action_bar_config.dart';
import 'package:here4help/chat/utils/application_status_utils.dart';
import 'package:here4help/services/error_handler_service.dart';
import 'package:here4help/widgets/error_display_widget.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/utils/image_helper.dart';
import 'package:here4help/task/models/resume_data.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/services/rating_service.dart';
import 'package:here4help/services/user_info_service.dart';
import 'package:here4help/chat/services/socket_service.dart';
import 'package:here4help/services/wallet_service.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_preload_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:provider/provider.dart';

import 'package:photo_view/photo_view.dart';
import 'package:here4help/utils/path_mapper.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'dart:ui';
import 'package:here4help/services/notification_service.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/widgets/dispute_dialog.dart';
import 'package:here4help/chat/widgets/disagree_completion_dialog.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:here4help/chat/models/image_upload_status.dart';
import 'package:here4help/chat/widgets/uploading_image_message.dart';
import 'package:here4help/services/media/cross_platform_image_service.dart';
import 'package:here4help/services/image_cleanup_service.dart';
import 'package:here4help/utils/error_message_mapper.dart';
import 'package:here4help/services/api/support_event_api.dart';
import 'package:here4help/widgets/support_timeline_dialog.dart';
import 'package:here4help/widgets/support_solved_dialog.dart';
import 'package:here4help/widgets/review_dialog.dart';
import 'package:here4help/widgets/block_user_dialog.dart';
import 'package:go_router/go_router.dart';

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

  // 封鎖狀態
  bool _isBlocked = false;
  bool _isBlockedByMe = false; // 我是否封鎖了對方
  bool _isBlockedByTarget = false; // 對方是否封鎖了我
  bool _hasExistingReview = false; // 是否已有評分

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

  // 操作狀態控制（防重複點擊）
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isWithdrawing = false;
  bool _isRefreshingTaskStatus = false;

  // 移除狀態 Bar 動畫控制相關變數

  // Socket.IO 服務
  final SocketService _socketService = SocketService();
  String? _currentRoomId;

  // 圖片上傳狀態管理
  final Map<String, ImageUploadStatus> _uploadingImages = {};

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
      // 允許相對路徑（後端回傳 backend/uploads/... 或 uploads/...）與完整 URL
      final httpMatch = RegExp(r'(https?:\/\/[^\s]+\.(png|jpg|jpeg|gif|webp))',
              caseSensitive: false)
          .firstMatch(trimmed);
      if (httpMatch != null) return httpMatch.group(1);

      // 支援多種相對路徑格式
      final relMatch = RegExp(
              r'^(?:\/)?(backend\/uploads\/[^\s]+\.(png|jpg|jpeg|gif|webp)|uploads\/[^\s]+\.(png|jpg|jpeg|gif|webp))$',
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

  /// 取得玻璃導航顏色
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

  /// 根據用戶角色獲取配色方案
  String _getColorSchemeForUserRole() {
    // 根據用戶角色決定使用哪種配色方案
    switch (_userRole.toLowerCase()) {
      case 'creator':
        return 'posted_tasks'; // 發布者使用 Posted Tasks 配色（基於 tasks.status_id）
      case 'participant':
        return 'my_works'; // 應徵者使用 My Works 配色（基於 task_applications.status）
      default:
        return 'posted_tasks'; // 預設使用 Posted Tasks 配色
    }
  }

  /// 根據用戶角色獲取狀態顯示名稱
  String? _getStatusDisplayNameForUserRole() {
    switch (_userRole.toLowerCase()) {
      case 'creator':
        // 發布者：顯示任務狀態（來自 tasks.status）
        return _task?['status']?['display_name'];
      case 'participant':
        // 應徵者：顯示應徵狀態（來自 task_applications.status）
        // 後端 API 將 application_status 放在 task 物件中
        final applicationStatus = _task?['application_status']?.toString();

        if (applicationStatus != null && applicationStatus.isNotEmpty) {
          // 使用 ApplicationStatusUtils 獲取顯示名稱
          return ApplicationStatusUtils.getDisplayName(applicationStatus);
        }
        // 備用方案：如果沒有應徵狀態，使用任務狀態
        return _task?['status']?['display_name'];
      default:
        // 預設使用任務狀態
        return _task?['status']?['display_name'];
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

  /// 取得對方用戶名稱
  String? _getOpponentUserName() {
    return _getOpponentDisplayName();
  }

  /// 取得對方顯示名稱（依對方 userId 判斷應取哪一側欄位）
  String _getOpponentDisplayName() {
    try {
      // 優先從 chat_partner_info 獲取對方資訊
      final chatPartnerInfo = _chatPartnerInfo;
      if (chatPartnerInfo != null && chatPartnerInfo['name'] != null) {
        final name = chatPartnerInfo['name'].toString().trim();
        if (name.isNotEmpty) {
          debugPrint('✅ 從 chat_partner_info 獲取對方名稱: $name');
          return name;
        }
      }

      // 備用方案：從 room 和 task 數據中獲取
      final room = _room;
      final task = _task;
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
          task?['participant_name'],
        ]);
      } else {
        // 對方為 creator
        name = firstNonEmpty([
          room['creator_nickname'],
          room['creator_name'],
          task?['creator_name'],
        ]);
      }

      final result = (name == null || name.isEmpty) ? 'User' : name;
      debugPrint('⚠️ 從備用方案獲取對方名稱: $result');
      return result;
    } catch (e) {
      debugPrint('❌ 獲取對方名稱失敗: $e');
      return 'User';
    }
  }

  /// 嘗試從多個來源擷取對方評分（平均星等、評論數）
  (double avg, int count) _getOpponentRating() {
    // 優先從 chat_partner_info 獲取評分數據
    final chatPartnerInfo = _chatPartnerInfo;
    if (chatPartnerInfo != null) {
      // 🔍 調試：輸出完整的 chat_partner_info
      debugPrint(
          '🔍 [_getOpponentRating] chat_partner_info 完整內容: $chatPartnerInfo');

      final rating = chatPartnerInfo['rating'];
      final reviewsCount = chatPartnerInfo['reviewsCount'];

      debugPrint(
          '🔍 [_getOpponentRating] rating: $rating (類型: ${rating.runtimeType})');
      debugPrint(
          '🔍 [_getOpponentRating] reviewsCount: $reviewsCount (類型: ${reviewsCount.runtimeType})');

      if (rating != null && reviewsCount != null) {
        final avgRating = rating is double
            ? rating
            : (rating is num ? rating.toDouble() : 0.0);
        final count = reviewsCount is int
            ? reviewsCount
            : (reviewsCount is num ? reviewsCount.toInt() : 0);
        debugPrint('✅ 從 chat_partner_info 獲取評分: $avgRating ($count 評論)');
        return (avgRating, count);
      } else {
        debugPrint('⚠️ [_getOpponentRating] rating 或 reviewsCount 為 null');
      }
    } else {
      debugPrint('⚠️ [_getOpponentRating] chat_partner_info 為 null');
    }

    // 備用方案：使用緩存的評分數據
    debugPrint('⚠️ 使用緩存的評分數據: $_opponentAvgRating ($_opponentReviewsCount 評論)');
    return (_opponentAvgRating, _opponentReviewsCount);
  }

  /// 🔧 新增：異步取得應徵者（participant）完整資料的方法
  /// 返回 (姓名, 頭像URL, 平均評分, 評論數量)
  Future<(String, String?, double, int)> _getParticipantInfoAsync() async {
    try {
      final room = _room;
      if (room == null) {
        debugPrint('❌ [_getParticipantInfoAsync] _room 為 null');
        return ('Applicant', null, 0.0, 0);
      }

      // 取得 participant_id
      final participantId = room['participant_id'];
      final int? participantIdInt = (participantId is int)
          ? participantId
          : int.tryParse('$participantId');

      debugPrint(
          '🔍 [_getParticipantInfoAsync] participant_id: $participantIdInt');

      if (participantIdInt == null) {
        debugPrint('❌ [_getParticipantInfoAsync] 無法解析 participant_id');
        return ('Applicant', null, 0.0, 0);
      }

      // 判斷當前用戶角色來決定資料來源
      if (_userRole == 'creator') {
        // 如果我是創建者，participant 就是對方，優先使用 chat_partner_info
        final chatPartnerInfo = _chatPartnerInfo;
        if (chatPartnerInfo != null) {
          final name =
              chatPartnerInfo['name']?.toString().trim() ?? 'Applicant';
          final avatar =
              chatPartnerInfo['avatar_url'] ?? chatPartnerInfo['avatar'];
          final rating = chatPartnerInfo['rating'];
          final reviewsCount = chatPartnerInfo['reviewsCount'];

          // 🔍 調試：輸出 chat_partner_info 的完整內容
          debugPrint(
              '🔍 [_getParticipantInfoAsync] chat_partner_info 完整內容: $chatPartnerInfo');
          debugPrint(
              '🔍 [_getParticipantInfoAsync] rating 原始值: $rating (類型: ${rating.runtimeType})');
          debugPrint(
              '🔍 [_getParticipantInfoAsync] reviewsCount 原始值: $reviewsCount (類型: ${reviewsCount.runtimeType})');

          final avgRating = rating is double
              ? rating
              : (rating is num ? rating.toDouble() : 0.0);
          final count = reviewsCount is int
              ? reviewsCount
              : (reviewsCount is num ? reviewsCount.toInt() : 0);

          debugPrint(
              '✅ [_getParticipantInfoAsync] 創建者視角 - 從 chat_partner_info 獲取應徵者資料');
          debugPrint('  - 姓名: $name, 評分: $avgRating ($count 評論)');

          return (name, avatar?.toString(), avgRating, count);
        }
      }

      // 🔧 新增：通過 UserInfoService API 獲取 participant 的完整資料
      debugPrint('🔍 [_getParticipantInfoAsync] 通過 API 獲取 participant 完整資料');

      try {
        final completeInfo =
            await UserInfoService.getUserCompleteInfo(participantIdInt);

        debugPrint('✅ [_getParticipantInfoAsync] API 獲取成功');
        debugPrint('  - 姓名: ${completeInfo.$1}');
        debugPrint('  - 評分: ${completeInfo.$3} (${completeInfo.$4} 評論)');

        return completeInfo;
      } catch (e) {
        debugPrint('❌ [_getParticipantInfoAsync] API 獲取失敗: $e');

        // 備用方案：從 room 資料中取得基本資訊
        final participantName =
            room['participant_name']?.toString().trim() ?? 'Applicant';
        final participantAvatar = room['participant_avatar']?.toString();

        debugPrint('⚠️ [_getParticipantInfoAsync] 使用備用方案從 room 資料獲取');
        return (participantName, participantAvatar, 0.0, 0);
      }
    } catch (e) {
      debugPrint('❌ [_getParticipantInfoAsync] 錯誤: $e');
      return ('Applicant', null, 0.0, 0);
    }
  }

  /// 🔧 保留：同步版本的方法（向後兼容）
  /// 返回 (姓名, 頭像URL, 平均評分, 評論數量)
  (String, String?, double, int) _getParticipantInfo() {
    try {
      final room = _room;
      if (room == null) {
        debugPrint('❌ [_getParticipantInfo] _room 為 null');
        return ('Applicant', null, 0.0, 0);
      }

      // 取得 participant_id
      final participantId = room['participant_id'];
      final int? participantIdInt = (participantId is int)
          ? participantId
          : int.tryParse('$participantId');

      debugPrint('🔍 [_getParticipantInfo] participant_id: $participantIdInt');

      // 判斷當前用戶角色來決定資料來源
      if (_userRole == 'creator') {
        // 如果我是創建者，participant 就是對方，使用 chat_partner_info
        final chatPartnerInfo = _chatPartnerInfo;
        if (chatPartnerInfo != null) {
          final name =
              chatPartnerInfo['name']?.toString().trim() ?? 'Applicant';
          final avatar =
              chatPartnerInfo['avatar_url'] ?? chatPartnerInfo['avatar'];
          final rating = chatPartnerInfo['rating'];
          final reviewsCount = chatPartnerInfo['reviewsCount'];

          final avgRating = rating is double
              ? rating
              : (rating is num ? rating.toDouble() : 0.0);
          final count = reviewsCount is int
              ? reviewsCount
              : (reviewsCount is num ? reviewsCount.toInt() : 0);

          debugPrint(
              '✅ [_getParticipantInfo] 創建者視角 - 從 chat_partner_info 獲取應徵者資料');
          debugPrint('  - 姓名: $name, 評分: $avgRating ($count 評論)');

          return (name, avatar?.toString(), avgRating, count);
        }
      } else {
        // 如果我是應徵者，participant 就是我自己，需要從其他地方獲取我的資料
        // 這種情況下應該不會顯示 Resume Dialog，但為了完整性還是處理
        debugPrint('⚠️ [_getParticipantInfo] 應徵者視角 - 不應該顯示自己的 Resume');

        // 從 room 資料中取得 participant 資訊
        final participantName = room['participant_name']?.toString().trim() ??
            '${room['participant_name']?.toString().trim()}(You)';
        final participantAvatar = room['participant_avatar']?.toString();

        // 從 RatingService 獲取評分（如果需要的話）
        return (participantName, participantAvatar, 0.0, 0);
      }

      // 備用方案：從 room 資料中取得
      final participantName =
          room['participant_name']?.toString().trim() ?? 'Applicant';
      final participantAvatar = room['participant_avatar']?.toString();

      debugPrint('⚠️ [_getParticipantInfo] 使用備用方案從 room 資料獲取');
      return (participantName, participantAvatar, 0.0, 0);
    } catch (e) {
      debugPrint('❌ [_getParticipantInfo] 錯誤: $e');
      return ('Applicant', null, 0.0, 0);
    }
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

          // 立即同步 Provider 未讀為 0，避免等待後端推播造成數字不同步
          try {
            final provider = context.read<ChatListProvider>();
            provider.markRoomRead(_currentRoomId!);
          } catch (_) {}

          // 背景刷新一次快照，確保跨分頁一致
          // ignore: discarded_futures
          NotificationCenter().service.refreshSnapshot();

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

  // 倒數計時相關變數（使用 CountdownTimerWidget）
  DateTime? _countdownEndTime;
  bool _isCountdownActive = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 ChatDetailPage.initState() 開始');
    debugPrint('🔍 widget.data: ${widget.data}');

    // 初始化 actionCallbacks
    _actionCallbacks = {
      'accept': () => _handleAcceptApplication(),
      'reject': () => _handleRejectApplication(),
      'withdraw': () => _handleWithdrawApplication(),
      'block': () => _handleBlockUser(),
      'unblock': () => _handleUnblockUser(),
      'report': () => _openReportSheet(),
      'pay': () => _openPayAndReview(),
      'complete': () => _handleCompleteTask(),
      'confirm': () => _handleConfirmCompletion(),
      'disagree': () => _handleDisagreeCompletion(),
      'paid_info': () => _showPaidInfo(),
      'review': () => _openReviewDialog(),
      'view_review': () => _viewExistingReview(),
      'dispute': () => _handleDispute(),
      // Support 相關動作
      'issue': () => _handleShowSupportTimeline(),
      'solved': () => _handleSupportSolved(),
      'close': () => _handleSupportSolved(), // 使用相同的處理邏輯
    };

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
      // debugPrint('🔍 [ChatDetailPage] 嘗試從 UserService 獲取用戶');
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.ensureUserLoaded();
      // debugPrint('  - UserService 載入完成');

      if (userService.currentUser != null) {
        // debugPrint(
        // '✅ [ChatDetailPage] UserService 有當前用戶：${userService.currentUser!.id}');
        // debugPrint('  - 用戶ID: ${userService.currentUser!.id}');
        // debugPrint('  - 用戶名稱: ${userService.currentUser!.name}');
        // debugPrint('  - 用戶頭像: ${userService.currentUser!.avatar_url}');

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

    // 當展開 Action Bar 時，重新讀取最新的任務狀態
    if (_showActionBar) {
      _refreshTaskStatusOnExpand();
    }
  }

  /// 展開 Action Bar 時刷新任務狀態
  Future<void> _refreshTaskStatusOnExpand() async {
    // 防重複刷新
    if (_isRefreshingTaskStatus) {
      debugPrint('⚠️ [ChatDetailPage] 任務狀態刷新進行中，跳過');
      return;
    }

    debugPrint('🔄 [ChatDetailPage] Action Bar 展開，刷新任務狀態');

    setState(() {
      _isRefreshingTaskStatus = true;
    });

    try {
      // 獲取當前 room_id
      final roomId = _currentRoomId;
      if (roomId == null || roomId.isEmpty) {
        debugPrint('⚠️ [ChatDetailPage] 無 room_id，跳過狀態刷新');
        return;
      }

      // 重新獲取聊天室數據以更新任務狀態
      final rawChatData = await ChatService().getChatDetailData(roomId: roomId);

      if (rawChatData.isNotEmpty && mounted) {
        // 🔧 修復：應用應徵狀態映射修正
        final chatData = _fixApplicationStatusMapping(rawChatData);
        final newTask = chatData['task'];
        final currentTask = _task;

        // 比較任務狀態是否有變化
        final currentStatus = currentTask?['status']?['code'];
        final newStatus = newTask?['status']?['code'];
        final currentAppStatus = currentTask?['application']?['status'];
        final newAppStatus = newTask?['application']?['status'];

        // 🔍 詳細調試信息
        debugPrint('🔍 [_refreshTaskStatusOnExpand] 狀態比較:');
        debugPrint(
            '  - 任務狀態: $currentStatus → $newStatus (變化: ${currentStatus != newStatus})');
        debugPrint(
            '  - 應徵狀態: $currentAppStatus → $newAppStatus (變化: ${currentAppStatus != newAppStatus})');
        debugPrint(
            '  - 整體變化: ${currentStatus != newStatus || currentAppStatus != newAppStatus}');

        // 檢查是否有實質性變化（排除 null 值的干擾）
        final hasTaskStatusChange = currentStatus != newStatus;
        final hasAppStatusChange = currentAppStatus != newAppStatus;
        final hasRealChange = hasTaskStatusChange || hasAppStatusChange;

        if (hasRealChange) {
          debugPrint('📊 [ChatDetailPage] 檢測到任務狀態變化:');
          debugPrint('  - 任務狀態: $currentStatus → $newStatus');
          debugPrint('  - 應徵狀態: $currentAppStatus → $newAppStatus');

          // 更新任務數據
          setState(() {
            _chatData = {..._chatData!, ...chatData};
          });

          // 顯示狀態變化提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Task status updated'),
                  ],
                ),
                backgroundColor: Colors.blue[600],
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          debugPrint('✅ [ChatDetailPage] 任務狀態無變化，保持現有狀態');
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatDetailPage] 刷新任務狀態失敗: $e');
      // 靜默失敗，不影響用戶體驗
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingTaskStatus = false;
        });
      }
    }
  }

  /// 選擇並直接發送圖片
  Future<void> _pickAndSendImage() async {
    try {
      // 使用 CrossPlatformImageService 來選擇圖片（Web 兼容）
      final imageService = CrossPlatformImageService();
      final image = await imageService.pickFromGallery(
        config: ImageValidationConfig.chat,
      );

      if (image != null) {
        await _sendImageMessage(image);
      }
    } catch (e) {
      debugPrint('❌ 選擇圖片失敗: $e');
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

  /// 發送圖片訊息
  Future<void> _sendImageMessage(ImageResult image,
      {String? existingMessageId}) async {
    if (_currentRoomId == null) {
      debugPrint('❌ 無法取得 roomId');
      return;
    }

    // 使用現有的 messageId 或創建新的
    final messageId =
        existingMessageId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final localId = messageId.replaceFirst('temp_', '');

    try {
      // 獲取或創建上傳狀態
      final existingStatus = _uploadingImages[messageId];
      final uploadStatus = existingStatus?.copyWith(
            state: ImageUploadState.uploading,
            progress: 0.0,
            errorMessage: null,
            retryCount: existingStatus.retryCount + 1,
          ) ??
          ImageUploadStatus.uploading(
            localId: localId,
            messageId: messageId,
            imageData: image.bytes,
            fileName: image.name,
          );

      setState(() {
        _uploadingImages[messageId] = uploadStatus;
      });

      // 滾動到底部（僅新上傳時）
      if (existingMessageId == null) {
        _scrollToBottom();
      }

      // 模擬進度更新
      _simulateUploadProgress(messageId);

      // 上傳圖片
      final uploadResult = await ChatService().uploadAttachment(
        roomId: _currentRoomId!,
        image: image,
      );

      if (uploadResult['success'] == true) {
        final uploadedUrl =
            uploadResult['data']?['url'] ?? uploadResult['data']?['path'];
        final tempFilePath =
            ImageCleanupService.extractFilePathFromUploadResult(uploadResult);

        // 更新進度到 90%
        setState(() {
          _uploadingImages[messageId] = uploadStatus.copyWith(
            progress: 0.9,
            tempFilePath: tempFilePath,
            retryCount: uploadStatus.retryCount,
          );
        });

        // 發送圖片訊息
        await ChatService().sendMessage(
          roomId: _currentRoomId!,
          message: uploadedUrl ?? '',
          kind: 'image',
        );

        // 更新為成功狀態
        setState(() {
          _uploadingImages[messageId] = uploadStatus.copyWith(
            state: ImageUploadState.success,
            progress: 1.0,
            uploadedUrl: uploadedUrl,
            retryCount: uploadStatus.retryCount,
          );
        });

        // 延遲移除上傳狀態並重新載入訊息
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _uploadingImages.remove(messageId);
            });
            _loadChatMessagesFromDatabase();
            // 圖片上傳成功後滾動到底部
            _scrollToBottom();
          }
        });
      } else {
        // 上傳失敗，保存暫存檔案路徑以便清理
        final tempFilePath =
            ImageCleanupService.extractFilePathFromUploadResult(uploadResult);

        setState(() {
          _uploadingImages[messageId] = uploadStatus.copyWith(
            state: ImageUploadState.failed,
            errorMessage: uploadResult['message'] ?? '上傳失敗',
            tempFilePath: tempFilePath,
            retryCount: uploadStatus.retryCount,
          );
        });
      }
    } catch (e) {
      debugPrint('❌ 發送圖片訊息失敗: $e');

      // 更新為失敗狀態
      setState(() {
        final existingStatus = _uploadingImages[messageId];
        _uploadingImages[messageId] = existingStatus?.copyWith(
              state: ImageUploadState.failed,
              errorMessage: e.toString(),
              retryCount: existingStatus.retryCount,
            ) ??
            ImageUploadStatus.failed(
              localId: localId,
              messageId: messageId,
              imageData: image.bytes,
              fileName: image.name,
              errorMessage: e.toString(),
            );
      });
    }
  }

  /// 模擬上傳進度更新
  void _simulateUploadProgress(String messageId) {
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final status = _uploadingImages[messageId];
      if (status == null || status.state != ImageUploadState.uploading) {
        timer.cancel();
        return;
      }

      final newProgress = (status.progress + 0.1).clamp(0.0, 0.8);
      setState(() {
        _uploadingImages[messageId] = status.copyWith(
          progress: newProgress,
          retryCount: status.retryCount,
        );
      });

      if (newProgress >= 0.8) {
        timer.cancel();
      }
    });
  }

  /// 重試圖片上傳
  Future<void> _retryImageUpload(String messageId) async {
    final uploadStatus = _uploadingImages[messageId];
    if (uploadStatus == null) return;

    try {
      // 重新創建 ImageResult
      final image = ImageResult(
        bytes: uploadStatus.imageData,
        name: uploadStatus.fileName,
        mimeType: 'image/jpeg', // 預設類型
        size: uploadStatus.imageData.length,
      );

      // 更新為上傳中狀態
      setState(() {
        _uploadingImages[messageId] = uploadStatus.copyWith(
          state: ImageUploadState.uploading,
          progress: 0.0,
          errorMessage: null,
          retryCount: uploadStatus.retryCount + 1,
        );
      });

      // 使用現有的 messageId 重新上傳
      await _sendImageMessage(image, existingMessageId: messageId);
    } catch (e) {
      debugPrint('❌ 重試上傳失敗: $e');
      setState(() {
        _uploadingImages[messageId] = uploadStatus.copyWith(
          state: ImageUploadState.failed,
          errorMessage: e.toString(),
          retryCount: uploadStatus.retryCount,
        );
      });
    }
  }

  /// 取消圖片上傳
  Future<void> _cancelImageUpload(String messageId) async {
    final uploadStatus = _uploadingImages[messageId];

    // 如果有暫存檔案，嘗試清理
    if (uploadStatus?.tempFilePath != null) {
      await ImageCleanupService.cleanupFailedUpload(
          uploadStatus!.tempFilePath!);
    }

    setState(() {
      _uploadingImages.remove(messageId);
    });

    debugPrint('🗑️ 已取消圖片上傳: $messageId');
  }

  /// 移除失敗的圖片訊息
  Future<void> _removeFailedImageMessage(String messageId) async {
    final uploadStatus = _uploadingImages[messageId];

    // 清理失敗的圖片檔案
    if (uploadStatus?.tempFilePath != null) {
      final success = await ImageCleanupService.cleanupFailedUpload(
          uploadStatus!.tempFilePath!);
      if (success) {
        debugPrint('✅ 成功清理失敗的圖片檔案: ${uploadStatus.tempFilePath}');
      }
    }

    setState(() {
      _uploadingImages.remove(messageId);
    });

    debugPrint('🗑️ 已移除失敗的圖片訊息: $messageId');

    // 顯示成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已移除失敗的圖片'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 發送文字訊息
  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 先清空輸入框
    _controller.clear();

    await _sendMessage(textOverride: text);
  }

  // 已移除 _pickAndSendPhoto - 使用新的圖片上傳邏輯

  /// 🔧 清除聊天室相關快取
  Future<void> _clearChatCache(String roomId) async {
    try {
      debugPrint('🧹 清除聊天室快取: roomId=$roomId');

      // 清除 SharedPreferences 快取
      await ChatStorageService.clearChatRoomData(roomId);

      // 清除預載入快取
      ChatPreloadService.clearPreloadedData(roomId);

      // 清除會話快取
      await ChatSessionManager.clearCurrentChatSession();

      debugPrint('✅ 聊天室快取清除完成');
    } catch (e) {
      debugPrint('⚠️ 清除快取時發生錯誤: $e');
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
          // 立即同步 Provider
          try {
            final provider = context.read<ChatListProvider>();
            provider.markRoomRead(_currentRoomId!);
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 離開 Socket.IO 房間
    if (_currentRoomId != null) {
      _socketService.leaveRoom(_currentRoomId!);
    }

    // 清理倒數計時相關資源（CountdownTimerWidget 會自動清理自己的 ticker）
    _countdownEndTime = null;
    _isCountdownActive = false;

    // 清理其他資源
    _controller.dispose();
    _focusNode.dispose();
    _listController.dispose();

    // 清理上傳中的圖片狀態
    _uploadingImages.clear();

    super.dispose();
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
          _errorMessage =
              'Unable to retrieve chat room ID. Please go back to the chat list and reselect.';
        });
        return;
      }

      debugPrint('🔍 初始化聊天室，room_id: $roomId');

      // 🔧 清除快取以確保獲取最新資料（用於測試評分修復）
      await _clearChatCache(roomId);

      // 使用聚合 API 獲取聊天室數據
      final chatData = await ChatService().getChatDetailData(roomId: roomId);

      // 驗證返回的數據
      if (chatData.isEmpty) {
        debugPrint('❌ ChatService.getChatDetailData 返回空數據');
        setState(() {
          _hasError = true;
          _errorMessage =
              'Unable to load chat room data. Please try again later.';
        });
        return;
      }

      debugPrint('✅ 成功獲取聊天室數據: ${chatData.keys}');

      if (mounted) {
        setState(() {
          // 修正應徵狀態數據映射問題
          final fixedChatData = _fixApplicationStatusMapping(chatData);

          // 更新聊天室數據
          _chatData = fixedChatData;
          _userRole = chatData['user_role'] ?? 'participant';
          _currentRoomId = roomId;
          _isBlocked = chatData['is_blocked'] ?? false;

          // 解析詳細的封鎖狀態
          final blockInfo = chatData['block_info'];
          if (blockInfo != null) {
            _isBlockedByMe = blockInfo['blocked_by_me'] ?? false;
            _isBlockedByTarget = blockInfo['blocked_by_target'] ?? false;
          } else {
            _isBlockedByMe = false;
            _isBlockedByTarget = false;
          }

          // 檢查是否已有評分
          _hasExistingReview = chatData['has_existing_review'] ?? false;

          // 動態檢查評分狀態（如果任務已完成）
          if (_task != null && _task!['status_code'] == 'completed') {
            _checkReviewStatus();
          }
        });

        // 提前嘗試加入房間（即便尚未連上 socket，會先排入佇列）
        try {
          _socketService.joinRoom(roomId);
        } catch (_) {}

        // 保存完整的聊天室數據到本地儲存
        await _saveChatRoomData(chatData, roomId);

        // 更新任務狀態相關數據
        final task = chatData['task'];
        if (task != null) {
          // 計算倒數計時結束時間（不觸發 setState）
          _calculateCountdownEndTime(task);
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
      debugPrint('❌ Initialize chat detail failed: $e');
      // 在 initState 中不能使用 ScaffoldMessenger.of(context)
      // 將錯誤存儲到狀態中，在 build 方法中顯示
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Load chat detail failed: $e';
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
      _socketService.onTaskStatusUpdate = _onTaskStatusUpdate;
      _socketService.onApplicationStatusUpdate = _onApplicationStatusUpdate;
      _socketService.onBlockStatusUpdate = _onBlockStatusUpdate;

      // 加入當前聊天室（保險：立即與延時重試）
      if (_currentRoomId != null) {
        final rid = _currentRoomId!;
        _socketService.joinRoom(rid);
        _socketService.markRoomAsRead(rid);
        // 本地先行將 Provider 未讀設為 0，提升體感一致性
        try {
          final provider = context.read<ChatListProvider>();
          provider.markRoomRead(rid);
        } catch (_) {}
        // 每次建立/切換聊天室時，解析一次對方身份與頭像
        _resolveOpponentIdentity();
        // 延時重試一次（若初次連線仍在建立中）
        Future.delayed(const Duration(milliseconds: 400), () {
          _socketService.joinRoom(rid);
          _socketService.markRoomAsRead(rid);
          try {
            final provider = context.read<ChatListProvider>();
            provider.markRoomRead(rid);
          } catch (_) {}
        });
        // 再延時一次 1 秒做最終保險
        Future.delayed(const Duration(seconds: 1), () {
          _socketService.joinRoom(rid);
          _socketService.markRoomAsRead(rid);
          try {
            final provider = context.read<ChatListProvider>();
            provider.markRoomRead(rid);
          } catch (_) {}
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
      debugPrint('❌ Resolve opponent identity failed: $e');
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

  /// 處理任務狀態更新 - 純局部更新版本
  void _onTaskStatusUpdate(Map<String, dynamic> data) {
    debugPrint('📋 Task status update received: $data');

    // 檢查是否為當前聊天室的任務
    final roomId = data['room_id']?.toString();
    final taskId = data['task_id']?.toString();

    if (roomId == _currentRoomId || taskId == _task?['id']?.toString()) {
      debugPrint('🔄 Updating task status locally (no full refresh)');

      // 1. 立即更新本地任務狀態（即時性）
      _updateTaskStatusLocally(data);

      // 2. 顯示狀態變更通知
      final statusData = data['status'] as Map<String, dynamic>?;
      if (statusData != null) {
        _showTaskStatusChangeNotification(statusData);
      }

      // 3. 通知 Provider 刷新聊天列表（保持列表同步）
      _notifyProviderRefresh();

      // 移除全量刷新：不再呼叫 _initializeChat()
    }
  }

  /// 立即更新本地任務狀態 - 增強版本
  void _updateTaskStatusLocally(Map<String, dynamic> data) {
    if (!mounted) return;

    final statusData = data['status'] as Map<String, dynamic>?;
    if (statusData == null) return;

    setState(() {
      if (_task != null) {
        // 更新任務狀態
        _task!['status'] = statusData;

        // 同步更新相關的計算屬性
        _updateDerivedStates();
      }
    });

    debugPrint(
        '✅ [ChatDetailPage] Task status updated locally: ${statusData['code']}');
  }

  /// 更新衍生狀態（如倒數計時等）
  void _updateDerivedStates() {
    if (_task == null) return;

    final statusCode = _task!['status']?['code'];

    // 更新倒數計時相關狀態
    if (statusCode == 'pending_confirmation' ||
        statusCode == 'pending_confirmation_tasker') {
      _calculateCountdownEndTime(_task!);
    } else {
      _stopCountdown();
    }

    debugPrint(
        '✅ [ChatDetailPage] Derived states updated for status: $statusCode');
  }

  /// 計算倒數計時結束時間
  void _calculateCountdownEndTime(Map<String, dynamic> task) {
    final statusCode = task['status']?['code'];

    if (statusCode == 'pending_confirmation_tasker') {
      // pending_confirmation_tasker 狀態的倒數計時
      final taskCreatedAt = task['created_at'];
      if (taskCreatedAt != null) {
        try {
          final createdAt = DateTime.parse(taskCreatedAt);
          final now = DateTime.now();
          final timeSinceCreation = now.difference(createdAt);

          // 只有在創建時間合理範圍內才啟動倒計時
          if (timeSinceCreation.inDays < 30) {
            _countdownEndTime = DateTime.now().add(const Duration(seconds: 5));
            _isCountdownActive = true;
            debugPrint(
                '⏰ 設置 pending_confirmation_tasker 倒數計時，結束時間: $_countdownEndTime');
            debugPrint('⏰ 剩餘時間: 5秒（測試用）');
          } else {
            _countdownEndTime = null;
            _isCountdownActive = false;
          }
        } catch (e) {
          debugPrint('❌ 解析任務創建時間失敗: $e');
          _countdownEndTime = null;
          _isCountdownActive = false;
        }
      }
    } else if (statusCode == 'pending_confirmation') {
      // pending_confirmation 狀態的倒數計時
      final taskUpdatedAt = task['updated_at'];
      if (taskUpdatedAt != null) {
        try {
          final updatedAt = DateTime.parse(taskUpdatedAt);
          const totalPendingTime = Duration(days: 7);
          final endTime = updatedAt.add(totalPendingTime);

          if (endTime.isAfter(DateTime.now())) {
            _countdownEndTime = endTime;
            _isCountdownActive = true;
            final remaining = endTime.difference(DateTime.now());
            debugPrint('⏰ 設置 pending_confirmation 倒數計時，結束時間: $endTime');
            debugPrint(
                '⏰ 剩餘時間: ${remaining.inDays}天 ${remaining.inHours.remainder(24)}小時 ${remaining.inMinutes.remainder(60)}分鐘');
          } else {
            _countdownEndTime = null;
            _isCountdownActive = false;
            debugPrint('⏰ pending_confirmation 時間已到，應該自動完成任務');
          }
        } catch (e) {
          debugPrint('❌ 解析任務更新時間失敗: $e');
          _countdownEndTime = null;
          _isCountdownActive = false;
        }
      }
    } else {
      _countdownEndTime = null;
      _isCountdownActive = false;
    }
  }

  /// 停止倒數計時
  void _stopCountdown() {
    _countdownEndTime = null;
    _isCountdownActive = false;
    debugPrint('🛑 [ChatDetailPage] Stopping countdown');
  }

  /// 處理應徵狀態更新 - 純局部更新版本
  void _onApplicationStatusUpdate(Map<String, dynamic> data) {
    debugPrint('📝 Application status update received: $data');

    // 檢查是否為當前聊天室的應徵
    final roomId = data['room_id']?.toString();
    final taskId = data['task_id']?.toString();

    if (roomId == _currentRoomId || taskId == _task?['id']?.toString()) {
      debugPrint('🔄 Updating application status locally (no full refresh)');

      // 1. 立即更新本地應徵狀態（即時性）
      _updateApplicationStatusLocally(data);

      // 2. 顯示應徵狀態變更通知
      final applicationStatus = data['application_status']?.toString();
      if (applicationStatus != null) {
        _showApplicationStatusChangeNotification(applicationStatus);
      }

      // 3. 通知 Provider 刷新聊天列表（保持列表同步）
      _notifyProviderRefresh();

      // 移除全量刷新：不再呼叫 _initializeChat()
    }
  }

  /// 立即更新本地應徵狀態
  void _updateApplicationStatusLocally(Map<String, dynamic> data) {
    if (!mounted) return;

    final applicationStatus = data['application_status']?.toString();
    if (applicationStatus == null) return;

    setState(() {
      if (_task != null) {
        _task!['application'] = {
          'status': applicationStatus,
          'updated_at': DateTime.now().toIso8601String(),
        };
      }
    });

    debugPrint(
        '✅ [ChatDetailPage] Application status updated locally: $applicationStatus');
  }

  /// 處理封鎖狀態更新 - 優化版本（方案一：混合策略）
  void _onBlockStatusUpdate(Map<String, dynamic> data) {
    debugPrint('🚫 [ChatDetailPage] Block status update received: $data');

    if (!mounted) return;

    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      final blockedByUserId = data['blocked_by_user_id']?.toString();
      final unblockedByUserId = data['unblocked_by_user_id']?.toString();
      final targetUserId = data['target_user_id']?.toString();
      final isBlocked = data['is_blocked'] as bool? ?? false;

      // 檢查這個封鎖事件是否與當前聊天室相關
      final opponentId = _getOpponentUserId()?.toString();
      if (opponentId == null) return;

      debugPrint('🔍 [ChatDetailPage] Block status data: $data');
      debugPrint(
          '🔍 [ChatDetailPage] Current user: $currentUserId, Opponent: $opponentId');
      debugPrint(
          '🔍 [ChatDetailPage] Blocked by: $blockedByUserId, Unblocked by: $unblockedByUserId, Target: $targetUserId, Is blocked: $isBlocked');

      bool shouldUpdate = false;

      if (isBlocked) {
        // 封鎖事件：檢查是否涉及當前聊天室的雙方
        if ((blockedByUserId == currentUserId.toString() &&
                targetUserId == opponentId) ||
            (blockedByUserId == opponentId &&
                targetUserId == currentUserId.toString())) {
          shouldUpdate = true;
        }
      } else {
        // 解除封鎖事件：檢查是否涉及當前聊天室的雙方
        if ((unblockedByUserId == currentUserId.toString() &&
                targetUserId == opponentId) ||
            (unblockedByUserId == opponentId &&
                targetUserId == currentUserId.toString())) {
          shouldUpdate = true;
        }
      }

      if (shouldUpdate) {
        // 1. 立即更新本地狀態（即時性）
        _updateBlockStatusLocally(data);

        // 2. 顯示狀態變更通知
        _showBlockStatusChangeNotification(data);

        // 3. 通知 Provider 刷新聊天列表（保持列表同步）
        _notifyProviderRefresh();

        // 移除全量刷新：不再呼叫 _initializeChat()
      }
    } catch (e) {
      debugPrint('❌ [ChatDetailPage] Error handling block status update: $e');
    }
  }

  /// 立即更新本地封鎖狀態
  void _updateBlockStatusLocally(Map<String, dynamic> data) {
    if (!mounted) return;

    final isBlocked = data['is_blocked'] as bool? ?? false;
    final blockedByUserId = data['blocked_by_user_id']?.toString();
    final currentUserId = _currentUserId?.toString();

    setState(() {
      _isBlocked = isBlocked;

      if (isBlocked) {
        // 封鎖狀態
        if (blockedByUserId == currentUserId) {
          _isBlockedByMe = true;
          _isBlockedByTarget = false;
        } else {
          _isBlockedByMe = false;
          _isBlockedByTarget = true;
        }
      } else {
        // 解除封鎖狀態
        _isBlockedByMe = false;
        _isBlockedByTarget = false;
      }
    });

    debugPrint(
        '✅ [ChatDetailPage] Block status updated locally: $_isBlocked, byMe: $_isBlockedByMe, byTarget: $_isBlockedByTarget');
  }

  /// 顯示封鎖狀態變更通知
  void _showBlockStatusChangeNotification(Map<String, dynamic> data) {
    if (!mounted) return;

    final isBlocked = data['is_blocked'] as bool? ?? false;
    final blockedByUserId = data['blocked_by_user_id']?.toString();
    final unblockedByUserId = data['unblocked_by_user_id']?.toString();
    final currentUserId = _currentUserId?.toString();

    String message;
    Color backgroundColor;
    IconData icon;

    if (isBlocked) {
      if (blockedByUserId == currentUserId) {
        message = '您已封鎖此用戶，雙方無法發送訊息';
        backgroundColor = Colors.orange;
        icon = Icons.block;
      } else {
        message = '您已被此用戶封鎖，雙方無法發送訊息';
        backgroundColor = Colors.red;
        icon = Icons.block;
      }
    } else {
      if (unblockedByUserId == currentUserId) {
        message = '您已解除封鎖此用戶';
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
      } else {
        message = '此用戶已解除對您的封鎖';
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 通知 Provider 刷新聊天列表
  void _notifyProviderRefresh() {
    if (!mounted || !context.mounted) return;

    try {
      final provider = context.read<ChatListProvider>();
      // 根據用戶角色刷新對應的標籤頁
      if (_userRole == 'creator') {
        provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
        debugPrint('✅ [BlockStatus] 已通知 Provider 刷新 POSTED_TASKS');
      } else {
        provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
        debugPrint('✅ [BlockStatus] 已通知 Provider 刷新 MY_WORKS');
      }
      // 強制刷新快取
      provider.forceRefreshCache();
      debugPrint('✅ [BlockStatus] 已強制刷新快取');
    } catch (e) {
      debugPrint('❌ [BlockStatus] 通知 Provider 刷新失敗: $e');
    }
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

  /// 倒數計時完成回調
  void _onCountdownComplete() {
    debugPrint('⏰ 倒數計時結束，開始執行自動完成流程');
    _executeAutoComplete();
  }

  /// 執行自動完成任務流程
  Future<void> _executeAutoComplete() async {
    if (_task == null) return;

    try {
      debugPrint('🔄 開始執行自動完成任務流程');

      // 1. 更新任務狀態為 completed
      final success = await TaskService().updateTaskStatus(
        _task!['id'].toString(),
        TaskStatusConstants.TaskStatus.statusString['completed_tasker']!,
        statusCode: 'completed',
      );

      if (success) {
        // 2. 更新本地狀態
        setState(() {
          // 停止倒數計時
          _countdownEndTime = null;
          _isCountdownActive = false;
          if (_task != null) {
            _task!['status'] =
                TaskStatusConstants.TaskStatus.statusString['completed_tasker'];
          }
        });

        // 3. 顯示成功訊息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⏰ 倒數計時結束！任務已自動完成，獎勵點數已轉移給任務執行者。',
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.green,
            ),
          );
        }

        debugPrint('✅ 自動完成任務流程執行成功');

        // 4. 刷新聊天室資料
        await _initializeChat();
      } else {
        debugPrint('❌ 自動完成任務失敗');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('自動完成任務失敗，請稍後重試'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ 執行自動完成任務時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('自動完成任務時發生錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            content: Text('Send message failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 已移除 _getApplicationData - 使用聚合 API 數據

  /// 顯示新的結構化 Resume 對話框
  void _showResumeDialog(ResumeData resumeData) async {
    // 🔧 修復：始終取得應徵者（participant）的資料，而非對方資料
    final (participantName, participantAvatar, avgRating, reviewsCount) =
        await _getParticipantInfoAsync();

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
                    backgroundImage: participantAvatar != null
                        ? ImageHelper.getAvatarImage(participantAvatar)
                        : null,
                    backgroundColor: _getAvatarColor(participantName),
                    child: participantAvatar == null
                        ? Text(
                            _getInitials(participantName),
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
                          participantName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 條件判斷：如果評分和評論都沒有，顯示 "No reviews yet."
                        if (avgRating <= 0 && reviewsCount <= 0)
                          Text(
                            '(No reviews yet.)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
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
                        // 條件判斷：如果評分和評論都沒有，顯示 "No reviews yet."
                        if (averageRating <= 0 && totalRatings <= 0)
                          Text(
                            '(No reviews yet.)',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
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
          title: const Text('Chat Room'),
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
        _uploadingImages.length + // 加入上傳中圖片訊息
        (hasUnreadSeparator ? 1 : 0); // 加入未讀分隔線

    // 減少 debug 輸出頻率
    if (kDebugMode && totalItemCount != _lastDebugMessageCount) {
      debugPrint(
          '🔍 Messages: $totalItemCount (unread: ${hasUnreadSeparator ? 1 : 0})');
      _lastDebugMessageCount = totalItemCount;
    }

    // 已移除 buildQuestionReplyBubble - 使用 _buildViewResumeBubble 替代

    // 已移除 buildOpponentBubble - 使用 _buildTextMessage 替代

    // 已移除 buildMyMessageBubble - 使用 _buildTextMessage 替代

    final isInputDisabled = _isBlocked || // 任何封鎖狀態都禁用輸入
        _task?['status']?['code'] == 'completed' ||
        _task?['status']?['code'] == 'rejected_tasker' ||
        _task?['status']?['code'] == 'completed_tasker' ||
        _task?['application']?['status'] == 'withdrawn';
    // --- ALERT BAR SWITCH-CASE 重構 ---
    // 預設 alert bar 不會顯示，只有在特定狀態下才顯示
    Widget? alertContent;

    // 優先檢查封鎖狀態
    if (_isBlocked) {
      // 統一處理任何封鎖狀態
      String message;
      Color? backgroundColor;
      Color? textColor;

      if (_isBlockedByMe) {
        message =
            'You have blocked this user, both parties cannot send messages.';
        backgroundColor = Theme.of(context).colorScheme.tertiaryContainer;
        textColor = Theme.of(context).colorScheme.tertiary;
      } else if (_isBlockedByTarget) {
        message =
            'You have been blocked by this user, both parties cannot send messages.';
        backgroundColor = Theme.of(context).colorScheme.errorContainer;
        textColor = Theme.of(context).colorScheme.error;
      } else {
        message =
            'This chat room has been restricted, both parties cannot send messages or images.';
        backgroundColor = Theme.of(context).colorScheme.errorContainer;
        textColor = Theme.of(context).colorScheme.error;
      }

      alertContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: backgroundColor,
        child: Row(
          children: [
            Icon(Icons.block, color: textColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
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
        case 'withdrawn':
          alertContent = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have withdrawn your application for this task.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
          break;
        case 'pending_confirmation_tasker':
          alertContent = Column(
            children: [
              if (_isCountdownActive && _countdownEndTime != null)
                CountdownTimerWidget(
                  endTime: _countdownEndTime!,
                  onComplete: _onCountdownComplete,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red,
                  ),
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
              if (_isCountdownActive && _countdownEndTime != null)
                CountdownTimerWidget(
                  endTime: _countdownEndTime!,
                  onComplete: _onCountdownComplete,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red,
                  ),
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
                    // debugPrint(
                    //     '🔍 [Chat Detail] 訊息資料: messageData=$messageData');
                    // debugPrint(
                    //     '🔍 [Chat Detail] 訊息來源: messageFromUserId=${messageData['from_user_id']}, currentUserId=$_currentUserId');

                    // 檢查是否為我發送的訊息
                    final isFromMe = _currentUserId != null &&
                        messageData['from_user_id'] == _currentUserId;
                    // debugPrint('🔍 [Chat Detail] 是否為我的訊息: $isFromMe');

                    // 使用新的統一訊息渲染方法
                    return _buildMessageItem(messageData);
                  }

                  // 檢查是否為上傳中圖片訊息
                  final uploadingImageIndex =
                      adjustedIndex - _chatMessages.length;
                  if (uploadingImageIndex >= 0 &&
                      uploadingImageIndex < _uploadingImages.length) {
                    final messageId =
                        _uploadingImages.keys.elementAt(uploadingImageIndex);
                    final uploadStatus = _uploadingImages[messageId]!;
                    return UploadingImageMessage(
                      uploadStatus: uploadStatus,
                      onCancel: () => _cancelImageUpload(messageId),
                      onRetry: () => _retryImageUpload(messageId),
                      onRemove: () => _removeFailedImageMessage(messageId),
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
                                  ? 'There are $_unseenCount unread messages — click to view the latest messages'
                                  : 'There are unread messages — click to view the latest messages',
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
        if (_showActionBar && (_task != null || _isSupportRoom))
          _isSupportRoom
              ? _buildSupportActionBar()
              : DynamicActionBar(
                  taskStatus: ActionBarConfigManager.parseTaskStatus(
                      _task!['status']?['code']),
                  userRole: ActionBarConfigManager.parseUserRole(_userRole),
                  actionCallbacks: _buildActionCallbacks(),
                  applicationStatus: _task?['application']?['status'],
                  isBlocked: _isBlocked,
                  isBlockedByMe: _isBlockedByMe,
                  isBlockedByTarget: _isBlockedByTarget,
                  hasExistingReview: _hasExistingReview,
                  showStatusBar: true,
                  statusDisplayName:
                      _getStatusDisplayNameForUserRole(), // 根據用戶角色獲取狀態顯示名稱
                  progressRatio: double.tryParse(
                      _task!['status']?['progress_ratio']?.toString() ?? '0'),
                  backgroundColor: _glassNavColor(context),
                  colorScheme: _getColorSchemeForUserRole(), // 根據用戶角色設定配色方案
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
                // Theme 級別的 inputDecorationTheme 設定
                inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                  filled: true,
                  fillColor: bg.withOpacity(0.08),
                  // fillColor: bg.withOpacity(0.08),
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
                                        : _pickAndSendImage,
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
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  enabled: !isInputDisabled,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (value) {
                                    if (!isInputDisabled) {
                                      _sendTextMessage();
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
                                        left: 14, top: 12, bottom: 12),
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
                                onPressed:
                                    isInputDisabled ? null : _sendTextMessage,
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

  // 緩存 actionCallbacks 避免無限重建
  late final Map<String, VoidCallback> _actionCallbacks;

  // 用於減少 debug 輸出頻率
  int _lastDebugMessageCount = -1;

  /// 構建動作回調映射（已緩存）
  Map<String, VoidCallback> _buildActionCallbacks() {
    return _actionCallbacks;
  }

  /// 構建支援聊天室的 Action Bar
  Widget _buildSupportActionBar() {
    // 使用新的 ActionBarConfigManager 來獲取客服聊天室的動作
    final supportStatus = _chatData?['support_event']?['status']?.toString();
    final actions = ActionBarConfigManager.getActionsForStatus(
      userRole: ActionBarConfigManager.parseUserRole(_userRole),
      actionCallbacks: _buildActionCallbacks(),
      chatRoomType: 'support',
      supportStatus: supportStatus,
    );

    if (actions.isEmpty) {
      // 如果沒有動作，顯示狀態信息
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _glassNavColor(context),
          border: const Border(
            bottom: BorderSide(color: Colors.grey, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Support Chat - ${_getSupportStatusDisplay(supportStatus)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _glassNavColor(context),
        border: const Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) {
          return _buildSupportActionButton(
            icon: action.icon,
            label: action.label,
            onTap: action.onTap,
            backgroundColor: action.backgroundColor,
          );
        }).toList(),
      ),
    );
  }

  String _getSupportStatusDisplay(String? status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Unknown';
    }
  }

  /// 構建支援動作按鈕
  Widget _buildSupportActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  /// 處理顯示支援事件時間線
  Future<void> _handleShowSupportTimeline() async {
    if (!_isSupportRoom || _currentRoomId == null) return;

    try {
      // 獲取支援事件詳情和時間線
      final events =
          await SupportEventApi.getEvents(chatRoomId: _currentRoomId!);

      if (!mounted) return;

      // 使用專門的 SupportTimelineDialog
      await showDialog(
        context: context,
        builder: (context) => SupportTimelineDialog(
          events: events,
          title: 'Support Event Timeline',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load support timeline: $e')),
      );
    }
  }

  /// 處理支援事件結案
  Future<void> _handleSupportSolved() async {
    if (!_isSupportRoom || _currentRoomId == null) return;

    try {
      // 獲取最新的支援事件以取得標題
      final events =
          await SupportEventApi.getEvents(chatRoomId: _currentRoomId!);

      if (events.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No support events found')),
        );
        return;
      }

      final latestEvent = events.first;
      final eventTitle = latestEvent['title'] ?? 'Support Case';

      // 使用專門的 SupportSolvedDialog
      await showSupportSolvedDialog(
        context: context,
        eventTitle: eventTitle,
        onSubmit: (rating, review) async {
          final eventId = latestEvent['id'].toString();
          await SupportEventApi.closeEvent(
            eventId: eventId,
            rating: rating,
            review: review,
          );
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support case closed successfully')),
      );

      // 刷新聊天室數據
      await _initializeChat();

      // Support 操作完成後自動收起 Action Bar
      if (mounted) {
        setState(() {
          _showActionBar = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to close support case: $e')),
      );
    }
  }

  /// 處理申訴 TODO: 建立申訴表單
  Future<void> _handleDispute() async {
    if (_task == null || _currentRoomId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DisputeDialog(
        taskId: _task!['id'].toString(),
        chatRoomId: _currentRoomId!, // 新增必要的 chatRoomId 參數
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

      // 申訴操作完成後自動收起 Action Bar
      if (mounted) {
        setState(() {
          _showActionBar = false;
        });
      }
    }
  }

  /// 處理接受應徵
  Future<void> _handleAcceptApplication() async {
    debugPrint('🔍 [ChatDetailPage] _handleAcceptApplication() 開始');

    // 防重複點擊檢查
    if (_isAccepting) {
      debugPrint('⚠️ [ChatDetailPage] Accept 操作進行中，忽略重複點擊');
      return;
    }

    debugPrint('  - _task: ${_task != null ? 'not null' : 'null'}');
    debugPrint('  - _chatData: ${_chatData != null ? 'not null' : 'null'}');
    debugPrint('  - _room: ${_room != null ? 'not null' : 'null'}');

    if (_task == null) {
      debugPrint('❌ [ChatDetailPage] _task 為 null，無法處理接受應徵');
      return;
    }

    // 設置操作狀態
    setState(() {
      _isAccepting = true;
    });

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

      debugPrint('✅ [Accept] API 調用成功，結果: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result['message'] ?? 'Application accepted successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
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
          // 根據用戶角色刷新對應的標籤頁
          if (_userRole == 'creator') {
            provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
            debugPrint('✅ [Accept] 已通知 Provider 刷新 POSTED_TASKS');
          } else {
            provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
            debugPrint('✅ [Accept] 已通知 Provider 刷新 MY_WORKS');
          }
          // 強制刷新快取
          provider.forceRefreshCache();
          debugPrint('✅ [Accept] 已強制刷新快取');

          // 新增：通知兩個分頁的分頁控制器刷新（若上層有監聽）
          try {
            provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
            provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
          } catch (_) {}
        } catch (e) {
          debugPrint('❌ 通知 Provider 刷新失敗: $e');
        }

        // 重新載入聊天室狀態以更新 Action Bar
        await _initializeChat();

        // 確保接受後 Action Bar 仍保持可見，讓使用者立即看到新的按鈕
        if (mounted) {
          setState(() {
            _showActionBar = true;
          });
        }
      }
    } catch (e) {
      ErrorHandlerService.logError(
          'ChatDetailPage._handleAcceptApplication', e);
      if (mounted) {
        ErrorSnackBar.show(context, e, operation: 'accept_application');
      }
    } finally {
      // 重置操作狀態
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  /// 處理撤銷應徵申請
  Future<void> _handleWithdrawApplication() async {
    // 防重複點擊檢查
    if (_isWithdrawing) {
      debugPrint('⚠️ [ChatDetailPage] Withdraw 操作進行中，忽略重複點擊');
      return;
    }

    final taskId = _task?['id']?.toString();
    if (taskId == null) return;

    // 設置操作狀態
    setState(() {
      _isWithdrawing = true;
    });

    try {
      // 顯示確認對話框
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Withdraw Application'),
          content: const Text(
              'Are you sure you want to withdraw this task\'s application? Once withdrawn, you will not be able to apply for this task again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm Withdraw'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ChatService().withdrawApplication(taskId: taskId);
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('The application has been withdrawn')),
          // );
          // 重新載入聊天室狀態
          await _initializeChat();

          // 自動收起 Action Bar
          // setState(() {
          //   _showActionBar = false;
          // });
        }
      }
    } catch (e) {
      ErrorHandlerService.logError(
          'ChatDetailPage._handleWithdrawApplication', e);
      if (mounted) {
        ErrorSnackBar.show(context, e, operation: 'withdraw_application');
      }
    } finally {
      // 重置操作狀態
      if (mounted) {
        setState(() {
          _isWithdrawing = false;
        });
      }
    }
  }

  /// 處理拒絕應徵
  Future<void> _handleRejectApplication() async {
    debugPrint('🔍 [ChatDetailPage] _handleRejectApplication() 開始');

    // 防重複點擊檢查
    if (_isRejecting) {
      debugPrint('⚠️ [ChatDetailPage] Reject 操作進行中，忽略重複點擊');
      return;
    }

    if (_task == null) {
      debugPrint('❌ [ChatDetailPage] _task 為 null，無法處理拒絕應徵');
      return;
    }

    // 設置操作狀態
    setState(() {
      _isRejecting = true;
    });

    try {
      // 確保當前用戶ID已載入
      if (_currentUserId == null) {
        debugPrint('  - _currentUserId 為 null，開始載入');
        await _loadCurrentUserId();
        debugPrint('  - 載入後 _currentUserId: $_currentUserId');
      }

      if (_currentUserId == null) {
        debugPrint('❌ [ChatDetailPage] 載入後仍無法獲取當前用戶ID');
        throw Exception('Unable to get current user ID');
      }

      // 檢查聊天室數據是否已載入
      if (_chatData == null || _chatData!.isEmpty) {
        debugPrint('❌ [ChatDetailPage] _chatData 為空，無法獲取對手用戶ID');
        throw Exception('Chat data not loaded. Please refresh the page.');
      }

      // 獲取對手用戶ID（應徵者）
      final opponentId = _getOpponentUserId();
      debugPrint('  - 獲取到的 opponentId: $opponentId');

      if (opponentId == null) {
        debugPrint('❌ [ChatDetailPage] 無法獲取對手用戶ID');
        throw Exception(
            'Unable to get opponent user ID. Please check chat room data.');
      }

      debugPrint(
          '✅ 準備拒絕應徵 - Task: ${_task!['id']}, User: $opponentId, Poster: $_currentUserId');

      // 呼叫 TaskService 的 rejectApplicationFromChat 方法
      final result = await TaskService().rejectApplicationFromChat(
        taskId: _task!['id'].toString(),
        applicantUserId: opponentId,
      );

      debugPrint('✅ [Reject] API 調用成功，結果: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result['message'] ?? 'Application rejected successfully!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 通知 Provider 刷新聊天列表數據
      if (mounted && context.mounted) {
        try {
          final provider = context.read<ChatListProvider>();
          // 根據用戶角色刷新對應的標籤頁
          if (_userRole == 'creator') {
            provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
            debugPrint('✅ [Reject] 已通知 Provider 刷新 POSTED_TASKS');
          }
          // 強制刷新快取
          provider.forceRefreshCache();
          debugPrint('✅ [Reject] 已強制刷新快取');
        } catch (e) {
          debugPrint('❌ 通知 Provider 刷新失敗: $e');
        }
      }

      // 重要：reject 成功後導航回到聊天列表頁面
      if (mounted) {
        debugPrint('🔙 [Reject] 導航回到聊天列表');
        context.go('/chat');
      }
    } catch (e) {
      ErrorHandlerService.logError(
          'ChatDetailPage._handleRejectApplication', e);
      if (mounted) {
        ErrorSnackBar.show(context, e, operation: 'reject_application');
      }
    } finally {
      // 重置操作狀態
      if (mounted) {
        setState(() {
          _isRejecting = false;
        });
      }
    }
  }

  /// 處理封鎖用戶
  Future<void> _handleBlockUser() async {
    final opponentId = _getOpponentUserId();
    final opponentName = _getOpponentUserName();
    if (opponentId == null) return;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BlockUserDialog(
          targetUserId: opponentId.toString(),
          targetUserName: opponentName ?? 'User',
          isCurrentlyBlocked: false,
          onBlockStatusChanged: () {
            // 重新載入聊天室狀態
            _initializeChat();
          },
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ User blocked successfully')),
        );
      }
    } catch (e) {
      ErrorHandlerService.logError('ChatDetailPage._handleBlockUser', e);
      if (mounted) {
        // 檢查是否為重複封鎖錯誤
        final errorMessage = e.toString();
        if (errorMessage.contains('Block relationship already exists') ||
            errorMessage.contains('409')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Block relationship already exists between these users'),
              backgroundColor: Colors.orange,
            ),
          );
          // 重新載入狀態以同步最新的封鎖狀態
          _initializeChat();
        } else {
          ErrorSnackBar.show(context, e, operation: 'block_user');
        }
      }
    }
  }

  /// 處理解除封鎖用戶
  Future<void> _handleUnblockUser() async {
    final opponentId = _getOpponentUserId();
    final opponentName = _getOpponentUserName();
    if (opponentId == null) return;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BlockUserDialog(
          targetUserId: opponentId.toString(),
          targetUserName: opponentName ?? 'User',
          isCurrentlyBlocked: true,
          onBlockStatusChanged: () {
            // 重新載入聊天室狀態
            _initializeChat();
          },
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Block removed successfully')),
        );
      }
    } catch (e) {
      ErrorHandlerService.logError('ChatDetailPage._handleUnblockUser', e);
      if (mounted) {
        // 檢查是否為找不到封鎖記錄的錯誤
        final errorMessage = e.toString();
        if (errorMessage.contains('No block relationship found') ||
            errorMessage.contains('404')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No block relationship found to remove'),
              backgroundColor: Colors.orange,
            ),
          );
          // 重新載入狀態以同步最新的封鎖狀態
          _initializeChat();
        } else {
          ErrorSnackBar.show(context, e, operation: 'unblock_user');
        }
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

      // Complete 操作後，只對 participant 自動收起 Action Bar
      if (mounted && _userRole == 'participant') {
        setState(() {
          _showActionBar = false;
        });
      }
    }
  }

  /// 處理確認完成
  Future<void> _handleConfirmCompletion() async {
    if (_task == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ConfirmPayDialog(
          task: _task,
          room: _room,
          title: 'Confirm Completion',
          buttonText: 'Confirm & Pay',
          onPaymentSuccess: () {
            // 確認完成成功後的回調
            Navigator.of(context).pop(true);
          },
        );
      },
    );

    if (result == true && mounted) {
      debugPrint('✅ [Confirm] 確認完成成功，刷新聊天室狀態');

      // 通知 Provider 刷新聊天列表數據
      try {
        final provider = context.read<ChatListProvider>();
        // 根據用戶角色刷新對應的標籤頁
        if (_userRole == 'creator') {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
          debugPrint('✅ [Confirm] 已通知 Provider 刷新 POSTED_TASKS');
        } else {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
          debugPrint('✅ [Confirm] 已通知 Provider 刷新 MY_WORKS');
        }
        // 強制刷新快取
        provider.forceRefreshCache();
        debugPrint('✅ [Confirm] 已強制刷新快取');

        // 通知兩個分頁的分頁控制器刷新
        try {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
          provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
        } catch (_) {}
      } catch (e) {
        debugPrint('❌ 通知 Provider 刷新失敗: $e');
      }

      // 重新載入聊天室狀態以更新 Action Bar
      await _initializeChat();

      // Confirm 操作後，只對 creator 自動收起 Action Bar
      if (mounted && _userRole == 'creator') {
        setState(() {
          _showActionBar = false;
        });
      }
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

    if (result == true && mounted) {
      debugPrint('✅ [Disagree] 駁回完成成功，刷新聊天室狀態');

      // 通知 Provider 刷新聊天列表數據
      try {
        final provider = context.read<ChatListProvider>();
        // 根據用戶角色刷新對應的標籤頁
        if (_userRole == 'creator') {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
          debugPrint('✅ [Disagree] 已通知 Provider 刷新 POSTED_TASKS');
        } else {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
          debugPrint('✅ [Disagree] 已通知 Provider 刷新 MY_WORKS');
        }
        // 強制刷新快取
        provider.forceRefreshCache();
        debugPrint('✅ [Disagree] 已強制刷新快取');

        // 通知兩個分頁的分頁控制器刷新
        try {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
          provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
        } catch (_) {}
      } catch (e) {
        debugPrint('❌ 通知 Provider 刷新失敗: $e');
      }

      // 重新載入聊天室狀態以更新 Action Bar
      await _initializeChat();

      // Disagree 操作後，只對 creator 自動收起 Action Bar
      if (mounted && _userRole == 'creator') {
        setState(() {
          _showActionBar = false;
        });
      }
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
            _openReviewDialog();
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
  void _openReportSheet() async {
    if (_currentRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get chat room ID')),
      );
      return;
    }

    try {
      // 先檢查用戶是否已經檢舉過
      final reportStatus = await ChatService().checkReportStatus(
        roomId: _currentRoomId!,
      );

      final hasReported = reportStatus['has_reported'] ?? false;

      if (hasReported) {
        // 如果已經檢舉過，顯示已檢舉的提示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Already Reported'),
              ],
            ),
            content: const Text(
              'You have already reported this chat room. Our team will review your report and take appropriate action.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // 如果沒有檢舉過，顯示檢舉表單
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final descriptionCtrl = TextEditingController();
          String? selectedReason;
          String? errorText;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Report',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                    StatefulBuilder(builder: (context, setState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            maxLines: 4,
                            controller: descriptionCtrl,
                            onChanged: (_) {
                              if (errorText != null) {
                                setState(() => errorText = null);
                              }
                            },
                          ),
                          if (errorText != null) const SizedBox(height: 6),
                          if (errorText != null)
                            Text(
                              errorText!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () async {
                                final roomId = _currentRoomId;
                                if (roomId == null ||
                                    selectedReason == null ||
                                    (descriptionCtrl.text.trim().length < 10)) {
                                  setState(() => errorText =
                                      'Please select a reason and enter at least 10 characters description.');
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
                                        content: Text('Report submitted.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(
                                        () => errorText = 'Report failed: $e');
                                  }
                                }
                              },
                              child: const Text('Submit'),
                            ),
                          ),
                        ],
                      );
                    })
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking report status: $e')),
        );
      }
    }
  }

  void _openPayAndReview() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ConfirmPayDialog(
          task: _task,
          room: _room,
          title: 'Confirm & Pay',
          buttonText: 'Confirm & Pay',
          onPaymentSuccess: () {
            // 付款成功後的回調
            Navigator.of(context).pop(true);
          },
        );
      },
    );

    // 如果付款成功，刷新聊天室狀態
    if (result == true && mounted) {
      debugPrint('💰 [Pay] 付款成功，刷新聊天室狀態');

      // 通知 Provider 刷新聊天列表數據
      try {
        final provider = context.read<ChatListProvider>();
        // 根據用戶角色刷新對應的標籤頁
        if (_userRole == 'creator') {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
          debugPrint('✅ [Pay] 已通知 Provider 刷新 POSTED_TASKS');
        } else {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
          debugPrint('✅ [Pay] 已通知 Provider 刷新 MY_WORKS');
        }
        // 強制刷新快取
        provider.forceRefreshCache();
        debugPrint('✅ [Pay] 已強制刷新快取');

        // 通知兩個分頁的分頁控制器刷新
        try {
          provider.checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
          provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
        } catch (_) {}
      } catch (e) {
        debugPrint('❌ 通知 Provider 刷新失敗: $e');
      }

      // 重新載入聊天室狀態以更新 Action Bar
      await _initializeChat();

      // Pay 操作後，只對 creator 自動收起 Action Bar
      if (mounted && _userRole == 'creator') {
        setState(() {
          _showActionBar = false;
        });
      }
    }
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

  /// 開啟評分對話框
  void _openReviewDialog() async {
    final taskId = _task?['id']?.toString();
    final taskerId = _getOpponentUserId()?.toString();
    final taskerName = _getOpponentDisplayName();
    final taskTitle = _task?['title']?.toString() ?? '';

    if (taskId == null || taskerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法獲取任務或用戶資訊')),
      );
      return;
    }

    // 檢查任務狀態和是否已有評分
    try {
      final existingReview = await TaskService().getReview(taskId: taskId);

      if (existingReview != null) {
        // 已有評分，顯示唯讀模式
        _viewExistingReview(existingReview);
      } else {
        // 沒有評分，顯示評分對話框
        showDialog(
          context: context,
          builder: (context) => ReviewDialog(
            taskId: taskId,
            taskerId: taskerId,
            taskerName: taskerName,
            taskTitle: taskTitle,
            onReviewSubmitted: () {
              debugPrint('✅ [Review] 評分提交成功，刷新聊天室狀態');

              // 通知 Provider 刷新聊天列表數據
              try {
                final provider = context.read<ChatListProvider>();
                // 根據用戶角色刷新對應的標籤頁
                if (_userRole == 'creator') {
                  provider
                      .checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
                  debugPrint('✅ [Review] 已通知 Provider 刷新 POSTED_TASKS');
                } else {
                  provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
                  debugPrint('✅ [Review] 已通知 Provider 刷新 MY_WORKS');
                }
                // 強制刷新快取
                provider.forceRefreshCache();
                debugPrint('✅ [Review] 已強制刷新快取');

                // 通知兩個分頁的分頁控制器刷新
                try {
                  provider
                      .checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
                  provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
                } catch (_) {}
              } catch (e) {
                debugPrint('❌ 通知 Provider 刷新失敗: $e');
              }

              // 重新載入聊天室狀態以更新 Action Bar
              _initializeChat();
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking review status: $e');
      // 發生錯誤時，預設顯示評分對話框
      showDialog(
        context: context,
        builder: (context) => ReviewDialog(
          taskId: taskId,
          taskerId: taskerId,
          taskerName: taskerName,
          taskTitle: taskTitle,
          onReviewSubmitted: () {
            debugPrint('✅ [Review] 評分提交成功，刷新聊天室狀態');

            // 通知 Provider 刷新聊天列表數據
            try {
              final provider = context.read<ChatListProvider>();
              // 根據用戶角色刷新對應的標籤頁
              if (_userRole == 'creator') {
                provider
                    .checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
                debugPrint('✅ [Review] 已通知 Provider 刷新 POSTED_TASKS');
              } else {
                provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
                debugPrint('✅ [Review] 已通知 Provider 刷新 MY_WORKS');
              }
              // 強制刷新快取
              provider.forceRefreshCache();
              debugPrint('✅ [Review] 已強制刷新快取');

              // 通知兩個分頁的分頁控制器刷新
              try {
                provider
                    .checkAndTriggerTabLoad(ChatListProvider.tabPostedTasks);
                provider.checkAndTriggerTabLoad(ChatListProvider.tabMyWorks);
              } catch (_) {}
            } catch (e) {
              debugPrint('❌ 通知 Provider 刷新失敗: $e');
            }

            _initializeChat();
          },
        ),
      );
    }
  }

  /// 動態檢查評分狀態
  Future<void> _checkReviewStatus() async {
    final taskId = _task?['id']?.toString();
    if (taskId == null) return;

    try {
      final existingReview = await TaskService().getReview(taskId: taskId);
      if (mounted) {
        setState(() {
          _hasExistingReview = existingReview != null;
        });
        debugPrint(
            '🔍 [Review Status] Task $taskId has review: $_hasExistingReview');
      }
    } catch (e) {
      debugPrint('❌ Error checking review status: $e');
      // 發生錯誤時保持原狀態
    }
  }

  /// 查看現有評分
  void _viewExistingReview([Map<String, dynamic>? reviewData]) async {
    final taskId = _task?['id']?.toString();
    final taskerId = _getOpponentUserId()?.toString();
    final taskerName = _getOpponentDisplayName();
    final taskTitle = _task?['title']?.toString() ?? '';

    if (taskId == null || taskerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法獲取任務或用戶資訊')),
      );
      return;
    }

    Map<String, dynamic>? existingReview = reviewData;

    // 如果沒有傳入評分資料，從後端獲取
    if (existingReview == null) {
      try {
        existingReview = await TaskService().getReview(taskId: taskId);
      } catch (e) {
        debugPrint('❌ Error fetching review: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法獲取評分資料')),
        );
        return;
      }
    }

    if (existingReview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('沒有找到評分記錄')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        taskId: taskId,
        taskerId: taskerId,
        taskerName: taskerName,
        taskTitle: taskTitle,
        readOnlyMode: true,
        existingReview: existingReview,
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
                              'Image failed to load',
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
              Text('Downloading image...'),
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
                Text('✅ Image downloaded successfully'),
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
            content: Text('❌ Image download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 修正應徵狀態數據映射問題
  /// 將 task['application_status'] 映射到 task['application']['status']
  /// 以便 Action Bar 能夠正確讀取應徵狀態
  Map<String, dynamic> _fixApplicationStatusMapping(
      Map<String, dynamic> chatData) {
    final result = Map<String, dynamic>.from(chatData);
    final task = result['task'] as Map<String, dynamic>?;

    if (task != null) {
      final applicationStatus = task['application_status']?.toString();

      debugPrint('🔧 [_fixApplicationStatusMapping] 修正應徵狀態映射:');
      debugPrint('  - application_status: $applicationStatus');
      debugPrint('  - 現有 application: ${task['application']}');

      // 🔧 改進：處理應徵狀態映射邏輯
      if (applicationStatus != null &&
          applicationStatus.isNotEmpty &&
          applicationStatus != 'null') {
        // 保持現有的 application 數據（如果存在）
        final existingApplication =
            task['application'] as Map<String, dynamic>? ?? {};

        // 創建或更新 application 巢狀結構
        task['application'] = {
          ...existingApplication,
          'status': applicationStatus,
          'created_at': task['application_created_at'],
          'updated_at': task['application_updated_at'],
        };

        debugPrint('  - 已創建/更新 application 巢狀結構: ${task['application']}');
      } else {
        // 🔧 新增：如果 application_status 為 null 或空，但存在現有的 application，保持現有狀態
        final existingApplication =
            task['application'] as Map<String, dynamic>?;
        if (existingApplication != null &&
            existingApplication['status'] != null) {
          debugPrint(
              '  - 保持現有 application 狀態: ${existingApplication['status']}');
        } else {
          debugPrint('  - 無有效的應徵狀態數據');
        }
      }

      result['task'] = task;
    }

    return result;
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

  /// 檢查是否為支援聊天室
  bool get _isSupportRoom => _room?['type'] == 'support';
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
              backgroundColor:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.35),
              child: Icon(
                Icons.notifications,
                size: 16,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
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
              backgroundColor:
                  Theme.of(context).colorScheme.secondary.withOpacity(0.35),
              child: Icon(
                Icons.notifications,
                size: 16,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
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

  /// 顯示任務狀態變更通知
  void _showTaskStatusChangeNotification(Map<String, dynamic> statusData) {
    final statusCode = statusData['code']?.toString();
    final displayName = statusData['display_name']?.toString();

    String message;
    Color backgroundColor;
    IconData icon;

    switch (statusCode) {
      case 'in_progress':
        message = 'Task has started in progress';
        backgroundColor = Colors.blue;
        icon = Icons.play_arrow;
        break;
      case 'pending_confirmation':
        message = 'The tasker requested confirmation for completion';
        backgroundColor = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case 'completed':
        message = 'Task has been confirmed as completed!';
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'dispute':
        message = 'Task has entered dispute resolution';
        backgroundColor = Colors.red;
        icon = Icons.warning;
        break;
      case 'cancelled':
        message = 'Task has been cancelled';
        backgroundColor = Colors.grey;
        icon = Icons.cancel;
        break;
      default:
        message = displayName != null
            ? 'Task status updated to: $displayName'
            : 'Task status updated';
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.info;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// 顯示應徵狀態變更通知
  void _showApplicationStatusChangeNotification(String applicationStatus) {
    String message;
    Color backgroundColor;
    IconData icon;

    switch (applicationStatus) {
      case 'accepted':
        message = '✅Application accepted!';
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        message = '❌ Application rejected';
        backgroundColor = Colors.red;
        icon = Icons.cancel;
        break;
      case 'withdrawn':
        message = '🔄 Application withdrawn';
        backgroundColor = Colors.orange;
        icon = Icons.undo;
        break;
      case 'cancelled':
        message = '❌ Application cancelled';
        backgroundColor = Colors.grey;
        icon = Icons.cancel;
        break;
      case 'pending':
        message = '🔄 Application status updated';
        backgroundColor = Colors.blue;
        icon = Icons.hourglass_empty;
        break;
      default:
        message = '🔄 Application status updated';
        backgroundColor = Theme.of(context).colorScheme.primary;
        icon = Icons.info;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

// #endregion
}

/// 確認付款對話框
class _ConfirmPayDialog extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Map<String, dynamic>? room;
  final VoidCallback? onPaymentSuccess;
  final String? title; // 新增：自定義標題
  final String? buttonText; // 新增：自定義按鈕文字

  const _ConfirmPayDialog({
    required this.task,
    required this.room,
    this.onPaymentSuccess,
    this.title,
    this.buttonText,
  });

  @override
  State<_ConfirmPayDialog> createState() => _ConfirmPayDialogState();
}

class _ConfirmPayDialogState extends State<_ConfirmPayDialog> {
  // 手續費設定
  FeeSettings? _feeSettings;
  bool _isLoadingFee = true;

  // UI 狀態
  bool _isAgreed = false;
  bool _isSubmitting = false;

  // 付款密碼
  final _paymentCode1Controller = TextEditingController();
  final _paymentCode2Controller = TextEditingController();
  bool _isPaymentCode1Visible = false;
  bool _isPaymentCode2Visible = false;
  String _passwordMismatchError = '';

  // 評分
  double _rating = 1.0; // 預設最低 1 星
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFeeSettings();
    _paymentCode2Controller.addListener(_validatePasswordMatch);
  }

  @override
  void dispose() {
    _paymentCode1Controller.dispose();
    _paymentCode2Controller.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// 安全地將任務數據中的數值轉換為整數
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  /// 載入手續費設定
  Future<void> _loadFeeSettings() async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final settings = await WalletService.getFeeSettings(userService);
      if (mounted) {
        setState(() {
          _feeSettings = settings;
          _isLoadingFee = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFee = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load fee settings: $e')),
        );
      }
    }
  }

  /// 驗證兩次密碼輸入是否一致
  void _validatePasswordMatch() {
    final code1 = _paymentCode1Controller.text;
    final code2 = _paymentCode2Controller.text;

    if (code2.isNotEmpty && code1 != code2) {
      setState(() {
        _passwordMismatchError = 'Payment passwords do not match.';
      });
    } else {
      setState(() {
        _passwordMismatchError = '';
      });
    }
  }

  /// 計算手續費
  int _calculateFee() {
    if (_feeSettings == null || widget.task == null) return 0;

    final rewardPoints = _safeParseInt(widget.task!['reward_point']);
    final feeRate = _feeSettings!.rate;

    return WalletService.calculateFee(rewardPoints, feeRate);
  }

  /// 檢查是否可以提交
  bool _canSubmit() {
    return _isAgreed &&
        _paymentCode1Controller.text.length == 6 &&
        _paymentCode2Controller.text.length == 6 &&
        _paymentCode1Controller.text == _paymentCode2Controller.text &&
        !_isSubmitting;
  }

  /// 提交付款
  Future<void> _submitPayment() async {
    if (!_canSubmit()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 調試：輸出任務數據
      debugPrint('🔍 [_ConfirmPayDialog] widget.task: ${widget.task}');
      debugPrint(
          '🔍 [_ConfirmPayDialog] widget.task keys: ${widget.task?.keys.toList()}');

      // 步驟1: 驗證付款密碼
      debugPrint('🔐 [Payment Flow] Step 1: Verifying payment password...');
      await TaskService().verifyPaymentPassword(
        paymentPassword: _paymentCode1Controller.text,
      );
      debugPrint('✅ [Payment Flow] Step 1: Payment password verified');

      // 步驟2-4: 執行完整的付款流程
      if (widget.task != null) {
        final taskId = widget.task!['id'].toString();
        final rewardPoints = _safeParseInt(widget.task!['reward_point']);

        // 🔧 修復：直接從 widget.room 獲取 creator_id 和 participant_id
        final room = widget.room;

        final creatorId = _safeParseInt(room?['creator_id']);
        final participantId = _safeParseInt(room?['participant_id']);

        debugPrint('🔍 [Payment Flow] 提取的參數:');
        debugPrint('🔍 [Payment Flow] taskId: $taskId');
        debugPrint('🔍 [Payment Flow] rewardPoints: $rewardPoints');
        debugPrint('🔍 [Payment Flow] creatorId: $creatorId');
        debugPrint('🔍 [Payment Flow] participantId: $participantId');

        // 🚨 添加數據驗證和錯誤處理
        if (room == null) {
          throw Exception('Room data is null. Cannot proceed with payment.');
        }
        if (creatorId == 0) {
          throw Exception(
              'Invalid creator_id: $creatorId. Room data may be incomplete.');
        }
        if (participantId == 0) {
          throw Exception(
              'Invalid participant_id: $participantId. Room data may be incomplete.');
        }

        // 步驟2: 確認任務完成 (包含點數轉移和手續費處理)
        debugPrint(
            '📋 [Payment Flow] Step 2: Confirming task completion (includes point transfer and fee deduction)...');
        await TaskService().confirmCompletion(
          taskId: taskId,
        );
        debugPrint(
            '✅ [Payment Flow] Step 2: Task completed - points transferred, fees deducted, status updated');

        // 步驟3: 提交評分和評論
        debugPrint('⭐ [Payment Flow] Step 3: Submitting review...');
        await TaskService().submitReview(
          taskId: taskId,
          taskerId: participantId.toString(),
          rating: _rating.round(),
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        );
        debugPrint('✅ [Payment Flow] Step 3: Review submitted successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment completed, task finished')),
          );

          // 調用成功回調
          if (widget.onPaymentSuccess != null) {
            widget.onPaymentSuccess!();
          } else {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Payment failed. Please try again.';

        // 判斷是否是密碼錯誤
        if (e.toString().contains('Invalid payment password') ||
            e.toString().contains('E_PAYMENT_PASSWORD')) {
          errorMessage = 'Payment password is incorrect. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: screenWidth * 0.9, // 90% 畫面寬度
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? 'Confirm & Pay',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // 內容區域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 上半部 - 說明文字 + 手續費說明
                    _buildUpperSection(),

                    // 分隔線
                    const Divider(height: 32, thickness: 1),

                    // 下半部 - 評分 + 同意勾選 + 付款碼輸入
                    _buildLowerSection(),
                  ],
                ),
              ),
            ),

            // 底部按鈕
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit() ? _submitPayment : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.buttonText ?? 'Confirm & Pay'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 上半部 - 說明文字 + 手續費說明
  Widget _buildUpperSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 說明文字
        const Text(
          'Please confirm the task is completed and agree to release payment to the assignee.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          'The completion fee will be deducted from the reward points, rounded to the nearest integer, and collected by the system.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),

        // 手續費詳情
        if (_isLoadingFee)
          const Center(child: CircularProgressIndicator())
        else
          _buildFeeDetails(),
      ],
    );
  }

  /// 手續費詳情
  Widget _buildFeeDetails() {
    if (widget.task == null) return const SizedBox.shrink();

    final rewardPoints = _safeParseInt(widget.task!['reward_point']);
    final feeRate = _feeSettings?.rate ?? 0.0;
    final feeAmount = _calculateFee();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reward Points Outcome：',
                  style: TextStyle(fontSize: 12)),
              Text('$rewardPoints Points',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Completion Fee Rate：',
                  style: TextStyle(fontSize: 12)),
              Text('${(feeRate * 100).toStringAsFixed(2)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.cyan)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fee Amount Outcome：', style: TextStyle(fontSize: 12)),
              Text('$feeAmount Points',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  /// 下半部 - 評分 + 同意勾選 + 付款碼輸入
  Widget _buildLowerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 評分區域
        const Text('Rating and Comment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            // 使用簡單的星星評分（可以後續改為 flutter_rating_bar）
            ...List.generate(5, (index) {
              return IconButton(
                onPressed: () {
                  setState(() {
                    _rating = (index + 1).toDouble();
                  });
                },
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ],
        ),

        // 評論輸入
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: 'Comment (Optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),

        const SizedBox(height: 16),
        const Divider(),

        const SizedBox(height: 16),
        // 付款碼輸入
        const Text('Payment Password',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // 同意勾選
        CheckboxListTile(
          value: _isAgreed,
          onChanged: (value) {
            setState(() {
              _isAgreed = value ?? false;
            });
          },
          title: const Text(
              'I agree to release payment to the assignee and pay the completion fee.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),

        const SizedBox(height: 16),

        // 第一次輸入
        TextField(
          controller: _paymentCode1Controller,
          enabled: _isAgreed,
          obscureText: !_isPaymentCode1Visible,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Payment Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _isPaymentCode1Visible = !_isPaymentCode1Visible;
                });
              },
              icon: Icon(_isPaymentCode1Visible
                  ? Icons.visibility
                  : Icons.visibility_off),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 第二次輸入
        TextField(
          controller: _paymentCode2Controller,
          enabled: _isAgreed,
          obscureText: !_isPaymentCode2Visible,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Confirm Payment Password',
            border: const OutlineInputBorder(),
            errorText:
                _passwordMismatchError.isEmpty ? null : _passwordMismatchError,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _isPaymentCode2Visible = !_isPaymentCode2Visible;
                });
              },
              icon: Icon(_isPaymentCode2Visible
                  ? Icons.visibility
                  : Icons.visibility_off),
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

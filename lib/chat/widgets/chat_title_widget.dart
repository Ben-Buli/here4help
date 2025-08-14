import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/chat/widgets/task_appbar_title.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/chat/services/chat_service.dart';

/// 聊天室標題組件，只負責提供 titleWidget
class ChatTitleWidget extends StatefulWidget {
  const ChatTitleWidget({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  State<ChatTitleWidget> createState() => _ChatTitleWidgetState();
}

class _ChatTitleWidgetState extends State<ChatTitleWidget> {
  Map<String, dynamic>? _chatData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 ChatTitleWidget.initState()');
    _checkUserInfo();
    _init();
  }

  Future<void> _checkUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final userId = prefs.getInt('user_id'); // 修正：user_id 是整數
      debugPrint('🔍 當前用戶信息: email=$email, userId=$userId');
    } catch (e) {
      debugPrint('❌ 無法獲取用戶信息: $e');
    }
  }

  Future<void> _init() async {
    debugPrint('🔍 ChatTitleWidget._init() 開始');
    debugPrint('🔍 widget.data: ${widget.data}');

    Map<String, dynamic>? data = widget.data;

    // 總是嘗試從會話管理器和本地儲存恢復，因為 titleWidgetBuilder 可能不會收到 state.extra
    debugPrint('🔍 嘗試從會話管理器和本地儲存恢復數據');

    // 1. 先檢查會話管理器
    final sessionData = await ChatSessionManager.getCurrentChatSession();
    if (sessionData != null && sessionData.isNotEmpty) {
      debugPrint('✅ 從會話管理器恢復數據');
      data = sessionData;
    } else {
      // 2. 檢查本地儲存
      try {
        final location = GoRouterState.of(context).uri.toString();
        debugPrint('🔍 當前位置: $location');

        final roomId = ChatStorageService.extractRoomIdFromUrl(location);
        debugPrint('🔍 提取的 roomId: $roomId');

        if (roomId != null) {
          final storedData = await ChatStorageService.getChatRoomData(roomId);
          debugPrint('🔍 從本地儲存獲取的數據: $storedData');

          // 使用本地儲存的數據
          if (storedData != null && storedData.isNotEmpty) {
            data = storedData;
            debugPrint('✅ 使用本地儲存的數據');
          } else {
            // 本地沒有，嘗試最小訊息讀取確保房間存在（不阻塞 UI）
            try {
              await ChatService().getMessages(roomId: roomId);
            } catch (_) {}
          }
        } else {
          debugPrint('❌ 無法從 URL 提取 roomId');
        }
      } catch (e) {
        debugPrint('❌ 無法存取 GoRouterState in ChatTitleWidget: $e');
      }
    }

    // 如果仍然沒有數據，使用傳入的數據（如果有的話）
    if ((data == null || data.isEmpty) && widget.data != null) {
      data = widget.data;
      debugPrint('✅ 使用傳入的數據作為後備');
    }

    debugPrint('🔍 最終使用的數據: $data');

    // 從 room/chatPartnerInfo 推導並補齊 userRole（如果缺）
    if (data != null) {
      final room = (data['room'] as Map<String, dynamic>?) ?? {};
      // 若 URL 有 roomId，但 data['room'] 沒有 id，補齊
      try {
        final location = GoRouterState.of(context).uri.toString();
        final urlRoomId = ChatStorageService.extractRoomIdFromUrl(location);
        if (urlRoomId != null &&
            (room['id'] == null && room['roomId'] == null)) {
          room['id'] = urlRoomId;
          room['roomId'] = urlRoomId;
          data['room'] = room;
        }
      } catch (_) {}
      // 若未顯式提供 userRole，根據當前用戶與 room 的 creator/participant 關係推導
      if ((data['userRole'] == null ||
          (data['userRole'] as String?)?.isEmpty == true)) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final myId = prefs.getInt('user_id');
          final creatorId = room['creator_id'] ?? room['creatorId'];
          if (myId != null && creatorId != null) {
            final int? creator =
                (creatorId is int) ? creatorId : int.tryParse('$creatorId');
            if (creator != null) {
              data['userRole'] = (creator == myId) ? 'creator' : 'participant';
            }
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _chatData = data;
      _loading = false;
    });

    debugPrint('🔍 ChatTitleWidget._init() 完成，_chatData: $_chatData');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 ChatTitleWidget.build() 開始');
    debugPrint('🔍 _loading: $_loading');
    debugPrint('🔍 _chatData: $_chatData');
    debugPrint('🔍 _chatData == null: ${_chatData == null}');
    debugPrint('🔍 _chatData!.isEmpty: ${_chatData?.isEmpty}');

    if (_loading) {
      debugPrint('⏳ 顯示 Loading 標題');
      return const Text('Loading...');
    }

    if (_chatData == null || _chatData!.isEmpty) {
      debugPrint('❌ 顯示預設 Chat Detail 標題，因為 _chatData 為空');
      return const Text('Chat Detail');
    }

    debugPrint('✅ 有數據，準備建構 TaskAppBarTitle');

    final task =
        (_chatData!['task'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final room =
        (_chatData!['room'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final userRole = _chatData!['userRole'] as String? ?? '';
    final chatPartnerInfo =
        (_chatData!['chatPartnerInfo'] as Map<String, dynamic>?) ?? {};

    debugPrint('🔍 task: $task');
    debugPrint('🔍 room: $room');
    debugPrint('🔍 userRole: $userRole');
    debugPrint('🔍 chatPartnerInfo: $chatPartnerInfo');

    // 判斷當前用戶角色並確定聊天夥伴
    String partnerName = 'Chat Partner';
    Map<String, dynamic> effectiveChatPartnerInfo = {};

    // 優先從 room 的 chat_partner 取得聊天對象資訊
    if (room['chat_partner'] != null) {
      final chatPartner = room['chat_partner'] as Map<String, dynamic>;
      partnerName = chatPartner['name'] as String? ?? 'Task Creator';
      effectiveChatPartnerInfo = chatPartner;
      debugPrint('🔍 使用 room.chat_partner: $partnerName');
    }
    // 次要選項：從 chatPartnerInfo 取得
    else if (chatPartnerInfo.isNotEmpty) {
      partnerName = chatPartnerInfo['name'] as String? ?? 'Chat Partner';
      effectiveChatPartnerInfo = chatPartnerInfo;
      debugPrint('🔍 使用 chatPartnerInfo: $partnerName');
    }
    // 最後選項：從 room 的其他欄位取得
    else {
      partnerName = room['name'] as String? ??
          room['participant_name'] as String? ??
          task['creator_name'] as String? ??
          'Chat Partner';
      debugPrint('🔍 使用 room 其他欄位: $partnerName');
    }

    final rating = (effectiveChatPartnerInfo['rating'] as num?)?.toDouble() ??
        (room['rating'] as num?)?.toDouble();
    final reviewsCount = effectiveChatPartnerInfo['reviewsCount'] as int? ??
        room['reviewsCount'] as int?;

    debugPrint('🔍 最終 partnerName: $partnerName');
    debugPrint('🔍 task title: ${task['title']}');

    return TaskAppBarTitle(
      task: task,
      chatPartnerName: partnerName,
      userRole: userRole,
      chatPartnerInfo: effectiveChatPartnerInfo,
      rating: rating,
      reviewsCount: reviewsCount,
    );
  }
}

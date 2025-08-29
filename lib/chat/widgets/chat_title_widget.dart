import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/chat/widgets/task_appbar_title.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';

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
    debugPrint('🔍 widget.data: ${widget.data}');

    // 如果有 widget.data，立即設置初始狀態
    if (widget.data != null && widget.data!.isNotEmpty) {
      setState(() {
        _chatData = widget.data;
        _loading = false;
      });
      debugPrint('✅ 立即設置初始 _chatData: ${widget.data}');
    }

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

    // 確保 data 不為 null
    if (data == null) {
      data = <String, dynamic>{};
      debugPrint('⚠️ 沒有可用數據，使用空 Map');
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
    debugPrint('🔍 _chatData?.isEmpty: ${_chatData?.isEmpty}');

    // 如果正在載入，顯示載入狀態
    if (_loading) {
      debugPrint('⏳ 顯示 Loading 標題');
      return const Text('Loading...');
    }

    // 如果 _chatData 為空但有 widget.data，嘗試使用 widget.data
    if ((_chatData == null || _chatData!.isEmpty) && widget.data != null) {
      debugPrint('🔄 使用 widget.data 作為臨時數據');
      final tempData = widget.data!;

      // 嘗試從 widget.data 構建臨時標題
      final task = tempData['task'] as Map<String, dynamic>?;
      final room = tempData['room'] as Map<String, dynamic>?;

      if (task != null && task['title'] != null) {
        debugPrint('✅ 使用 widget.data 中的任務標題');
        return Text(task['title'].toString());
      } else if (room != null) {
        debugPrint('✅ 使用 widget.data 中的房間信息');
        return const Text('Chat Room');
      }
    }

    // 如果 _chatData 為空且沒有可用的 widget.data
    if (_chatData == null || _chatData!.isEmpty) {
      debugPrint('❌ 顯示預設 Chat Detail 標題，因為 _chatData 為空');
      debugPrint('🔍 widget.data: ${widget.data}');
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

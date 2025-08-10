import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/chat/widgets/task_appbar_title.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';

/// 聊天室 AppBar 組件，支援從 SharedPreferences 恢復數據
class ChatAppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  const ChatAppBarWidget({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  State<ChatAppBarWidget> createState() => _ChatAppBarWidgetState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);
}

class _ChatAppBarWidgetState extends State<ChatAppBarWidget> {
  Map<String, dynamic>? _chatData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 ChatAppBarWidget.initState()');
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
    debugPrint('🔍 ChatAppBarWidget._init() 開始');
    debugPrint('🔍 widget.data: ${widget.data}');

    Map<String, dynamic>? data = widget.data;

    // 總是嘗試從本地儲存恢復，因為 appBarBuilder 可能不會收到 state.extra
    debugPrint('🔍 嘗試從本地儲存恢復數據');
    try {
      final location = GoRouterState.of(context).uri.toString();
      debugPrint('🔍 當前位置: $location');

      final roomId = ChatStorageService.extractRoomIdFromUrl(location);
      debugPrint('🔍 提取的 roomId: $roomId');

      if (roomId != null) {
        final storedData = await ChatStorageService.getChatRoomData(roomId);
        debugPrint('🔍 從本地儲存獲取的數據: $storedData');

        // 優先使用本地儲存的數據，因為它包含完整的信息
        if (storedData != null && storedData.isNotEmpty) {
          data = storedData;
          debugPrint('✅ 使用本地儲存的數據');
        }
      } else {
        debugPrint('❌ 無法從 URL 提取 roomId');
      }
    } catch (e) {
      debugPrint('❌ 無法存取 GoRouterState in ChatAppBarWidget: $e');
    }

    // 如果仍然沒有數據，使用傳入的數據（如果有的話）
    if ((data == null || data.isEmpty) && widget.data != null) {
      data = widget.data;
      debugPrint('✅ 使用傳入的數據作為後備');
    }

    debugPrint('🔍 最終使用的數據: $data');

    if (!mounted) return;
    setState(() {
      _chatData = data;
      _loading = false;
    });

    debugPrint('🔍 ChatAppBarWidget._init() 完成，_chatData: $_chatData');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 ChatAppBarWidget.build() 開始');
    debugPrint('🔍 _loading: $_loading');
    debugPrint('🔍 _chatData: $_chatData');
    debugPrint('🔍 _chatData == null: ${_chatData == null}');
    debugPrint('🔍 _chatData!.isEmpty: ${_chatData?.isEmpty}');

    if (_loading) {
      debugPrint('⏳ 顯示 Loading AppBar');
      return AppBar(
        title: const Text('Loading...'),
        toolbarHeight: kToolbarHeight + 8,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[300]),
        ),
      );
    }
    if (_chatData == null || _chatData!.isEmpty) {
      debugPrint('❌ 顯示預設 Chat Detail AppBar，因為 _chatData 為空');
      return AppBar(
        title: const Text('Chat Detail'),
        toolbarHeight: kToolbarHeight + 8,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[300]),
        ),
      );
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

    // 優先從 chatPartnerInfo 取得聊天對象名稱，如果沒有則從 room 取得
    final partnerName = chatPartnerInfo['name'] as String? ??
        room['name'] as String? ??
        room['participant_name'] as String? ??
        'Chat Partner';
    final rating = (room['rating'] as num?)?.toDouble();
    final reviewsCount = room['reviewsCount'] as int?;

    debugPrint('🔍 最終 partnerName: $partnerName');
    debugPrint('🔍 task title: ${task['title']}');

    return AppBar(
      title: TaskAppBarTitle(
        task: task,
        chatPartnerName: partnerName,
        userRole: userRole,
        chatPartnerInfo: chatPartnerInfo,
        rating: rating,
        reviewsCount: reviewsCount,
      ),
      toolbarHeight: kToolbarHeight + 8,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.grey[300]),
      ),
    );
  }
}

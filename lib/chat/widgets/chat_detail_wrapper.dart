import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/chat/pages/chat_detail_page.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/layout/app_scaffold.dart';

/// 聊天詳細頁面包裝器，處理數據恢復邏輯
class ChatDetailWrapper extends StatefulWidget {
  const ChatDetailWrapper({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  State<ChatDetailWrapper> createState() => _ChatDetailWrapperState();
}

class _ChatDetailWrapperState extends State<ChatDetailWrapper> {
  Map<String, dynamic>? _chatData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeChatData();
  }

  Future<void> _initializeChatData() async {
    try {
      debugPrint('🔍 ChatDetailWrapper._initializeChatData() 開始');
      debugPrint('🔍 widget.data: ${widget.data}');

      Map<String, dynamic>? chatData = widget.data;

      // 如果沒有傳入的數據，先檢查會話管理器，然後是本地儲存
      if (chatData == null || chatData.isEmpty) {
        debugPrint('🔍 沒有傳入數據，嘗試從會話和本地儲存恢復');

        // 1. 先檢查當前會話
        final sessionData = await ChatSessionManager.getCurrentChatSession();
        if (sessionData != null && sessionData.isNotEmpty) {
          debugPrint('✅ 從會話管理器恢復數據');
          chatData = sessionData;
        } else {
          // 2. 如果會話中沒有，嘗試從本地儲存恢復
          try {
            final location = GoRouterState.of(context).uri.toString();
            debugPrint('🔍 當前位置: $location');

            final roomId = ChatStorageService.extractRoomIdFromUrl(location);
            debugPrint('🔍 提取的 roomId: $roomId');

            if (roomId != null) {
              final storedData =
                  await ChatStorageService.getChatRoomData(roomId);
              debugPrint('🔍 從本地儲存獲取的數據: $storedData');

              if (storedData != null && storedData.isNotEmpty) {
                chatData = storedData;
                debugPrint('✅ 使用本地儲存的數據');
              } else {
                debugPrint('ℹ️ 本地儲存中沒有數據，將構造最小數據集');
                // 構造最小數據集，包含 room_id
                chatData = {
                  'room': {
                    'id': roomId,
                    'roomId': roomId,
                  },
                  'task': {},
                  'userRole': 'participant',
                  'chatPartnerInfo': {},
                };
              }
            } else {
              debugPrint('❌ 無法從 URL 提取 roomId');
              chatData = null;
            }
          } catch (e) {
            debugPrint('❌ 無法存取 GoRouterState in ChatDetailWrapper: $e');
            chatData = null;
          }
        }
      } else {
        debugPrint('✅ 使用傳入的數據');
        // 如果有傳入數據，也設置為當前會話
        final roomId = chatData['room']?['id']?.toString() ?? 'unknown';
        final previousRoute = AppScaffold.getPreviousValidRoute();
        await ChatSessionManager.setCurrentChatSession(
          roomId: roomId,
          room: chatData['room'] ?? {},
          task: chatData['task'] ?? {},
          userRole: chatData['userRole'] ?? '',
          chatPartnerInfo: chatData['chatPartnerInfo'] ?? {},
          sourceTab: chatData['sourceTab']?.toString(),
          returnPath: (chatData['returnPath'] ?? previousRoute)?.toString(),
        );
        debugPrint('✅ 已將傳入數據設置為當前會話');
      }

      if (mounted) {
        setState(() {
          _chatData = chatData;
          _isLoading = false;
          // 即使沒有數據也不設置為錯誤，讓 ChatDetailPage 自己處理
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });

        // 發生錯誤，2秒後重定向
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            GoRouter.of(context).go('/chat');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在載入聊天室...'),
            ],
          ),
        ),
      );
    }

    // 即使沒有數據也渲染 ChatDetailPage，讓它自己處理數據載入
    return ChatDetailPage(data: _chatData);
  }
}

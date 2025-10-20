import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/account/pages/support_chat_detail_page.dart';
import 'package:here4help/chat/services/support_chat_storage_service.dart';
import 'package:here4help/chat/services/support_chat_session_manager.dart';
import 'package:here4help/layout/app_scaffold.dart';

/// 聊天詳細頁面包裝器，處理數據恢復邏輯
class SupportChatDetailWrapper extends StatefulWidget {
  const SupportChatDetailWrapper({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  State<SupportChatDetailWrapper> createState() =>
      _SupportChatDetailWrapperState();
}

class _SupportChatDetailWrapperState extends State<SupportChatDetailWrapper> {
  Map<String, dynamic>? _chatData;
  bool _isLoading = true;

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
      bool shouldUpdateSession = false;

      if (chatData == null || chatData.isEmpty) {
        debugPrint('🔍 沒有傳入數據，嘗試從會話和本地儲存恢復');

        // 1. 先檢查當前會話
        final sessionData = await ChatSessionManager.getCurrentChatSession();
        if (sessionData != null && sessionData.isNotEmpty) {
          debugPrint('✅ 從會話管理器恢復數據');
          chatData = sessionData;
          shouldUpdateSession = true;
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
                shouldUpdateSession = true;
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
                  'sourceTab': 'support',
                };
                shouldUpdateSession = true;
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
        final previousRoute =
            AppScaffold.getPreviousValidRoute() ?? '/account/support';
        await ChatSessionManager.setCurrentChatSession(
          roomId: roomId,
          room: chatData['room'] ?? {},
          task: chatData['task'] ?? {},
          userRole: chatData['userRole'] ?? '',
          chatPartnerInfo: chatData['chatPartnerInfo'] ?? {},
          sourceTab: (chatData['sourceTab'] ?? 'support').toString(),
          returnPath: (chatData['returnPath'] ?? previousRoute).toString(),
        );
        debugPrint('✅ 已將傳入數據設置為當前會話');
        shouldUpdateSession = false; // 已在此處設定
      }

      if (chatData != null && shouldUpdateSession) {
        final room = chatData['room'] ?? {};
        final task = chatData['task'] ?? {};
        final chatPartnerInfo = chatData['chatPartnerInfo'] ?? {};
        final userRole = (chatData['userRole'] ?? 'participant').toString();
        final roomId = room['id']?.toString() ?? room['roomId']?.toString();

        if (roomId != null && roomId.isNotEmpty) {
          final previousRoute =
              AppScaffold.getPreviousValidRoute() ?? '/account/support';
          final sourceTab = (chatData['sourceTab'] ?? 'support').toString();
          final returnPath =
              (chatData['returnPath'] ?? previousRoute).toString();

          await ChatSessionManager.setCurrentChatSession(
            roomId: roomId,
            room: room,
            task: task,
            userRole: userRole,
            chatPartnerInfo: chatPartnerInfo,
            sourceTab: sourceTab,
            returnPath: returnPath,
          );
          debugPrint('✅ Chat session updated for roomId: $roomId');
        }
      }

      if (mounted) {
        setState(() {
          _chatData = chatData;
          _isLoading = false;
          // 即使沒有數據也不設置為錯誤，讓 ChatDetailPage 自己處理
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    return SupportChatDetailPage(data: _chatData);
  }
}

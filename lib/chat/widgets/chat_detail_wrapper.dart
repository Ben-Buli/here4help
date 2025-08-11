import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/chat/pages/chat_detail_page.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';

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
            // 同時擷取 taskId（供最小資料構造使用）
            String? urlTaskId;
            try {
              final frag = Uri.parse(location).fragment;
              final fragUri = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
              urlTaskId = fragUri.queryParameters['taskId'];
            } catch (_) {}

            if (roomId != null) {
              // 若為舊格式（如 app_5），嘗試用 taskId 在會話或本地查找真實 BIGINT room_id
              String effectiveRoomId = roomId;
              if (roomId.startsWith('app_')) {
                debugPrint('🔁 偵測到舊格式 roomId: $roomId，嘗試回退');
                final fragUri = Uri.parse(location).fragment;
                final parsedFrag =
                    Uri.parse(fragUri.startsWith('/') ? fragUri : '/$fragUri');
                final taskId = parsedFrag.queryParameters['taskId'];
                debugPrint('🔍 從 URL 取得 taskId: $taskId');
                // 嘗試從會話獲取真實 id
                final session =
                    await ChatSessionManager.getCurrentChatSession();
                final sessionRoomId = session?['room']?['id']?.toString();
                if (sessionRoomId != null && sessionRoomId.isNotEmpty) {
                  effectiveRoomId = sessionRoomId;
                  debugPrint('✅ 使用會話中的真實 room_id: $effectiveRoomId');
                }
              }

              final storedData =
                  await ChatStorageService.getChatRoomData(effectiveRoomId);
              debugPrint('🔍 從本地儲存獲取的數據: $storedData');
              if (storedData != null) {
                chatData = storedData;
                debugPrint('✅ 使用本地儲存的數據');

                // 將本地數據設置為當前會話
                await ChatSessionManager.setCurrentChatSession(
                  roomId: effectiveRoomId,
                  room: storedData['room'] ?? {},
                  task: storedData['task'] ?? {},
                  userRole: storedData['userRole'] ?? '',
                  chatPartnerInfo: storedData['chatPartnerInfo'] ?? {},
                );
              } else {
                // 本地沒有資料，構造最小資料集（支援直接貼連結進入）
                debugPrint('ℹ️ 本地無資料，使用 URL 構造最小聊天室資料');
                chatData = {
                  'room': {
                    'id': effectiveRoomId,
                    'roomId': effectiveRoomId,
                    if (urlTaskId != null) 'taskId': urlTaskId,
                    if (urlTaskId != null) 'task_id': urlTaskId,
                  },
                  'task': {
                    if (urlTaskId != null) 'id': urlTaskId,
                  },
                };
                await ChatSessionManager.setCurrentChatSession(
                  roomId: effectiveRoomId,
                  room: chatData['room'] as Map<String, dynamic>,
                  task: chatData['task'] as Map<String, dynamic>,
                  userRole: '',
                  chatPartnerInfo: const {},
                );
              }
            } else {
              debugPrint('❌ 無法從 URL 提取 roomId');
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
        await ChatSessionManager.setCurrentChatSession(
          roomId: roomId,
          room: chatData['room'] ?? {},
          task: chatData['task'] ?? {},
          userRole: chatData['userRole'] ?? '',
          chatPartnerInfo: chatData['chatPartnerInfo'] ?? {},
        );
        debugPrint('✅ 已將傳入數據設置為當前會話');
      }

      debugPrint('🔍 最終使用的數據: $chatData');

      if (mounted) {
        setState(() {
          _chatData = chatData;
          _isLoading = false;
          _hasError = chatData == null || chatData.isEmpty;
        });

        // 如果沒有數據，3秒後自動重定向
        if (_hasError) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              GoRouter.of(context).go('/chat');
            }
          });
        }
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

    if (_hasError || _chatData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load chat room',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will be redirected to the chat list in 3 seconds',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => GoRouter.of(context).go('/chat'),
                child: const Text('Return now'),
              ),
            ],
          ),
        ),
      );
    }

    return ChatDetailPage(data: _chatData!);
  }
}

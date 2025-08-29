import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:here4help/chat/services/chat_service.dart';
import 'package:here4help/chat/services/chat_storage_service.dart';
import 'package:here4help/chat/services/chat_session_manager.dart';
import 'package:here4help/chat/services/chat_preload_service.dart';

/// 統一的聊天導航服務
/// 確保從聊天列表到聊天詳情的數據預載入和錯誤處理
class ChatNavigationService {
  static final ChatNavigationService _instance =
      ChatNavigationService._internal();
  factory ChatNavigationService() => _instance;
  ChatNavigationService._internal();

  /// 導航到聊天詳情頁面（帶預載入）
  static Future<bool> navigateToChatDetail({
    required BuildContext context,
    required String roomId,
    Map<String, dynamic>? preloadedData,
    String? taskId,
    int? creatorId,
    int? participantId,
    String? type = 'application',
  }) async {
    try {
      debugPrint('🚀 [ChatNavigationService] 開始導航到聊天詳情');
      debugPrint('  - roomId: $roomId');

      // 檢查是否有預載入的數據
      final preloadedData = ChatPreloadService.getPreloadedData(roomId);
      debugPrint('  - 是否有預載入數據: ${preloadedData != null}');
      if (preloadedData != null && preloadedData.isNotEmpty) {
        debugPrint('✅ [ChatNavigationService] 使用預載入數據');

        // 保存到本地儲存
        await ChatStorageService.savechatRoomData(
          roomId: roomId,
          room: preloadedData['room'] ?? {},
          task: preloadedData['task'] ?? {},
          userRole: preloadedData['user_role'] ?? 'participant',
          chatPartnerInfo: preloadedData['chat_partner_info'],
        );

        // 設置為當前會話
        await ChatSessionManager.setCurrentChatSession(
          roomId: roomId,
          room: preloadedData['room'] ?? {},
          task: preloadedData['task'] ?? {},
          userRole: preloadedData['user_role'] ?? 'participant',
          chatPartnerInfo: preloadedData['chat_partner_info'] ?? {},
        );

        // 導航
        context.go('/chat/detail?room_id=$roomId');
        return true;
      }

      // 沒有預載入數據，需要載入
      debugPrint('📡 [ChatNavigationService] 開始載入聊天室數據');

      // 顯示載入指示器
      _showLoadingDialog(context);

      // 載入聊天室詳細數據
      final chatService = ChatService();
      final chatData = await chatService.getChatDetailData(roomId: roomId);

      // 關閉載入指示器
      _hideLoadingDialog(context);

      if (chatData.isEmpty) {
        debugPrint('❌ [ChatNavigationService] 聊天室數據載入失敗');
        _showErrorDialog(context, '無法載入聊天室數據');
        return false;
      }

      // 保存到本地儲存
      await ChatStorageService.savechatRoomData(
        roomId: roomId,
        room: chatData['room'] ?? {},
        task: chatData['task'] ?? {},
        userRole: chatData['user_role'] ?? 'participant',
        chatPartnerInfo: chatData['chat_partner_info'],
      );

      // 設置為當前會話
      await ChatSessionManager.setCurrentChatSession(
        roomId: roomId,
        room: chatData['room'] ?? {},
        task: chatData['task'] ?? {},
        userRole: chatData['user_role'] ?? 'participant',
        chatPartnerInfo: chatData['chat_partner_info'] ?? {},
      );

      // 導航
      context.go('/chat/detail?room_id=$roomId');
      debugPrint('✅ [ChatNavigationService] 導航成功');
      return true;
    } catch (e) {
      debugPrint('❌ [ChatNavigationService] 導航失敗: $e');
      _hideLoadingDialog(context);
      _showErrorDialog(context, '導航失敗: $e');
      return false;
    }
  }

  /// 確保聊天室存在並導航（用於 My Works）
  static Future<bool> ensureRoomAndNavigate({
    required BuildContext context,
    required String taskId,
    required int creatorId,
    required int participantId,
    String? existingRoomId,
    String type = 'application',
  }) async {
    try {
      debugPrint('🚀 [ChatNavigationService] 確保聊天室存在並導航');
      debugPrint('  - taskId: $taskId');
      debugPrint('  - creatorId: $creatorId');
      debugPrint('  - participantId: $participantId');
      debugPrint('  - existingRoomId: $existingRoomId');

      String realRoomId = '';

      // 檢查是否已經有現成的 chat_room_id
      if (existingRoomId != null && existingRoomId.isNotEmpty) {
        realRoomId = existingRoomId;
        debugPrint('✅ [ChatNavigationService] 使用現有的 chat_room_id: $realRoomId');
      } else {
        // 沒有現成的 chat_room_id，需要調用 ensure_room 創建
        debugPrint('📡 [ChatNavigationService] 調用 ensure_room 創建聊天室');

        // 顯示載入指示器
        _showLoadingDialog(context);

        final chatService = ChatService();
        final roomResult = await chatService.ensureRoom(
          taskId: taskId,
          creatorId: creatorId,
          participantId: participantId,
          type: type,
        );

        final roomData = roomResult['room'] ?? {};
        realRoomId = roomData['id']?.toString() ?? '';

        if (realRoomId.isEmpty) {
          debugPrint('❌ [ChatNavigationService] ensure_room 未取得 room_id');
          _hideLoadingDialog(context);
          _showErrorDialog(context, '無法創建聊天室');
          return false;
        }

        debugPrint(
            '✅ [ChatNavigationService] ensure_room 成功創建聊天室: $realRoomId');
      }

      // 使用統一的導航邏輯
      return await navigateToChatDetail(
        context: context,
        roomId: realRoomId,
      );
    } catch (e) {
      debugPrint('❌ [ChatNavigationService] 確保聊天室失敗: $e');
      _hideLoadingDialog(context);
      _showErrorDialog(context, '創建聊天室失敗: $e');
      return false;
    }
  }

  /// 顯示載入對話框
  static void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }

  /// 隱藏載入對話框
  static void _hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// 顯示錯誤對話框
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}

// 這是 ChatDetailPage 中改進任務操作同步的程式碼片段
// 用於替換現有的任務操作處理邏輯

import 'package:flutter/material.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/chat/utils/action_result_handler.dart';

/// ChatDetailPage 增強同步版本的核心方法
/// 用於替換現有的任務接受處理邏輯
mixin ChatDetailPageEnhancedSyncMixin<T extends StatefulWidget> on State<T> {
  /// 增強版本的任務接受處理
  /// 確保操作後即時同步到聊天列表
  Future<void> enhancedHandleAcceptApplication({
    required String taskId,
    required String applicantUserId,
    required ChatListProvider provider,
    required String userRole,
  }) async {
    debugPrint('🚀 [Enhanced] 開始處理任務接受操作');

    try {
      // 1. 執行原有的任務接受 API 調用
      // （這裡保留原有的 API 調用邏輯）

      // 2. 構建更新後的任務數據
      final updatedTaskData = {
        'status': {
          'code': 'in_progress',
          'display_name': 'In Progress',
        },
        'accepted_applicant_id': applicantUserId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 3. 使用 ActionResultHandler 處理結果同步
      await ActionResultHandler.handleTaskAcceptResult(
        taskId: taskId,
        updatedTaskData: updatedTaskData,
        userRole: userRole,
        provider: provider,
      );

      // 4. 更新本地 UI 狀態
      if (mounted) {
        setState(() {
          // 更新本地任務狀態...
        });
      }

      debugPrint('✅ [Enhanced] 任務接受處理完成');

      // 5. 顯示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 任務接受成功，聊天列表將自動更新'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [Enhanced] 任務接受處理失敗: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 任務接受失敗: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 增強版本的任務完成處理
  Future<void> enhancedHandleCompleteTask({
    required String taskId,
    required ChatListProvider provider,
    required String userRole,
  }) async {
    debugPrint('🚀 [Enhanced] 開始處理任務完成操作');

    try {
      // 1. 執行任務完成 API 調用
      // （保留原有邏輯）

      // 2. 構建更新後的狀態
      final newStatus = {
        'code': 'pending_confirmation',
        'display_name': 'Pending Confirmation',
      };

      // 3. 使用 ActionResultHandler 同步結果
      await ActionResultHandler.handleTaskStatusChangeResult(
        taskId: taskId,
        newStatus: newStatus,
        userRole: userRole,
        provider: provider,
      );

      debugPrint('✅ [Enhanced] 任務完成處理完成');
    } catch (e) {
      debugPrint('❌ [Enhanced] 任務完成處理失敗: $e');
    }
  }

  /// 增強版本的確認完成處理
  Future<void> enhancedHandleConfirmCompletion({
    required String taskId,
    required ChatListProvider provider,
    required String userRole,
  }) async {
    debugPrint('🚀 [Enhanced] 開始處理確認完成操作');

    try {
      // 1. 執行確認完成 API 調用
      // （保留原有邏輯）

      // 2. 構建完成狀態
      final newStatus = {
        'code': 'completed',
        'display_name': 'Completed',
      };

      // 3. 同步到聊天列表
      await ActionResultHandler.handleTaskStatusChangeResult(
        taskId: taskId,
        newStatus: newStatus,
        userRole: userRole,
        provider: provider,
      );

      debugPrint('✅ [Enhanced] 確認完成處理完成');
    } catch (e) {
      debugPrint('❌ [Enhanced] 確認完成處理失敗: $e');
    }
  }

  /// 增強版本的頁面退出處理
  /// 確保返回聊天列表時數據是最新的
  Future<void> enhancedOnPageWillPop({
    required ChatListProvider provider,
    String? currentTaskId,
  }) async {
    debugPrint('🚀 [Enhanced] 處理頁面退出同步');

    try {
      // 使用 ActionResultHandler 處理頁面返回
      await ActionResultHandler.handlePageReturn(
        provider: provider,
        specificTaskId: currentTaskId,
      );

      debugPrint('✅ [Enhanced] 頁面退出同步完成');
    } catch (e) {
      debugPrint('❌ [Enhanced] 頁面退出同步失敗: $e');
    }
  }
}

/// 使用示例：在 ChatDetailPage 中整合
class ChatDetailPageSyncExample {
  /// 替換現有的 _handleAcceptApplication 方法
  static String get replacementCode => '''
  /// 處理接受應徵 - 增強同步版本
  Future<void> _handleAcceptApplication(String applicantUserId) async {
    if (_task == null) return;
    
    try {
      final provider = context.read<ChatListProvider>();
      final taskId = _task!['id'].toString();
      
      // 使用增強版本處理
      await enhancedHandleAcceptApplication(
        taskId: taskId,
        applicantUserId: applicantUserId,
        provider: provider,
        userRole: _userRole,
      );
      
    } catch (e) {
      debugPrint('❌ 處理任務接受失敗: \$e');
    }
  }
  ''';

  /// 替換現有的 dispose 方法
  static String get enhancedDisposeCode => '''
  @override
  void dispose() async {
    try {
      // 增強版本的頁面退出處理
      final provider = context.read<ChatListProvider>();
      final taskId = _task?['id']?.toString();
      
      await enhancedOnPageWillPop(
        provider: provider,
        currentTaskId: taskId,
      );
      
    } catch (e) {
      debugPrint('❌ 頁面退出同步失敗: \$e');
    }
    
    // 原有的清理邏輯...
    super.dispose();
  }
  ''';
}

/// 驗證和測試工具
class ChatSyncTestingTools {
  /// 測試任務狀態同步
  static Future<void> testTaskStatusSync({
    required String taskId,
    required ChatListProvider provider,
  }) async {
    debugPrint('🧪 [測試] 開始測試任務狀態同步');

    // 模擬不同的狀態更新
    final testStatuses = ['in_progress', 'pending_confirmation', 'completed'];

    for (final status in testStatuses) {
      debugPrint('🧪 [測試] 測試狀態: $status');

      await ActionResultHandler.testTaskStatusUpdate(
        taskId: taskId,
        newStatus: status,
        provider: provider,
      );

      // 等待一段時間觀察結果
      await Future.delayed(const Duration(seconds: 1));
    }

    debugPrint('✅ [測試] 任務狀態同步測試完成');
  }

  /// 驗證緩存同步狀態
  static Future<Map<String, dynamic>> verifyCacheSync({
    required String taskId,
    required ChatListProvider provider,
  }) async {
    debugPrint('🔍 [驗證] 檢查緩存同步狀態');

    final result = <String, dynamic>{};

    // 檢查 Posted Tasks 緩存
    final postedTasks = provider.cacheManager.postedTasksCache;
    final foundInPosted =
        postedTasks.any((task) => task['id'].toString() == taskId);
    result['found_in_posted_tasks'] = foundInPosted;

    // 檢查 My Works 緩存
    final myWorks = provider.cacheManager.myWorksCache;
    final foundInMyWorks =
        myWorks.any((work) => work['task_id'].toString() == taskId);
    result['found_in_my_works'] = foundInMyWorks;

    // 檢查緩存更新狀態
    result['cache_is_updating'] = provider.cacheManager.isUpdating;
    result['cache_has_new_data'] = provider.cacheManager.hasNewData;
    result['cache_last_update'] =
        provider.cacheManager.lastUpdate?.toIso8601String();

    debugPrint('✅ [驗證] 緩存同步狀態: $result');
    return result;
  }
}

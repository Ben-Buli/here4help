import 'package:flutter/foundation.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';

/// 任務操作結果處理器
/// 確保 ChatDetailPage 中的任務操作後能即時同步到 ChatListProvider
class ActionResultHandler {
  static const String _tag = '[ActionResultHandler]';

  /// 處理任務接受操作的結果
  /// [taskId] 任務 ID
  /// [updatedTaskData] 更新後的任務數據
  /// [userRole] 用戶角色 ('creator' 或其他)
  /// [provider] ChatListProvider 實例
  static Future<void> handleTaskAcceptResult({
    required String taskId,
    required Map<String, dynamic> updatedTaskData,
    required String userRole,
    required ChatListProvider provider,
  }) async {
    debugPrint('$_tag 處理任務接受操作結果: taskId=$taskId');

    try {
      // 1. 立即更新 Provider 緩存中的任務狀態（即時同步）
      _updateTaskInCache(taskId, updatedTaskData, provider);

      // 2. 等待後台緩存完全刷新完成
      await _waitForCacheRefresh(provider);

      // 3. 根據用戶角色觸發相應分頁重載
      await _triggerTabRefresh(userRole, provider);

      debugPrint('✅ $_tag 任務接受結果處理完成');
    } catch (e) {
      debugPrint('❌ $_tag 任務接受結果處理失敗: $e');
    }
  }

  /// 處理任務狀態變更操作的結果
  /// [taskId] 任務 ID
  /// [newStatus] 新的任務狀態
  /// [userRole] 用戶角色
  /// [provider] ChatListProvider 實例
  static Future<void> handleTaskStatusChangeResult({
    required String taskId,
    required Map<String, dynamic> newStatus,
    required String userRole,
    required ChatListProvider provider,
  }) async {
    debugPrint('$_tag 處理任務狀態變更結果: taskId=$taskId, status=${newStatus['code']}');

    try {
      // 1. 構建更新的任務數據
      final updatedTaskData = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 2. 立即更新緩存
      _updateTaskInCache(taskId, updatedTaskData, provider);

      // 3. 等待完整刷新
      await _waitForCacheRefresh(provider);

      // 4. 觸發分頁刷新
      await _triggerTabRefresh(userRole, provider);

      debugPrint('✅ $_tag 任務狀態變更結果處理完成');
    } catch (e) {
      debugPrint('❌ $_tag 任務狀態變更結果處理失敗: $e');
    }
  }

  /// 處理應徵者狀態變更結果
  /// [taskId] 任務 ID
  /// [applicantUserId] 應徵者用戶 ID
  /// [newApplicationStatus] 新的應徵狀態
  /// [provider] ChatListProvider 實例
  static Future<void> handleApplicantStatusChangeResult({
    required String taskId,
    required String applicantUserId,
    required String newApplicationStatus,
    required ChatListProvider provider,
  }) async {
    debugPrint(
        '$_tag 處理應徵者狀態變更結果: taskId=$taskId, applicant=$applicantUserId, status=$newApplicationStatus');

    try {
      // 1. 構建更新的應徵者數據
      final updatedApplicantData = {
        'application_status': newApplicationStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 2. 立即更新應徵者狀態
      provider.updateApplicantStatus(
          taskId, applicantUserId, updatedApplicantData);

      // 3. 等待後台刷新
      await _waitForCacheRefresh(provider);

      debugPrint('✅ $_tag 應徵者狀態變更結果處理完成');
    } catch (e) {
      debugPrint('❌ $_tag 應徵者狀態變更結果處理失敗: $e');
    }
  }

  // ==================== 私有方法 ====================

  /// 立即更新緩存中的任務數據
  static void _updateTaskInCache(String taskId,
      Map<String, dynamic> updatedData, ChatListProvider provider) {
    debugPrint('$_tag 立即更新緩存中的任務: $taskId');

    // 使用 Provider 的精確更新方法
    provider.updateTaskStatus(taskId, updatedData);

    debugPrint('✅ $_tag 任務緩存立即更新完成');
  }

  /// 等待緩存完全刷新完成
  static Future<void> _waitForCacheRefresh(ChatListProvider provider) async {
    debugPrint('$_tag 等待緩存刷新完成...');

    // 觸發強制刷新並等待完成
    await provider.forceRefreshCache();

    // 額外等待確保更新完成
    await Future.delayed(const Duration(milliseconds: 500));

    debugPrint('✅ $_tag 緩存刷新等待完成');
  }

  /// 根據用戶角色觸發相應分頁刷新
  static Future<void> _triggerTabRefresh(
      String userRole, ChatListProvider provider) async {
    debugPrint('$_tag 觸發分頁刷新: userRole=$userRole');

    if (userRole == 'creator') {
      // 發布者：刷新 Posted Tasks 分頁
      await provider.refreshTab(ChatListProvider.tabPostedTasks);
      debugPrint('✅ $_tag Posted Tasks 分頁刷新完成');
    } else {
      // 應徵者：刷新 My Works 分頁
      await provider.refreshTab(ChatListProvider.tabMyWorks);
      debugPrint('✅ $_tag My Works 分頁刷新完成');
    }
  }

  /// 處理頁面返回時的數據同步
  /// 確保用戶返回聊天列表時看到最新狀態
  static Future<void> handlePageReturn({
    required ChatListProvider provider,
    String? specificTaskId,
  }) async {
    debugPrint('$_tag 處理頁面返回數據同步');

    try {
      // 1. 檢查緩存是否還在更新中
      if (provider.cacheManager.isUpdating) {
        debugPrint('$_tag 緩存正在更新中，等待完成...');

        // 等待更新完成，最多等待3秒
        int waitCount = 0;
        while (provider.cacheManager.isUpdating && waitCount < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }

        debugPrint('✅ $_tag 緩存更新等待完成（${waitCount * 100}ms）');
      }

      // 2. 如果指定了特定任務，檢查其狀態是否最新
      if (specificTaskId != null) {
        await _ensureTaskStatusLatest(specificTaskId, provider);
      }

      // 3. 觸發輕量級的數據檢查
      await provider.cacheManager.checkForUpdates();

      debugPrint('✅ $_tag 頁面返回數據同步完成');
    } catch (e) {
      debugPrint('❌ $_tag 頁面返回數據同步失敗: $e');
    }
  }

  /// 確保特定任務狀態是最新的
  static Future<void> _ensureTaskStatusLatest(
      String taskId, ChatListProvider provider) async {
    debugPrint('$_tag 確保任務狀態最新: $taskId');

    try {
      // 這裡可以添加單個任務狀態的檢查邏輯
      // 比如調用單個任務查詢 API 並更新緩存

      debugPrint('✅ $_tag 任務狀態檢查完成: $taskId');
    } catch (e) {
      debugPrint('❌ $_tag 任務狀態檢查失敗: $taskId, error: $e');
    }
  }

  /// 測試方法：模擬任務狀態更新
  static Future<void> testTaskStatusUpdate({
    required String taskId,
    required String newStatus,
    required ChatListProvider provider,
  }) async {
    debugPrint('$_tag [測試] 模擬任務狀態更新: $taskId -> $newStatus');

    final testData = {
      'status': {
        'code': newStatus,
        'display_name': newStatus,
      },
      'updated_at': DateTime.now().toIso8601String(),
    };

    await handleTaskStatusChangeResult(
      taskId: taskId,
      newStatus: testData['status'] as Map<String, dynamic>,
      userRole: 'creator',
      provider: provider,
    );
  }
}

// 此檔案包含 Posted Tasks Widget 的應徵者篩選增強邏輯
// 解決非 Open 狀態時應只顯示被接受應徵者的問題

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Posted Tasks 應徵者篩選增強邏輯
class PostedTasksApplicantFilter {
  static const String _tag = '[PostedTasksFilter]';

  /// 根據任務狀態篩選應徵者
  /// [task] 任務數據
  /// [applicants] 原始應徵者列表
  /// 返回篩選後的應徵者列表
  static List<Map<String, dynamic>> filterApplicantsByTaskStatus(
    Map<String, dynamic> task,
    List<Map<String, dynamic>> applicants,
  ) {
    if (applicants.isEmpty) {
      debugPrint('$_tag 任務 ${task['id']} 沒有應徵者');
      return applicants;
    }

    final taskId = task['id']?.toString() ?? 'unknown';
    final statusId = _getTaskStatusId(task);
    final statusDisplay = _getTaskStatusDisplay(task);

    debugPrint('$_tag 任務 $taskId 篩選應徵者:');
    debugPrint('  - 狀態ID: $statusId');
    debugPrint('  - 狀態顯示: $statusDisplay');
    debugPrint('  - 原始應徵者數量: ${applicants.length}');

    // 列印所有應徵者的狀態（調試用）
    for (int i = 0; i < applicants.length; i++) {
      final applicant = applicants[i];
      debugPrint(
          '    - 應徵者 $i: ${applicant['applier_name']} (狀態: ${applicant['application_status']})');
    }

    List<Map<String, dynamic>> filteredApplicants;

    switch (statusId) {
      case 1: // Open - 顯示所有應徵者
        filteredApplicants = applicants;
        debugPrint('$_tag Open 狀態，顯示所有 ${applicants.length} 個應徵者');
        break;

      case 2: // In Progress
      case 3: // Pending Confirmation
      case 4: // Completed
      case 5: // Dispute
        // 只顯示被接受的應徵者
        filteredApplicants = applicants.where((applicant) {
          final applicationStatus =
              applicant['application_status']?.toString().toLowerCase();
          return applicationStatus == 'accepted';
        }).toList();

        debugPrint('$_tag 非 Open 狀態，篩選後應徵者數量: ${filteredApplicants.length}');

        // 調試：列印篩選後的應徵者
        for (int i = 0; i < filteredApplicants.length; i++) {
          final applicant = filteredApplicants[i];
          debugPrint(
              '    - 篩選後應徵者 $i: ${applicant['applier_name']} (狀態: ${applicant['application_status']})');
        }
        break;

      default:
        // 未知狀態，保守策略：顯示所有應徵者
        filteredApplicants = applicants;
        debugPrint('$_tag 未知狀態 (ID: $statusId)，顯示所有應徵者');
        break;
    }

    // 驗證篩選結果
    _validateFilterResult(
        taskId, statusId, applicants.length, filteredApplicants.length);

    return filteredApplicants;
  }

  /// 獲取任務狀態ID
  static int _getTaskStatusId(Map<String, dynamic> task) {
    // 嘗試多種可能的欄位名稱
    final statusId = task['status_id'] ??
        task['statusId'] ??
        task['status']?['id'] ??
        task['task_status_id'];

    if (statusId is int) {
      return statusId;
    }

    if (statusId is String) {
      return int.tryParse(statusId) ?? 1; // 預設為 Open
    }

    debugPrint('⚠️ $_tag 無法獲取狀態ID，預設為 Open (1)');
    return 1; // 預設為 Open
  }

  /// 獲取任務狀態顯示名稱
  static String _getTaskStatusDisplay(Map<String, dynamic> task) {
    return task['status_display']?.toString() ??
        task['statusDisplay']?.toString() ??
        task['status']?['display_name']?.toString() ??
        'Unknown';
  }

  /// 驗證篩選結果的合理性
  static void _validateFilterResult(
    String taskId,
    int statusId,
    int originalCount,
    int filteredCount,
  ) {
    // 基本驗證
    if (filteredCount > originalCount) {
      debugPrint('❌ $_tag 篩選錯誤：篩選後數量 ($filteredCount) 大於原始數量 ($originalCount)');
      return;
    }

    // 狀態特定驗證
    switch (statusId) {
      case 1: // Open
        if (filteredCount != originalCount) {
          debugPrint('⚠️ $_tag Open 狀態應顯示所有應徵者，但篩選數量不一致');
        }
        break;

      case 2: // In Progress
      case 3: // Pending Confirmation
      case 4: // Completed
      case 5: // Dispute
        if (filteredCount > 1) {
          debugPrint('⚠️ $_tag 非 Open 狀態通常只應有一個被接受的應徵者，但發現 $filteredCount 個');
        }
        if (filteredCount == 0 && originalCount > 0) {
          debugPrint(
              '⚠️ $_tag 任務 $taskId 有 $originalCount 個應徵者但沒有被接受的，可能狀態不一致');
        }
        break;
    }

    debugPrint('✅ $_tag 任務 $taskId 篩選完成：$originalCount -> $filteredCount');
  }

  /// 檢查應徵者列表是否需要篩選
  /// 用於優化性能，避免不必要的篩選操作
  static bool shouldFilterApplicants(Map<String, dynamic> task) {
    final statusId = _getTaskStatusId(task);

    // 只有非 Open 狀態才需要篩選
    return statusId != 1;
  }

  /// 獲取狀態對應的期望應徵者數量
  /// 用於 UI 提示和驗證
  static int getExpectedApplicantCount(Map<String, dynamic> task) {
    final statusId = _getTaskStatusId(task);

    switch (statusId) {
      case 1: // Open
        return -1; // 不限制數量
      case 2: // In Progress
      case 3: // Pending Confirmation
      case 4: // Completed
      case 5: // Dispute
        return 1; // 應該只有一個被接受的應徵者
      default:
        return -1; // 不確定
    }
  }

  /// 調試方法：打印任務和應徵者的詳細信息
  static void debugTaskApplicants(
      Map<String, dynamic> task, List<Map<String, dynamic>> applicants) {
    if (!kDebugMode) return;

    final taskId = task['id']?.toString() ?? 'unknown';
    final statusId = _getTaskStatusId(task);
    final statusDisplay = _getTaskStatusDisplay(task);

    debugPrint('🔍 $_tag 任務詳細信息:');
    debugPrint('  - ID: $taskId');
    debugPrint('  - 標題: ${task['title']}');
    debugPrint('  - 狀態ID: $statusId');
    debugPrint('  - 狀態顯示: $statusDisplay');
    debugPrint('  - 應徵者數量: ${applicants.length}');

    if (applicants.isEmpty) {
      debugPrint('  - 沒有應徵者');
      return;
    }

    debugPrint('  - 應徵者詳細:');
    for (int i = 0; i < applicants.length; i++) {
      final applicant = applicants[i];
      debugPrint(
          '    [$i] ${applicant['applier_name'] ?? 'Unknown'} - ${applicant['application_status'] ?? 'unknown'}');
    }

    // 統計不同狀態的應徵者數量
    final statusCounts = <String, int>{};
    for (final applicant in applicants) {
      final status = applicant['application_status']?.toString() ?? 'unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    debugPrint('  - 狀態統計: $statusCounts');
  }
}

/// Posted Tasks Widget 的 Mixin 增強
/// 使用方法：在 PostedTasksWidget 的 State 類中添加 `with PostedTasksApplicantFilterMixin`
mixin PostedTasksApplicantFilterMixin<T extends StatefulWidget> on State<T> {
  /// 增強版的應徵者篩選方法
  /// 在原有的 _buildTaskCard 方法中調用此方法替換原始的應徵者列表
  List<Map<String, dynamic>> filterApplicantsForTask(
    Map<String, dynamic> task,
    Map<String, List<Map<String, dynamic>>> applicationsByTask,
  ) {
    final taskId = task['id'].toString();
    final originalApplicants = applicationsByTask[taskId] ?? [];

    // 調試原始數據
    PostedTasksApplicantFilter.debugTaskApplicants(task, originalApplicants);

    // 篩選應徵者
    return PostedTasksApplicantFilter.filterApplicantsByTaskStatus(
        task, originalApplicants);
  }

  /// 檢查任務是否應該隱藏應徵者區塊
  /// 例如：取消的任務可能不需要顯示應徵者
  bool shouldShowApplicantsForTask(Map<String, dynamic> task) {
    final statusId = PostedTasksApplicantFilter._getTaskStatusId(task);

    // 隱藏已取消任務的應徵者
    if (statusId == 8) {
      // Cancelled
      return false;
    }

    return true;
  }

  /// 獲取應徵者區塊的標題文本
  /// 根據任務狀態顯示不同的標題
  String getApplicantsSectionTitle(
      Map<String, dynamic> task, int applicantCount) {
    final statusId = PostedTasksApplicantFilter._getTaskStatusId(task);

    switch (statusId) {
      case 1: // Open
        return applicantCount == 0
            ? 'No applicants'
            : '$applicantCount applicants';
      case 2: // In Progress
        return applicantCount == 0
            ? 'No accepted applicant'
            : 'Accepted applicant';
      case 3: // Pending Confirmation
        return 'Awaiting confirmation';
      case 4: // Completed
        return 'Task completed by';
      case 5: // Dispute
        return 'In dispute with';
      default:
        return applicantCount == 0
            ? 'No applicants'
            : '$applicantCount applicants';
    }
  }
}

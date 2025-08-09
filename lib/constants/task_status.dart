// 統一任務狀態映射常量
class TaskStatus {
  // 狀態名稱映射
  static const Map<String, String> statusString = {
    'open': 'Open',
    'in_progress': 'In Progress',
    'in_progress_tasker': 'In Progress',
    'applying_tasker': 'Applying',
    'rejected_tasker': 'Rejected',
    'pending_confirmation': 'Pending Confirmation',
    'pending_confirmation_tasker': 'Pending Confirmation',
    'dispute': 'Dispute',
    'completed': 'Completed',
    'completed_tasker': 'Completed',
  };

  // 狀態進度對應表
  static const Map<String, double> statusProgressMap = {
    'Open': 0.0,
    'In Progress': 0.25,
    'Pending Confirmation': 0.5,
    'Completed': 1.0,
    'Dispute': 0.75,
    'Applying': 0.0,
    'Rejected': 0.0,
  };

  // 狀態排序權重
  static const Map<String, int> statusOrder = {
    'open': 0,
    'in_progress': 1,
    'pending_confirmation': 2,
    'dispute': 3,
    'completed': 4,
  };

  // 獲取顯示狀態
  static String getDisplayStatus(String status) {
    return statusString[status] ?? status;
  }

  // 獲取進度數據
  static Map<String, dynamic> getProgressData(String status) {
    final displayStatus = getDisplayStatus(status);

    if (statusProgressMap.containsKey(displayStatus)) {
      return {'progress': statusProgressMap[displayStatus]};
    }
    // 不顯示進度條的狀態
    return {'progress': null};
  }

  // 獲取狀態排序權重
  static int getStatusOrder(String status) {
    return statusOrder[status] ?? 999;
  }
}

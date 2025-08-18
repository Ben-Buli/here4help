import 'package:flutter/material.dart';

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

  // 角色視角狀態映射表
  // 根據 tasks.status_id + task_applications.status 組合，返回對應的顯示狀態
  static String getMappedStatusForRole({
    required int taskStatusId,
    required String? applicationStatus,
    required String userRole, // 'creator' 或 'participant'
  }) {
    // 預設狀態
    String defaultStatus = 'Unknown';

    try {
      switch (taskStatusId) {
        case 1: // pending
          if (userRole == 'creator') {
            defaultStatus = 'Open';
          } else {
            // participant 視角
            switch (applicationStatus) {
              case 'applied':
              case 'pending':
                defaultStatus = 'Pending Review';
                break;
              case 'accepted':
                defaultStatus = 'Accepted';
                break;
              case 'rejected':
                defaultStatus = 'Rejected';
                break;
              default:
                defaultStatus = 'Applied';
            }
          }
          break;

        case 2: // in_progress
          if (userRole == 'creator') {
            defaultStatus = 'In Progress';
          } else {
            // participant 視角
            switch (applicationStatus) {
              case 'accepted':
                defaultStatus = 'In Progress';
                break;
              case 'rejected':
                defaultStatus = 'Rejected';
                break;
              default:
                defaultStatus = 'In Progress';
            }
          }
          break;

        case 3: // pending_confirmation
          if (userRole == 'creator') {
            defaultStatus = 'Pending Confirmation';
          } else {
            // participant 視角
            switch (applicationStatus) {
              case 'accepted':
                defaultStatus = 'Pending Confirmation';
                break;
              case 'rejected':
                defaultStatus = 'Rejected';
                break;
              default:
                defaultStatus = 'Pending Confirmation';
            }
          }
          break;

        case 4: // completed
          if (userRole == 'creator') {
            defaultStatus = 'Completed';
          } else {
            // participant 視角
            switch (applicationStatus) {
              case 'accepted':
                defaultStatus = 'Completed';
                break;
              case 'rejected':
                defaultStatus = 'Rejected';
                break;
              default:
                defaultStatus = 'Completed';
            }
          }
          break;

        case 5: // cancelled
          defaultStatus = 'Cancelled';
          break;

        default:
          defaultStatus = 'Unknown';
      }
    } catch (e) {
      debugPrint('❌ 狀態映射錯誤: $e');
      defaultStatus = 'Unknown';
    }

    return defaultStatus;
  }

  // 根據主題色系生成對應的狀態配色
  // 回傳各顯示狀態對應的前景/背景色與進度權重
  static Map<String, ({double intensity, Color fg, Color bg})> themedColors(
      ColorScheme scheme) {
    Color muted(Color base, [double opacity = 0.12]) =>
        base.withOpacity(opacity);
    final Color primary = scheme.primary;
    final Color secondary = scheme.secondary;
    final Color warning = scheme.tertiary; // 近似警告/等待
    final Color neutral = scheme.surfaceContainerHighest;

    return {
      'Open': (intensity: 0.0, fg: primary, bg: muted(primary)),
      'In Progress': (intensity: 0.25, fg: secondary, bg: muted(secondary)),
      'Pending Confirmation': (intensity: 0.5, fg: warning, bg: muted(warning)),
      'Completed': (intensity: 1.0, fg: scheme.onSurface, bg: muted(neutral)),
      'Dispute': (intensity: 0.75, fg: scheme.error, bg: muted(scheme.error)),
      'Applying': (intensity: 0.0, fg: primary, bg: muted(primary)),
      'Rejected': (intensity: 0.0, fg: scheme.onSurface, bg: muted(neutral)),
      // 新增角色視角狀態
      'Pending Review': (intensity: 0.0, fg: warning, bg: muted(warning)),
      'Accepted': (intensity: 0.25, fg: secondary, bg: muted(secondary)),
      'Cancelled': (intensity: 0.0, fg: scheme.onSurface, bg: muted(neutral)),
    };
  }

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

  // 獲取角色視角的進度數據
  static Map<String, dynamic> getProgressDataForRole({
    required int taskStatusId,
    required String? applicationStatus,
    required String userRole,
  }) {
    final mappedStatus = getMappedStatusForRole(
      taskStatusId: taskStatusId,
      applicationStatus: applicationStatus,
      userRole: userRole,
    );

    return getProgressData(mappedStatus);
  }

  // 判斷狀態是否應該計入未讀統計
  static bool shouldIncludeInUnread(String status) {
    // 完成的任務不計入未讀
    return !['Completed', 'Cancelled', 'Rejected'].contains(status);
  }

  // 獲取狀態的優先級（用於排序）
  static int getStatusPriority(String status) {
    const priorityMap = {
      'Open': 1,
      'Pending Review': 2,
      'Applied': 3,
      'Accepted': 4,
      'In Progress': 5,
      'Pending Confirmation': 6,
      'Dispute': 7,
      'Completed': 8,
      'Rejected': 9,
      'Cancelled': 10,
    };

    return priorityMap[status] ?? 999;
  }
}

import 'package:flutter/material.dart';

/// ApplicationStatusUtils - 應徵者視角的任務狀態工具類
///
/// 此工具類專門處理從 task_applications.status 角度的狀態顯示
/// 與 TaskCardUtils 不同，這裡專注於應徵者的體驗
class ApplicationStatusUtils {
  /// task_applications.status 的所有可能值
  static const List<String> allApplicationStatuses = [
    'applied', // 已投遞
    'accepted', // 已被接受
    'rejected', // 已被拒絕
    'pending', // 待確認（任務完成等待發布者確認）
    'completed', // 已完成
    'cancelled', // 已取消
    'dispute', // 爭議中
    'withdrawn', // 已撤回
  ];

  /// 應徵狀態的中文顯示名稱映射
  static const Map<String, String> statusDisplayNames = {
    'applied': 'Applied (Please Wait for Response)',
    'accepted': 'Accepted (In Progress)',
    'rejected': 'Rejected',
    'pending': 'Pending Confirmation',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'dispute': 'In Dispute',
    'withdrawn': 'Withdrawn',
  };

  /// 應徵狀態的進度比例（0.0 - 1.0）
  static const Map<String, double> statusProgressMap = {
    'applied': 0.1, // 已投遞，等待回覆
    'accepted': 0.3, // 已接受，開始執行
    'rejected': 1.0, // 被拒絕，無進度
    'pending': 0.5, // 待確認，接近完成
    'completed': 1.0, // 已完成
    'cancelled': 1.0, // 已取消，無進度
    'dispute': 0.75, // 爭議中，部分進度
    'withdrawn': 1.0, // 已撤回，無進度
  };

  /// 應徵狀態的排序權重（數字越小優先級越高）
  static const Map<String, int> statusSortOrder = {
    'accepted': 1, // 已接受 - 最高優先級
    'pending': 2, // 待確認 - 第二優先級
    'dispute': 3, // 爭議中 - 第三優先級
    'applied': 4, // 已投遞 - 第四優先級
    'completed': 5, // 已完成 - 第五優先級
    'rejected': 6, // 被拒絕 - 第六優先級
    'cancelled': 7, // 已取消 - 第七優先級
    'withdrawn': 8, // 已撤回 - 最低優先級
  };

  /// 應徵者視角的狀態色彩配置
  /// 與 creator 視角不同，這裡更注重應徵者的情感體驗
  static const Map<String, Color> participantStatusColors = {
    'applied': Color.fromARGB(255, 132, 167, 192), // 莫蘭迪藍色 - 等待中，保持希望
    'accepted': Color.fromARGB(255, 234, 171, 102), // 莫蘭迪橘色 - 成功被選中
    'rejected': Color(0xFF9E9E9E), // 深灰色 - 被拒絕，但不過於刺眼
    'pending': Color(0xFF887392), // 莫蘭迪紫色 - 等待確認，接近成功
    'completed': Color.fromARGB(255, 105, 124, 106), // 莫蘭迪綠色 - 任務完成，成就感
    'cancelled': Color(0xFF9E9E9E), // 灰色 - 中性，任務取消
    'dispute': Color.fromARGB(255, 131, 97, 87), // 莫蘭迪棕色 - 需要注意的爭議
    'withdrawn': Color(0xFFBDBDBD), // 淺灰色 - 主動撤回，中性
  };

  /// 獲取應徵狀態的顯示名稱
  static String getDisplayName(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return 'Unknown';
    }
    return statusDisplayNames[applicationStatus.toLowerCase()] ??
        applicationStatus;
  }

  /// 獲取應徵狀態的進度比例
  static double getProgress(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return 0.0;
    }
    return statusProgressMap[applicationStatus.toLowerCase()] ?? 0.0;
  }

  /// 獲取應徵狀態的色彩
  static Color getStatusColor(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return Colors.grey[600]!;
    }
    return participantStatusColors[applicationStatus.toLowerCase()] ??
        Colors.grey[600]!;
  }

  /// 獲取應徵狀態的排序權重
  static int getSortOrder(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return 999;
    }
    return statusSortOrder[applicationStatus.toLowerCase()] ?? 999;
  }

  /// 獲取應徵狀態的進度數據（包含進度和顏色）
  static Map<String, dynamic> getProgressData(String? applicationStatus) {
    final progress = getProgress(applicationStatus);
    final color = getStatusColor(applicationStatus);

    return {
      'progress': progress,
      'color': color,
      'display_name': getDisplayName(applicationStatus),
      'sort_order': getSortOrder(applicationStatus),
    };
  }

  /// 檢查是否為活躍狀態（需要用戶關注的狀態）
  static bool isActiveStatus(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return false;
    }

    const activeStatuses = ['applied', 'accepted', 'pending', 'dispute'];
    return activeStatuses.contains(applicationStatus.toLowerCase());
  }

  /// 檢查是否為完成狀態
  static bool isCompletedStatus(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return false;
    }

    const completedStatuses = ['completed'];
    return completedStatuses.contains(applicationStatus.toLowerCase());
  }

  /// 檢查是否為失敗狀態
  static bool isFailedStatus(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return false;
    }

    const failedStatuses = ['rejected', 'cancelled', 'withdrawn'];
    return failedStatuses.contains(applicationStatus.toLowerCase());
  }

  /// 檢查是否需要倒數計時
  static bool isCountdownStatus(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return false;
    }

    const countdownStatuses = ['pending'];
    return countdownStatuses.contains(applicationStatus.toLowerCase());
  }

  /// 獲取狀態的描述文字（用於工具提示或詳細說明）
  static String getStatusDescription(String? applicationStatus) {
    if (applicationStatus == null || applicationStatus.isEmpty) {
      return 'Status unknown';
    }

    const descriptions = {
      'applied':
          'Your application has been submitted and is waiting for the poster\'s response.',
      'accepted': 'Congratulations! You have been selected for this task.',
      'rejected': 'Unfortunately, the poster has chosen another candidate.',
      'pending': 'Task completed, waiting for the poster\'s confirmation.',
      'completed': 'Task successfully completed and confirmed.',
      'cancelled': 'This task has been cancelled.',
      'dispute':
          'There is a dispute regarding this task that needs resolution.',
      'withdrawn': 'You have withdrawn your application for this task.',
    };

    return descriptions[applicationStatus.toLowerCase()] ??
        'Status: $applicationStatus';
  }

  /// 根據應徵狀態對任務列表進行排序
  static List<Map<String, dynamic>> sortByApplicationStatus(
    List<Map<String, dynamic>> tasks, {
    bool ascending = true,
  }) {
    final sortedTasks = List<Map<String, dynamic>>.from(tasks);

    sortedTasks.sort((a, b) {
      final statusA = a['application_status']?.toString();
      final statusB = b['application_status']?.toString();

      final orderA = getSortOrder(statusA);
      final orderB = getSortOrder(statusB);

      int comparison = orderA.compareTo(orderB);

      // 如果狀態相同，按更新時間排序
      if (comparison == 0) {
        final timeA =
            DateTime.tryParse(a['application_updated_at']?.toString() ?? '') ??
                DateTime.now();
        final timeB =
            DateTime.tryParse(b['application_updated_at']?.toString() ?? '') ??
                DateTime.now();
        comparison = timeB.compareTo(timeA); // 最新的在前
      }

      return ascending ? comparison : -comparison;
    });

    return sortedTasks;
  }

  /// 根據應徵狀態篩選任務
  static List<Map<String, dynamic>> filterByApplicationStatus(
    List<Map<String, dynamic>> tasks,
    List<String> allowedStatuses,
  ) {
    if (allowedStatuses.isEmpty) {
      return tasks;
    }

    return tasks.where((task) {
      final status = task['application_status']?.toString().toLowerCase();
      return status != null &&
          allowedStatuses.map((s) => s.toLowerCase()).contains(status);
    }).toList();
  }

  /// 獲取應徵狀態的統計信息
  static Map<String, int> getStatusStatistics(
      List<Map<String, dynamic>> tasks) {
    final stats = <String, int>{};

    for (final status in allApplicationStatuses) {
      stats[status] = 0;
    }

    for (final task in tasks) {
      final status = task['application_status']?.toString().toLowerCase();
      if (status != null && stats.containsKey(status)) {
        stats[status] = stats[status]! + 1;
      }
    }

    return stats;
  }
}

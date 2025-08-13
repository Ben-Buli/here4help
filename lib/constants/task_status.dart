import 'package:flutter/material.dart';
import '../services/task_status_service.dart';

/// 任務狀態常量類別 - 重構為使用 TaskStatusService
///
/// ⚠️ 已棄用：本類別保留用於向後相容，建議直接使用 TaskStatusService
@Deprecated('Use TaskStatusService instead for dynamic status management')
class TaskStatus {
  static final TaskStatusService _service = TaskStatusService();

  /// ⚠️ 已棄用：請使用 TaskStatusService.getDisplayName()
  @Deprecated('Use TaskStatusService.getDisplayName() instead')
  static String getDisplayStatus(String status) {
    return _service.getDisplayName(status);
  }

  /// ⚠️ 已棄用：請使用 TaskStatusService.getProgressRatio()
  @Deprecated('Use TaskStatusService.getProgressRatio() instead')
  static Map<String, dynamic> getProgressData(String status) {
    final progress = _service.getProgressRatio(status);
    return {'progress': progress > 0 ? progress : null};
  }

  /// ⚠️ 已棄用：請使用 TaskStatusService.getSortOrder()
  @Deprecated('Use TaskStatusService.getSortOrder() instead')
  static int getStatusOrder(String status) {
    return _service.getSortOrder(status);
  }

  /// ⚠️ 已棄用：請使用 TaskStatusService.getStatusStyle()
  @Deprecated('Use TaskStatusService.getStatusStyle() instead')
  static Map<String, ({double intensity, Color fg, Color bg})> themedColors(
      ColorScheme scheme) {
    // 提供基本的向後相容性
    final Map<String, ({double intensity, Color fg, Color bg})> result = {};

    for (final status in _service.statuses) {
      final style = _service.getStatusStyle(status.code, scheme);
      result[status.displayName] = (
        intensity: style.intensity,
        fg: style.foregroundColor,
        bg: style.backgroundColor,
      );
    }

    // 如果 service 尚未載入，提供預設值
    if (result.isEmpty) {
      return _getFallbackThemedColors(scheme);
    }

    return result;
  }

  /// 向後相容的預設顏色配置
  static Map<String, ({double intensity, Color fg, Color bg})>
      _getFallbackThemedColors(ColorScheme scheme) {
    Color muted(Color base, [double opacity = 0.12]) =>
        base.withValues(alpha: opacity);
    final Color primary = scheme.primary;
    final Color secondary = scheme.secondary;
    final Color warning = scheme.tertiary;
    final Color neutral = scheme.surfaceContainerHighest;

    return {
      'Open': (intensity: 0.0, fg: primary, bg: muted(primary)),
      'In Progress': (intensity: 0.25, fg: secondary, bg: muted(secondary)),
      'Pending Confirmation': (intensity: 0.5, fg: warning, bg: muted(warning)),
      'Completed': (intensity: 1.0, fg: scheme.onSurface, bg: muted(neutral)),
      'Dispute': (intensity: 0.75, fg: scheme.error, bg: muted(scheme.error)),
      'Applying': (intensity: 0.0, fg: primary, bg: muted(primary)),
      'Rejected': (intensity: 0.0, fg: scheme.onSurface, bg: muted(neutral)),
    };
  }

  /// ⚠️ 已棄用的硬編碼對應表 - 僅供向後相容
  @Deprecated('Hardcoded status mappings - use TaskStatusService instead')
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
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// 任務狀態服務 - 動態載入和管理任務狀態
class TaskStatusService extends ChangeNotifier {
  static final TaskStatusService _instance = TaskStatusService._internal();
  factory TaskStatusService() => _instance;
  TaskStatusService._internal();

  /// 狀態資料快取
  final List<TaskStatusModel> _statuses = [];
  final Map<String, TaskStatusModel> _statusByCode = {};
  final Map<int, TaskStatusModel> _statusById = {};

  bool _isLoaded = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TaskStatusModel> get statuses => List.unmodifiable(_statuses);
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 初始化載入狀態資料
  Future<bool> initialize({bool force = false}) async {
    if (_isLoaded && !force) return true;
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(AppConfig.taskStatusesUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _statuses.clear();
          _statusByCode.clear();
          _statusById.clear();

          for (final statusData in data['data']) {
            final status = TaskStatusModel.fromJson(statusData);
            _statuses.add(status);
            _statusByCode[status.code] = status;
            _statusById[status.id] = status;
          }

          _isLoaded = true;
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _error = data['message'] ?? 'Failed to load statuses';
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to load statuses';
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('TaskStatusService initialization error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// 根據 code 取得狀態
  TaskStatusModel? getByCode(String code) {
    return _statusByCode[code];
  }

  /// 根據 ID 取得狀態
  TaskStatusModel? getById(int id) {
    return _statusById[id];
  }

  /// 取得顯示名稱
  String getDisplayName(dynamic statusIdentifier) {
    TaskStatusModel? status;

    if (statusIdentifier is int) {
      status = getById(statusIdentifier);
    } else if (statusIdentifier is String) {
      status = getByCode(statusIdentifier);
    }

    return status?.displayName ?? statusIdentifier.toString();
  }

  /// 取得進度比例
  double getProgressRatio(dynamic statusIdentifier) {
    TaskStatusModel? status;

    if (statusIdentifier is int) {
      status = getById(statusIdentifier);
    } else if (statusIdentifier is String) {
      status = getByCode(statusIdentifier);
    }

    return status?.progressRatio ?? 0.0;
  }

  /// 取得排序權重
  int getSortOrder(dynamic statusIdentifier) {
    TaskStatusModel? status;

    if (statusIdentifier is int) {
      status = getById(statusIdentifier);
    } else if (statusIdentifier is String) {
      status = getByCode(statusIdentifier);
    }

    return status?.sortOrder ?? 999;
  }

  /// 是否計入未讀
  bool includeInUnread(dynamic statusIdentifier) {
    TaskStatusModel? status;

    if (statusIdentifier is int) {
      status = getById(statusIdentifier);
    } else if (statusIdentifier is String) {
      status = getByCode(statusIdentifier);
    }

    return status?.includeInUnread ?? true;
  }

  /// 取得狀態樣式 (主題色系適配)
  TaskStatusStyle getStatusStyle(
      dynamic statusIdentifier, ColorScheme colorScheme) {
    final status = (statusIdentifier is int)
        ? getById(statusIdentifier)
        : getByCode(statusIdentifier.toString());

    if (status == null) {
      return TaskStatusStyle.defaultStyle(colorScheme);
    }

    return TaskStatusStyle.fromStatus(status, colorScheme);
  }

  /// 取得可用的狀態選項 (用於狀態選擇器)
  List<TaskStatusModel> getActiveStatuses() {
    return _statuses.where((status) => status.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 強制重新載入
  Future<bool> reload() async {
    return initialize(force: true);
  }

  /// 兼容性方法 - 已棄用，請使用 initialize()
  @Deprecated('Use TaskStatusService.initialize() instead')
  Future<void> loadStatuses() async {
    await initialize();
  }

  /// 兼容性方法 - 取得進度條顏色
  Color getProgressColor(String status) {
    return getStatusStyle(status, ThemeData().colorScheme).foregroundColor;
  }

  /// 兼容性方法 - 取得狀態背景顏色
  Color getStatusBackgroundColor(String status) {
    return getStatusStyle(status, ThemeData().colorScheme).backgroundColor;
  }

  /// 兼容性方法 - 創建假狀態物件
  TaskStatusModel createFakeStatus(String code, String displayName) {
    return TaskStatusModel(
      id: 999,
      code: code,
      displayName: displayName,
      progressRatio: 0.0,
      sortOrder: 999,
      includeInUnread: true,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 兼容性方法 - 根據狀態產生樣式
  TaskStatusStyle generateStyleFromStatus(
      TaskStatusModel status, ColorScheme colorScheme) {
    Color muted(Color base, [double opacity = 0.12]) =>
        base.withValues(alpha: opacity);

    switch (status.code) {
      case 'open':
        return TaskStatusStyle(
          foregroundColor: colorScheme.primary,
          backgroundColor: muted(colorScheme.primary),
          intensity: status.progressRatio,
          icon: Icons.fiber_new,
        );

      case 'in_progress':
        return TaskStatusStyle(
          foregroundColor: colorScheme.secondary,
          backgroundColor: muted(colorScheme.secondary),
          intensity: status.progressRatio,
          icon: Icons.hourglass_bottom,
        );

      case 'pending_confirmation':
        return TaskStatusStyle(
          foregroundColor: colorScheme.tertiary,
          backgroundColor: muted(colorScheme.tertiary),
          intensity: status.progressRatio,
          icon: Icons.pending,
        );

      case 'completed':
        return TaskStatusStyle(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: muted(colorScheme.surfaceContainerHighest),
          intensity: status.progressRatio,
          icon: Icons.check_circle,
        );

      case 'dispute':
        return TaskStatusStyle(
          foregroundColor: colorScheme.error,
          backgroundColor: muted(colorScheme.error),
          intensity: status.progressRatio,
          icon: Icons.report_problem,
        );

      case 'applying':
        return TaskStatusStyle(
          foregroundColor: colorScheme.primary,
          backgroundColor: muted(colorScheme.primary),
          intensity: status.progressRatio,
          icon: Icons.send,
        );

      case 'rejected':
        return TaskStatusStyle(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: muted(colorScheme.surfaceContainerHighest),
          intensity: status.progressRatio,
          icon: Icons.cancel,
        );

      case 'canceled':
        return TaskStatusStyle(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: muted(colorScheme.surfaceContainerHighest),
          intensity: status.progressRatio,
          icon: Icons.block,
        );

      default:
        return TaskStatusStyle.defaultStyle(colorScheme);
    }
  }

  /// 預設樣式
  static TaskStatusStyle defaultStyle(ColorScheme colorScheme) {
    return TaskStatusStyle(
      foregroundColor: colorScheme.onSurface,
      backgroundColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
      intensity: 0.0,
      icon: Icons.help_outline,
    );
  }
}

/// 任務狀態資料模型
class TaskStatusModel {
  final int id;
  final String code;
  final String displayName;
  final double progressRatio;
  final int sortOrder;
  final bool includeInUnread;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskStatusModel({
    required this.id,
    required this.code,
    required this.displayName,
    required this.progressRatio,
    required this.sortOrder,
    required this.includeInUnread,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskStatusModel.fromJson(Map<String, dynamic> json) {
    return TaskStatusModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      code: (json['code'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      progressRatio: (json['progress_ratio'] is String)
          ? double.parse(json['progress_ratio'])
          : (json['progress_ratio'] as num).toDouble(),
      sortOrder: json['sort_order'] is int
          ? json['sort_order']
          : int.parse(json['sort_order'].toString()),
      includeInUnread:
          json['include_in_unread'] == 1 || json['include_in_unread'] == true,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'display_name': displayName,
      'progress_ratio': progressRatio,
      'sort_order': sortOrder,
      'include_in_unread': includeInUnread,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TaskStatusModel(id: $id, code: $code, displayName: $displayName)';
  }
}

/// 任務狀態樣式
class TaskStatusStyle {
  final Color foregroundColor;
  final Color backgroundColor;
  final double intensity;
  final IconData? icon;

  TaskStatusStyle({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.intensity,
    this.icon,
  });

  /// 根據狀態和主題生成樣式
  factory TaskStatusStyle.fromStatus(
      TaskStatusModel status, ColorScheme colorScheme) {
    Color muted(Color base, [double opacity = 0.12]) =>
        base.withValues(alpha: opacity);

    switch (status.code) {
      case 'open':
        return TaskStatusStyle(
          foregroundColor: colorScheme.primary,
          backgroundColor: muted(colorScheme.primary),
          intensity: status.progressRatio,
          icon: Icons.fiber_new,
        );

      case 'in_progress':
        return TaskStatusStyle(
          foregroundColor: colorScheme.secondary,
          backgroundColor: muted(colorScheme.secondary),
          intensity: status.progressRatio,
          icon: Icons.hourglass_bottom,
        );

      case 'pending_confirmation':
        return TaskStatusStyle(
          foregroundColor: colorScheme.tertiary,
          backgroundColor: muted(colorScheme.tertiary),
          intensity: status.progressRatio,
          icon: Icons.pending,
        );

      case 'completed':
        return TaskStatusStyle(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: muted(colorScheme.surfaceContainerHighest),
          intensity: status.progressRatio,
          icon: Icons.check_circle,
        );

      case 'dispute':
        return TaskStatusStyle(
          foregroundColor: colorScheme.error,
          backgroundColor: muted(colorScheme.error),
          intensity: status.progressRatio,
          icon: Icons.report_problem,
        );

      case 'applying':
        return TaskStatusStyle(
          foregroundColor: colorScheme.primary,
          backgroundColor: muted(colorScheme.primary),
          intensity: status.progressRatio,
          icon: Icons.send,
        );

      case 'rejected':
        return TaskStatusStyle(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: muted(colorScheme.surfaceContainerHighest),
          intensity: status.progressRatio,
          icon: Icons.cancel,
        );

      case 'canceled':
        return TaskStatusStyle(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: muted(colorScheme.surfaceContainerHighest),
          intensity: status.progressRatio,
          icon: Icons.block,
        );

      default:
        return defaultStyle(colorScheme);
    }
  }

  /// 預設樣式
  static TaskStatusStyle defaultStyle(ColorScheme colorScheme) {
    return TaskStatusStyle(
      foregroundColor: colorScheme.onSurface,
      backgroundColor:
          colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
      intensity: 0.0,
      icon: Icons.help_outline,
    );
  }
}

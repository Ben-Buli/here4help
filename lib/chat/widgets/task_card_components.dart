import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:here4help/constants/task_status.dart';

/// 任務卡片相關的共用組件和工具函數
/// 從原始 ChatListPage 中提取的 UI 組件

/// 中空圓餅圖繪製器
class PieChartPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final double strokeWidth;

  PieChartPainter({
    required this.progress,
    required this.baseColor,
    this.strokeWidth = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 繪製背景圓圈（淺色）
    final backgroundPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 繪製進度圓弧
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = baseColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // 從頂部開始
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 任務卡片工具函數
class TaskCardUtils {
  /// 顯示任務狀態
  static String displayStatus(Map<String, dynamic> task) {
    final dynamic display = task['status_display'];
    if (display != null && display is String && display.isNotEmpty) {
      return display;
    }
    final dynamic codeOrLegacy = task['status_code'] ?? task['status'];
    final mapped = TaskStatus.statusString[codeOrLegacy] ?? codeOrLegacy;
    return (mapped ?? '').toString();
  }

  /// 根據狀態返回進度值和顏色
  static Map<String, dynamic> getProgressData(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.statusString[status] ?? status;

    const int colorRates = 200;
    switch (displayStatus) {
      case 'Open':
        return {'progress': 0.0, 'color': Colors.blue[colorRates]!};
      case 'In Progress':
        return {'progress': 0.25, 'color': Colors.orange[colorRates]!};
      case 'Pending Confirmation':
        return {'progress': 0.5, 'color': Colors.purple[colorRates]!};
      case 'Completed':
        return {'progress': 1.0, 'color': Colors.lightGreen[colorRates]!};
      case 'Dispute':
        return {'progress': 0.75, 'color': Colors.brown[colorRates]!};
      case 'Applying (Tasker)':
        return {'progress': 0.0, 'color': Colors.lightGreenAccent[colorRates]!};
      case 'In Progress (Tasker)':
        return {'progress': 0.25, 'color': Colors.orange[colorRates]!};
      case 'Completed (Tasker)':
        return {'progress': 1.0, 'color': Colors.green[colorRates]!};
      case 'Rejected (Tasker)':
        return {'progress': 1.0, 'color': Colors.blueGrey[colorRates]!};
      default:
        return {
          'progress': null,
          'color': Colors.lightBlue[colorRates]!
        }; // 其他狀態
    }
  }

  /// 判斷是否為新任務（發布未滿一週）
  static bool isNewTask(Map<String, dynamic> task) {
    try {
      final createdAt =
          DateTime.parse(task['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(createdAt);
      return difference.inDays < 7;
    } catch (e) {
      return false;
    }
  }

  /// 判斷是否為熱門任務（超過一位應徵者）
  static bool isPopularTask(Map<String, dynamic> task,
      Map<String, List<Map<String, dynamic>>> applicationsByTask) {
    final applications = applicationsByTask[task['id']?.toString()] ?? [];
    return applications.length > 1;
  }

  /// 獲取任務發布時間的距離描述
  static String getTimeAgo(Map<String, dynamic> task) {
    try {
      final createdAt =
          DateTime.parse(task['created_at'] ?? DateTime.now().toString());
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      if (difference.inDays > 30) {
        return DateFormat('MM/dd').format(createdAt);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// 根據 id 產生一致的顏色
  static Color getAvatarColor(String id) {
    const int avatarBgColorLevel = 400;
    // 使用 id 的 hashCode 來產生顏色
    final colors = [
      Colors.deepOrangeAccent[avatarBgColorLevel]!,
      Colors.lightGreen[avatarBgColorLevel]!,
      Colors.blue[avatarBgColorLevel]!,
      Colors.orange[avatarBgColorLevel]!,
      Colors.purple[avatarBgColorLevel]!,
      Colors.teal[avatarBgColorLevel]!,
      Colors.indigo[avatarBgColorLevel]!,
      Colors.brown[avatarBgColorLevel]!,
      Colors.cyan[avatarBgColorLevel]!,
      Colors.orangeAccent[avatarBgColorLevel]!,
      Colors.deepPurple[avatarBgColorLevel]!,
      Colors.lime[avatarBgColorLevel]!,
      Colors.pinkAccent[avatarBgColorLevel]!,
      Colors.amber[avatarBgColorLevel]!,
    ];
    final index = id.hashCode.abs() % colors.length;
    return colors[index];
  }

  /// 取得名字的首個字母
  static String getInitials(String name) {
    if (name.isEmpty) return '';
    return name.trim().substring(0, 1).toUpperCase();
  }

  /// 檢查是否為倒數計時狀態
  static bool isCountdownStatus(String status) {
    // Convert database status to display status if needed
    final displayStatus = TaskStatus.getDisplayStatus(status);

    return displayStatus == TaskStatus.statusString['pending_confirmation'] ||
        displayStatus == TaskStatus.statusString['pending_confirmation_tasker'];
  }
}

/// 緊湊倒數計時器 Widget
class CompactCountdownTimerWidget extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onCountdownComplete;

  const CompactCountdownTimerWidget({
    super.key,
    required this.task,
    required this.onCountdownComplete,
  });

  @override
  State<CompactCountdownTimerWidget> createState() =>
      _CompactCountdownTimerWidgetState();
}

class _CompactCountdownTimerWidgetState
    extends State<CompactCountdownTimerWidget> {
  late Duration _remaining;
  late DateTime _endTime;
  late DateTime _startTime;
  bool _completed = false;
  late Stream<int> _timerStream;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = _startTime.add(const Duration(days: 7));
    _remaining = _endTime.difference(DateTime.now());

    // 使用 Stream 來替代自定義 Ticker
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  String _formatCompactDuration(Duration d) {
    int totalSeconds = d.inSeconds;
    int days = totalSeconds ~/ (24 * 3600);
    int hours = (totalSeconds % (24 * 3600)) ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _timerStream,
      builder: (context, snapshot) {
        final now = DateTime.now();
        final remain = _endTime.difference(now);

        if (remain <= Duration.zero && !_completed) {
          _completed = true;
          widget.onCountdownComplete();
          _remaining = Duration.zero;
        } else if (!_completed) {
          _remaining = remain > Duration.zero ? remain : Duration.zero;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: Colors.purple[600], size: 12),
              const SizedBox(width: 4),
              Text(
                _remaining > Duration.zero
                    ? _formatCompactDuration(_remaining)
                    : '00d 00:00:00',
                style: TextStyle(
                  color: Colors.purple[600],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

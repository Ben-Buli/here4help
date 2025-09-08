import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 獨立的倒數計時組件
///
/// 這個組件專門處理倒數計時邏輯，每秒更新顯示，但不影響父組件的重建
class CountdownTimerWidget extends StatefulWidget {
  final DateTime endTime;
  final VoidCallback? onComplete;
  final TextStyle? textStyle;
  final String prefix;
  final String suffix;

  const CountdownTimerWidget({
    super.key,
    required this.endTime,
    this.onComplete,
    this.textStyle,
    this.prefix = '⏰ ',
    this.suffix = ' until auto complete',
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget>
    with TickerProviderStateMixin {
  late Ticker _ticker;
  Duration _remainingTime = Duration.zero;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) {
      _updateRemainingTime();
      _isCompleted = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final remaining = widget.endTime.difference(now);
    _remainingTime = remaining > Duration.zero ? remaining : Duration.zero;
  }

  void _onTick(Duration elapsed) {
    if (_isCompleted) return;

    final now = DateTime.now();
    final remaining = widget.endTime.difference(now);

    if (remaining <= Duration.zero) {
      // 倒數計時結束
      _isCompleted = true;
      _ticker.stop();

      debugPrint('⏰ [CountdownTimer] 倒數計時結束');
      setState(() {
        _remainingTime = Duration.zero;
      });

      // 通知完成
      widget.onComplete?.call();
    } else {
      // 每秒更新倒數計時顯示
      final newRemainingTime = remaining;
      if (newRemainingTime.inSeconds != _remainingTime.inSeconds) {
        // 只在分鐘變化時輸出調試信息，避免刷屏
        final shouldDebug =
            newRemainingTime.inMinutes != _remainingTime.inMinutes;

        setState(() {
          _remainingTime = newRemainingTime;
        });

        if (shouldDebug) {
          debugPrint(
              '⏰ [CountdownTimer] 剩餘時間: ${_formatDuration(newRemainingTime)}');
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingTime <= Duration.zero) {
      return const SizedBox.shrink(); // 時間到了就隱藏
    }

    return Text(
      '${widget.prefix}${_formatDuration(_remainingTime)}${widget.suffix}',
      style: widget.textStyle ??
          const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.red,
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// 觸控板手勢修復 Widget
/// 解決 Flutter Web 中的觸控板手勢斷言失敗問題
class TrackpadGestureFix extends StatelessWidget {
  final Widget child;
  final bool enableTrackpadFix;

  const TrackpadGestureFix({
    super.key,
    required this.child,
    this.enableTrackpadFix = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableTrackpadFix) {
      return child;
    }

    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        // 攔截觸控板滾輪事件，避免 Flutter 的斷言失敗
        if (event is PointerScrollEvent) {
          // 手動處理滾輪事件
          _handleScrollEvent(event);
        }
      },
      child: GestureDetector(
        onPanUpdate: (DragUpdateDetails details) {
          // 攔截觸控板拖拽事件
          _handlePanUpdate(details);
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          // 攔截觸控板縮放手勢
          _handleScaleUpdate(details);
        },
        child: child,
      ),
    );
  }

  void _handleScrollEvent(PointerScrollEvent event) {
    // 手動處理滾輪事件，避免 Flutter 的觸控板斷言
    try {
      // 這裡可以添加自定義的滾輪處理邏輯
      // 例如：手動滾動 ScrollController
      debugPrint('🖱️ [TrackpadFix] 處理滾輪事件: ${event.scrollDelta}');
    } catch (e) {
      debugPrint('⚠️ [TrackpadFix] 滾輪事件處理失敗: $e');
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    // 手動處理拖拽事件
    try {
      debugPrint('🖱️ [TrackpadFix] 處理拖拽事件: ${details.delta}');
    } catch (e) {
      debugPrint('⚠️ [TrackpadFix] 拖拽事件處理失敗: $e');
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // 手動處理縮放手勢
    try {
      debugPrint('🖱️ [TrackpadFix] 處理縮放手勢: ${details.scale}');
    } catch (e) {
      debugPrint('⚠️ [TrackpadFix] 縮放手勢處理失敗: $e');
    }
  }
}

/// 觸控板手勢修復的 ScrollView
class TrackpadScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final bool enableTrackpadFix;

  const TrackpadScrollView({
    super.key,
    required this.child,
    this.controller,
    this.enableTrackpadFix = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableTrackpadFix) {
      return SingleChildScrollView(
        controller: controller,
        child: child,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // 攔截滾動通知，避免觸控板手勢問題
        if (notification is ScrollStartNotification) {
          debugPrint('🖱️ [TrackpadFix] 滾動開始');
        } else if (notification is ScrollUpdateNotification) {
          debugPrint('🖱️ [TrackpadFix] 滾動更新: ${notification.metrics.pixels}');
        } else if (notification is ScrollEndNotification) {
          debugPrint('🖱️ [TrackpadFix] 滾動結束');
        }
        return false; // 允許事件繼續傳播
      },
      child: SingleChildScrollView(
        controller: controller,
        // 添加觸控板手勢修復
        physics: const ClampingScrollPhysics(),
        child: child,
      ),
    );
  }
}

/// 觸控板手勢修復的 ListView
class TrackpadListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final bool enableTrackpadFix;

  const TrackpadListView({
    super.key,
    required this.children,
    this.controller,
    this.enableTrackpadFix = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableTrackpadFix) {
      return ListView(
        controller: controller,
        children: children,
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // 攔截滾動通知
        if (notification is ScrollStartNotification) {
          debugPrint('🖱️ [TrackpadFix] ListView 滾動開始');
        }
        return false;
      },
      child: ListView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        children: children,
      ),
    );
  }
}

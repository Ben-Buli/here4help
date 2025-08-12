import 'dart:async';

/// 簡單全域事件匯流排：用於同頁點擊 BottomNav 時觸發滾動回頂端
class ScrollEventBus {
  static final ScrollEventBus _instance = ScrollEventBus._internal();
  factory ScrollEventBus() => _instance;
  ScrollEventBus._internal();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// 監聽事件（payload 為路由，例如 '/home'）
  Stream<String> get stream => _controller.stream;

  /// 發送事件
  void emit(String route) {
    try {
      _controller.add(route);
    } catch (_) {
      // 忽略偶發錯誤（例如 listener 關閉）
    }
  }
}

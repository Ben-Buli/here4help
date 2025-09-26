import 'package:flutter/foundation.dart';

/// 移動端平台的第三方登入實現
class PlatformAuth {
  /// 移動端不支持 Web API
  static bool get canUseWebAPI => false;

  /// 移動端不支持打開 popup
  static void openAuthPopup(String url, String windowName) {
    debugPrint('⚠️ 移動端不支持 popup 登入: $windowName');
    // 在移動端，應該使用原生的第三方登入套件
  }

  /// 移動端不需要消息監聽器
  static void addMessageListener(void Function(String data) onMessage) {
    debugPrint('⚠️ 移動端不支持消息監聽器');
  }

  /// 移動端不需要移除消息監聽器
  static void removeMessageListener() {
    debugPrint('⚠️ 移動端不需要移除消息監聽器');
  }
}

import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web 平台的第三方登入實現
class PlatformAuth {
  /// 檢查是否可以使用 Web API
  static bool get canUseWebAPI {
    try {
      return true; // 在 Web 平台上始終可用
    } catch (e) {
      return false;
    }
  }

  /// 打開認證 popup
  static void openAuthPopup(String url, String windowName) {
    if (canUseWebAPI) {
      html.window.open(
          url, windowName, 'width=500,height=600,scrollbars=yes,resizable=yes');
      debugPrint('✅ 認證 popup 已打開: $windowName');
    }
  }

  /// 添加消息監聽器
  static void addMessageListener(void Function(String data) onMessage) {
    if (canUseWebAPI) {
      html.window.addEventListener('message', (event) {
        if (event is html.MessageEvent) {
          debugPrint('🔍 收到登入消息: ${event.data}');
          onMessage(event.data.toString());
        }
      });
    }
  }

  /// 移除消息監聽器
  static void removeMessageListener() {
    if (canUseWebAPI) {
      // 在實際應用中，您可能需要保存監聽器引用以便移除
      debugPrint('📱 移除消息監聽器');
    }
  }
}

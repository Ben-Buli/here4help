import 'package:flutter/foundation.dart';
import 'package:here4help/config/environment_config_legacy.dart';

// 條件導入：根據平台選擇不同的實現
import 'web_environment_bridge_stub.dart'
    if (dart.library.html) 'web_environment_bridge_web.dart';

/// Web 環境配置橋接器
/// 安全地將 Flutter 環境配置傳遞給 Web JavaScript
class WebEnvironmentBridge {
  static WebEnvironmentBridge? _instance;
  static WebEnvironmentBridge get instance =>
      _instance ??= WebEnvironmentBridge._();

  WebEnvironmentBridge._() {
    if (kIsWeb) {
      WebEnvironmentBridgeImpl.setupMessageListener();
    }
  }

  /// 手動初始化配置傳送
  void initializeWebConfig() {
    if (kIsWeb) {
      // 延遲執行，確保 JavaScript 已準備好
      Future.delayed(const Duration(milliseconds: 500), () {
        WebEnvironmentBridgeImpl.handleEnvironmentConfigRequest();
      });
    }
  }

  /// 檢查 Web 環境配置是否完整
  bool isWebConfigComplete() {
    return EnvironmentConfig.googleClientId.isNotEmpty &&
        EnvironmentConfig.facebookAppId.isNotEmpty &&
        EnvironmentConfig.appleServiceId.isNotEmpty;
  }

  /// 獲取 Web 環境配置摘要
  Map<String, String> getWebConfigSummary() {
    return {
      'google_status':
          EnvironmentConfig.googleClientId.isNotEmpty ? '已配置' : '未配置',
      'facebook_status':
          EnvironmentConfig.facebookAppId.isNotEmpty ? '已配置' : '未配置',
      'apple_status':
          EnvironmentConfig.appleServiceId.isNotEmpty ? '已配置' : '未配置',
    };
  }
}

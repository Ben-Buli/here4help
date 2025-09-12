import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:here4help/config/environment_config_legacy.dart';

/// Web 平台專用的環境配置橋接器實現
class WebEnvironmentBridgeImpl {
  /// 設置消息監聽器
  static void setupMessageListener() {
    html.window.addEventListener('message', (event) {
      final messageEvent = event as html.MessageEvent;

      if (messageEvent.data is Map) {
        final data = Map<String, dynamic>.from(messageEvent.data);

        if (data['type'] == 'REQUEST_ENVIRONMENT_CONFIG' &&
            data['source'] == 'web_oauth_handler') {
          handleEnvironmentConfigRequest();
        }
      }
    });
  }

  /// 處理環境配置請求
  static void handleEnvironmentConfigRequest() {
    try {
      // 僅傳遞公開的配置（不包含敏感信息）
      final publicConfig = {
        'google_client_id': EnvironmentConfig.googleClientId,
        'google_redirect_uri': EnvironmentConfig.googleRedirectUri,
        'facebook_app_id': EnvironmentConfig.facebookAppId,
        'facebook_redirect_uri': EnvironmentConfig.facebookRedirectUri,
        'apple_service_id': EnvironmentConfig.appleServiceId,
        'apple_redirect_uri': EnvironmentConfig.appleRedirectUri,
      };

      // 發送配置到 JavaScript
      html.window.postMessage({
        'type': 'ENVIRONMENT_CONFIG_RESPONSE',
        'config': publicConfig,
      }, '*');

      if (kDebugMode) {
        print('✅ Web 環境配置已傳送到 JavaScript');
        print(
            '🔑 Google Client ID: ${EnvironmentConfig.googleClientId.isNotEmpty ? "已配置" : "未配置"}');
        print(
            '🔑 Facebook App ID: ${EnvironmentConfig.facebookAppId.isNotEmpty ? "已配置" : "未配置"}');
        print(
            '🔑 Apple Service ID: ${EnvironmentConfig.appleServiceId.isNotEmpty ? "已配置" : "未配置"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Web 環境配置傳送失敗: $e');
      }
    }
  }
}

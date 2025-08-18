import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EnvironmentConfig {
  static Map<String, dynamic>? _config;

  /// 初始化配置
  static Future<void> initialize() async {
    if (_config != null) return;

    try {
      const environment = String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: 'development',
      );

      final configFile = 'assets/app_env/$environment.json';
      final configString = await rootBundle.loadString(configFile);
      _config = json.decode(configString) as Map<String, dynamic>;

      if (kDebugMode) {
        print('🌍 環境配置已載入: $environment');
        print('📁 配置檔案: $configFile');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 載入環境配置失敗: $e');
        print('💡 使用預設配置');
      }
      // 使用預設配置
      _config = {
        'environment': 'development',
        'public': {
          'api_base_url': 'http://localhost:8888/here4help',
          'socket_url': 'http://localhost:3001',
          'image_base_url': 'http://localhost:8888/here4help',
          'google_client_id': '',
          'facebook_app_id': '',
          'apple_service_id': '',
        },
        'app': {
          'debug_mode': true,
          'log_level': 'debug',
          'features': {},
        },
      };
    }
  }

  /// 當前環境
  static String get environment => _config?['environment'] ?? 'development';

  /// 是否為開發環境
  static bool get isDevelopment => environment == 'development';

  /// 是否為生產環境
  static bool get isProduction => environment == 'production';

  /// 是否為測試環境
  static bool get isStaging => environment == 'staging';

  /// API 基礎 URL
  static String get apiBaseUrl =>
      _config?['public']?['api_base_url'] ?? 'http://localhost:8888/here4help';

  /// Socket 伺服器 URL
  static String get socketUrl =>
      _config?['public']?['socket_url'] ?? 'http://localhost:3001';

  /// 圖片基礎 URL
  static String get imageBaseUrl =>
      _config?['public']?['image_base_url'] ?? apiBaseUrl;

  /// 是否啟用調試模式
  static bool get debugMode => _config?['app']?['debug_mode'] ?? true;

  /// 日誌級別
  static String get logLevel => _config?['app']?['log_level'] ?? 'debug';

  /// 功能開關
  static Map<String, bool> get features =>
      Map<String, bool>.from(_config?['app']?['features'] ?? {});

  /// Google Client ID (公開)
  static String get googleClientId =>
      _config?['public']?['google_client_id'] ?? '';

  /// Facebook App ID (公開)
  static String get facebookAppId =>
      _config?['public']?['facebook_app_id'] ?? '';

  /// Apple Service ID (公開)
  static String get appleServiceId =>
      _config?['public']?['apple_service_id'] ?? '';

  /// 獲取完整的圖片 URL
  static String getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return '';
    }

    // 如果已經是完整 URL，直接返回
    if (relativePath.startsWith('http://') ||
        relativePath.startsWith('https://')) {
      return relativePath;
    }

    // 如果是本地資源，直接返回
    if (relativePath.startsWith('assets/')) {
      return relativePath;
    }

    // 移除開頭的斜線
    if (relativePath.startsWith('/')) {
      relativePath = relativePath.substring(1);
    }

    return '$imageBaseUrl/$relativePath';
  }

  /// 調試信息
  static void printEnvironmentInfo() {
    if (kDebugMode) {
      print('🌍 當前環境: $environment');
      print('🔗 API 基礎 URL: $apiBaseUrl');
      print('🔌 Socket URL: $socketUrl');
      print('🖼️ 圖片基礎 URL: $imageBaseUrl');
      print('🐛 調試模式: $debugMode');
      print('📝 日誌級別: $logLevel');
      print('⚙️ 功能開關: $features');
      print(
          '🔑 Google Client ID: ${googleClientId.isNotEmpty ? "已配置" : "未配置"}');
      print('🔑 Facebook App ID: ${facebookAppId.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Apple Service ID: ${appleServiceId.isNotEmpty ? "已配置" : "未配置"}');
    }
  }
}

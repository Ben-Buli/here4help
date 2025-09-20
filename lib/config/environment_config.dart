/// ⚠️ 此文件已廢棄 - 請使用新的 .env 系統
///
/// 舊的 JSON 配置系統已被新的 .env 系統取代
/// 所有功能已遷移到 environment_config_legacy.dart
///
/// 新系統特點：
/// - 使用 flutter_dotenv 管理環境變數
/// - 支持多環境配置 (.env.development, .env.production 等)
/// - 更安全的敏感資訊管理
/// - 統一的端口和 URL 配置
///
/// @deprecated 使用 environment_config_legacy.dart 替代
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:here4help/config/env_config.dart';

@Deprecated('使用新的 .env 系統和 environment_config_legacy.dart')
class EnvironmentConfig {
  static Map<String, dynamic>? _config;
  static final bool _useEnvConfig = true; // 切換到新的 .env 系統

  /// 檢測是否為 Android 模擬器
  static bool _isAndroidEmulator() {
    // 在 Web 平台不使用模擬器配置
    if (kIsWeb) return false;

    // 檢查環境變數
    const androidEmulator =
        bool.fromEnvironment('ANDROID_EMULATOR', defaultValue: false);
    if (androidEmulator) {
      debugPrint('🔧 檢測到 ANDROID_EMULATOR 環境變數');
      return true;
    }

    // 檢查是否在 Android 平台上運行
    if (defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('🔧 檢測到 Android 平台，使用模擬器配置');
      return true;
    }

    return false;
  }

  /// 檢測是否為 iOS 模擬器
  static bool _isIOSSimulator() {
    // 在 Web 平台不使用模擬器配置
    if (kIsWeb) return false;

    // 檢查環境變數
    const iosSimulator =
        bool.fromEnvironment('IOS_SIMULATOR', defaultValue: false);
    if (iosSimulator) {
      debugPrint('🔧 檢測到 IOS_SIMULATOR 環境變數');
      return true;
    }

    // 檢查是否在 iOS 平台上運行
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('🔧 檢測到 iOS 平台，使用模擬器配置');
      return true;
    }

    return false;
  }

  /// 檢測是否為 Web 平台
  static bool _isWebPlatform() {
    return kIsWeb;
  }

  /// 獲取正確的網路地址
  static String _getNetworkAddress(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      if (defaultTargetPlatform == TargetPlatform.android &&
          (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
        return uri.replace(host: '10.0.2.2').toString();
      }
      return baseUrl;
    } catch (_) {
      return baseUrl;
    }
  }

  /// 獲取環境變數值（安全方式）
  static String _getEnvValue(String key) {
    try {
      return EnvConfig.get(key);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 無法獲取環境變數 $key: $e');
      }
      return '';
    }
  }

  /// 初始化配置
  static Future<void> initialize() async {
    if (_config != null) return;

    try {
      String environment = const String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: 'development',
      );

      // 檢測 Web 平台並使用相應配置
      if (_isWebPlatform()) {
        environment = 'web';
        if (kDebugMode) {
          print('🌐 檢測到 Web 平台，使用 web 配置');
        }
      }
      // 檢測 Android 模擬器並使用相應配置
      else if (_isAndroidEmulator()) {
        environment = 'android_emulator';
        if (kDebugMode) {
          print('🤖 檢測到 Android 模擬器，使用 android_emulator 配置');
        }
      }
      // 檢測 iOS 模擬器並使用相應配置
      else if (_isIOSSimulator()) {
        environment = 'ios_simulator';
        if (kDebugMode) {
          print('🍎 檢測到 iOS 模擬器，使用 ios_simulator 配置');
        }
      }

      final configFile = 'assets/app_env/$environment.json';
      final configString = await rootBundle.loadString(configFile);
      _config = json.decode(configString) as Map<String, dynamic>;

      if (kDebugMode) {
        print('🌍 環境配置已載入: $environment');
        print('📁 配置檔案: $configFile');
        print(
            '🔑 Google Client ID: ${_config?['public']?['google_client_id'] ?? 'NULL'}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 載入環境配置失敗: $e');
        print('💡 使用預設配置');
      }
      // 使用預設配置 - 移除所有硬編程的敏感資訊
      _config = {
        'environment': 'development',
        'public': {
          'api_base_url': _getNetworkAddress(EnvConfig.apiBaseUrl),
          'socket_url': _getNetworkAddress(EnvConfig.socketUrl),
          'image_base_url': _getNetworkAddress(EnvConfig.imageBaseUrl),
          // 使用環境變數而非硬編程敏感資訊
          'google_client_id': _getEnvValue('GOOGLE_CLIENT_ID'),
          'google_redirect_uri': _getEnvValue('GOOGLE_REDIRECT_URI'),
          'facebook_app_id': _getEnvValue('FACEBOOK_APP_ID'),
          'facebook_redirect_uri': _getEnvValue('FACEBOOK_REDIRECT_URI'),
          'apple_service_id': _getEnvValue('APPLE_SERVICE_ID'),
          'apple_redirect_uri': _getEnvValue('APPLE_REDIRECT_URI'),
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
  static String get apiBaseUrl {
    final baseUrl = _config?['public']?['api_base_url'] ?? EnvConfig.apiBaseUrl;
    return _getNetworkAddress(baseUrl);
  }

  /// API Origin（scheme + host[:port]）
  static String get apiOrigin {
    final origin = _config?['public']?['api_origin'] ?? apiBaseUrl;
    return _getNetworkAddress(origin);
  }

  /// API Prefix（例：/api 或 /here4help/backend/api）
  static String get apiPrefix {
    final prefix = _config?['public']?['api_prefix'] ?? '/api';
    if (prefix.isEmpty) return '';
    return prefix.startsWith('/') ? prefix : '/$prefix';
  }

  /// Socket 伺服器 URL
  static String get socketUrl {
    final socketUrlValue =
        _config?['public']?['socket_url'] ?? EnvConfig.socketUrl;
    // 使用正確的網路地址分流邏輯
    return _getNetworkAddress(socketUrlValue);
  }

  /// 圖片基礎 URL
  static String get imageBaseUrl {
    final imageUrl = _config?['public']?['image_base_url'] ?? apiBaseUrl;
    // 使用正確的網路地址分流邏輯
    return _getNetworkAddress(imageUrl);
  }

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

  /// Google Redirect URI (公開)
  static String get googleRedirectUri =>
      _config?['public']?['google_redirect_uri'] ?? '';

  /// Facebook App ID (公開)
  static String get facebookAppId =>
      _config?['public']?['facebook_app_id'] ?? '';

  /// Facebook Redirect URI (公開)
  static String get facebookRedirectUri =>
      _config?['public']?['facebook_redirect_uri'] ?? '';

  /// Apple Service ID (公開)
  static String get appleServiceId =>
      _config?['public']?['apple_service_id'] ?? '';

  /// Apple Redirect URI (公開)
  static String get appleRedirectUri =>
      _config?['public']?['apple_redirect_uri'] ?? '';

  /// Google Android Client ID (公開)
  static String get googleAndroidClientId =>
      _config?['public']?['google_android_client_id'] ?? '';

  /// Google iOS Client ID (公開)
  static String get googleIosClientId =>
      _config?['public']?['google_ios_client_id'] ?? '';

  /// Google Web Client Secret (公開)
  static String get googleWebClientSecret =>
      _config?['public']?['google_web_client_secret'] ?? '';

  /// Facebook App Secret (公開)
  static String get facebookAppSecret =>
      _config?['public']?['facebook_app_secret'] ?? '';

  /// Apple Key ID (公開)
  static String get appleKeyId => _config?['public']?['apple_key_id'] ?? '';

  /// Apple Team ID (公開)
  static String get appleTeamId => _config?['public']?['apple_team_id'] ?? '';

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
      print(
          '🔑 Google Redirect URI: ${googleRedirectUri.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Google Android Client ID: ${googleAndroidClientId.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Google iOS Client ID: ${googleIosClientId.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Google Web Client Secret: ${googleWebClientSecret.isNotEmpty ? "已配置" : "未配置"}');
      print('🔑 Facebook App ID: ${facebookAppId.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Facebook Redirect URI: ${facebookRedirectUri.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Facebook App Secret: ${facebookAppSecret.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Apple Service ID: ${appleServiceId.isNotEmpty ? "已配置" : "未配置"}');
      print(
          '🔑 Apple Redirect URI: ${appleRedirectUri.isNotEmpty ? "已配置" : "未配置"}');
      print('🔑 Apple Key ID: ${appleKeyId.isNotEmpty ? "已配置" : "未配置"}');
      print('🔑 Apple Team ID: ${appleTeamId.isNotEmpty ? "已配置" : "未配置"}');

      print('🔒 注意：敏感資訊已移至後端環境配置');
    }
  }

  /// 預設 API 基礎 URL
  static String _getDefaultApiBaseUrl() {
    return EnvConfig.apiBaseUrl;
  }

  /// 預設 Socket 伺服器 URL
  static String _getDefaultSocketUrl() {
    return EnvConfig.socketUrl;
  }

  /// 檢查是否為 Android 模擬器
  static bool _isAndroidEmulatorFromEnv() {
    // 簡化檢測，避免複雜邏輯
    return false;
  }

  /// 為 Android 模擬器調整 API 基礎 URL
  static void _adjustForAndroidEmulator() {
    if (kDebugMode) {
      print('🔧 為 Android 模擬器調整 API 基礎 URL');
    }
    // 暫時不進行調整，使用配置文件來處理
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/environment_config.dart';

/// 全域錯誤上報服務
class ErrorReportingService {
  static const String _errorLogKey = 'error_reports';
  static const int _maxLocalErrors = 50;
  static const Duration _reportInterval = Duration(minutes: 5);

  static DateTime? _lastReportTime;
  static List<Map<String, dynamic>> _pendingReports = [];

  /// 初始化全域錯誤處理
  static void initialize() {
    // 設置 Flutter 錯誤處理器
    FlutterError.onError = (FlutterErrorDetails details) {
      // 在 debug 模式下仍然顯示錯誤
      if (kDebugMode) {
        FlutterError.presentError(details);
      }

      // 上報錯誤
      _reportFlutterError(details);
    };

    // 設置 Dart 未捕獲異常處理器
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportDartError(error, stack);
      return true;
    };

    debugPrint('🔍 ErrorReportingService initialized');
  }

  /// 手動上報錯誤
  static Future<void> reportError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    ErrorSeverity severity = ErrorSeverity.error,
  }) async {
    try {
      final errorReport = await _createErrorReport(
        error: error,
        stackTrace: stackTrace,
        context: context,
        additionalData: additionalData,
        severity: severity,
      );

      await _queueErrorReport(errorReport);
    } catch (e) {
      debugPrint('Failed to report error: $e');
    }
  }

  /// 上報 Flutter 錯誤
  static Future<void> _reportFlutterError(FlutterErrorDetails details) async {
    try {
      final errorReport = await _createErrorReport(
        error: details.exception,
        stackTrace: details.stack,
        context: details.context?.toString(),
        additionalData: {
          'library': details.library,
          'informationCollector': details.informationCollector?.toString(),
        },
        severity: ErrorSeverity.error,
        errorType: 'flutter_error',
      );

      await _queueErrorReport(errorReport);
    } catch (e) {
      debugPrint('Failed to report Flutter error: $e');
    }
  }

  /// 上報 Dart 錯誤
  static Future<void> _reportDartError(
      dynamic error, StackTrace stackTrace) async {
    try {
      final errorReport = await _createErrorReport(
        error: error,
        stackTrace: stackTrace,
        context: 'Uncaught Dart Exception',
        severity: ErrorSeverity.critical,
        errorType: 'dart_error',
      );

      await _queueErrorReport(errorReport);
    } catch (e) {
      debugPrint('Failed to report Dart error: $e');
    }
  }

  /// 創建錯誤報告
  static Future<Map<String, dynamic>> _createErrorReport({
    required dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    ErrorSeverity severity = ErrorSeverity.error,
    String errorType = 'manual',
  }) async {
    final deviceInfo = await _getDeviceInfo();
    final appInfo = await _getAppInfo();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'error_type': errorType,
      'severity': severity.name,
      'message': error.toString(),
      'stack_trace': stackTrace?.toString(),
      'context': context,
      'device_info': deviceInfo,
      'app_info': appInfo,
      'additional_data': additionalData,
      'user_id': await _getCurrentUserId(),
      'session_id': await _getSessionId(),
    };
  }

  /// 將錯誤報告加入佇列
  static Future<void> _queueErrorReport(
      Map<String, dynamic> errorReport) async {
    try {
      // 添加到內存佇列
      _pendingReports.add(errorReport);

      // 保存到本地存儲
      await _saveErrorReportLocally(errorReport);

      // 檢查是否需要立即上報
      final now = DateTime.now();
      if (_lastReportTime == null ||
          now.difference(_lastReportTime!) > _reportInterval ||
          errorReport['severity'] == ErrorSeverity.critical.name) {
        await _sendPendingReports();
        _lastReportTime = now;
      }
    } catch (e) {
      debugPrint('Failed to queue error report: $e');
    }
  }

  /// 發送待處理的錯誤報告
  static Future<void> _sendPendingReports() async {
    if (_pendingReports.isEmpty) return;

    try {
      final reports = List<Map<String, dynamic>>.from(_pendingReports);
      _pendingReports.clear();

      final response = await HttpClientService.post(
        '${EnvironmentConfig.apiBaseUrl}/system/error-reports',
        body: jsonEncode({
          'reports': reports,
          'batch_size': reports.length,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Sent ${reports.length} error reports');
        await _clearLocalErrorReports();
      } else {
        // 如果發送失敗，重新加入佇列
        _pendingReports.addAll(reports);
        debugPrint('❌ Failed to send error reports: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error sending reports: $e');
      // 網絡錯誤時保留報告，稍後重試
    }
  }

  /// 獲取設備信息
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'hardware': androidInfo.hardware,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'localized_model': iosInfo.localizedModel,
          'identifier_for_vendor': iosInfo.identifierForVendor,
        };
      } else {
        return {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }
    } catch (e) {
      return {
        'platform': Platform.operatingSystem,
        'error': 'Failed to get device info: $e',
      };
    }
  }

  /// 獲取應用信息
  static Future<Map<String, dynamic>> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      return {
        'app_name': packageInfo.appName,
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'build_signature': packageInfo.buildSignature,
      };
    } catch (e) {
      return {
        'error': 'Failed to get app info: $e',
      };
    }
  }

  /// 獲取當前用戶 ID
  static Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (e) {
      return null;
    }
  }

  /// 獲取會話 ID
  static Future<String> _getSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('session_id');

      if (sessionId == null) {
        sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('session_id', sessionId);
      }

      return sessionId;
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// 保存錯誤報告到本地
  static Future<void> _saveErrorReportLocally(
      Map<String, dynamic> errorReport) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final errorReports = prefs.getStringList(_errorLogKey) ?? [];

      errorReports.add(errorReport.toString());

      // 只保留最近的錯誤報告
      if (errorReports.length > _maxLocalErrors) {
        errorReports.removeRange(0, errorReports.length - _maxLocalErrors);
      }

      await prefs.setStringList(_errorLogKey, errorReports);
    } catch (e) {
      debugPrint('Failed to save error report locally: $e');
    }
  }

  /// 清除本地錯誤報告
  static Future<void> _clearLocalErrorReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_errorLogKey);
    } catch (e) {
      debugPrint('Failed to clear local error reports: $e');
    }
  }

  /// 獲取本地錯誤報告
  static Future<List<String>> getLocalErrorReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_errorLogKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// 手動觸發發送待處理報告
  static Future<void> flushPendingReports() async {
    await _sendPendingReports();
  }

  /// 設置用戶 ID（登錄時調用）
  static Future<void> setUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
    } catch (e) {
      debugPrint('Failed to set user ID: $e');
    }
  }

  /// 清除用戶 ID（登出時調用）
  static Future<void> clearUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    } catch (e) {
      debugPrint('Failed to clear user ID: $e');
    }
  }
}

/// 錯誤嚴重程度
enum ErrorSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

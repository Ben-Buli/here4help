import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_platform/universal_platform.dart';

class PlatformInfoHelper {
  static String detectPlatform() {
    if (UniversalPlatform.isWeb) return 'web';
    if (UniversalPlatform.isIOS) return 'ios';
    if (UniversalPlatform.isAndroid) return 'android';
    if (UniversalPlatform.isMacOS) return 'macos';
    if (UniversalPlatform.isWindows) return 'windows';
    if (UniversalPlatform.isLinux) return 'linux';
    return 'unknown';
  }

  static Future<String?> buildDeviceDescription() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (UniversalPlatform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        final manufacturer = info.manufacturer.trim();
        final model = info.model.trim();
        final version = info.version.release;
        return [
          if (manufacturer != null && manufacturer.isNotEmpty) manufacturer,
          if (model != null && model.isNotEmpty) model,
          if (version.isNotEmpty) '(Android $version)',
        ].join(' ').trim();
      }

      if (UniversalPlatform.isIOS) {
        final info = await deviceInfo.iosInfo;
        final name = info.name;
        final systemVersion = info.systemVersion;
        return [
          if (name.isNotEmpty) name,
          if (systemVersion.isNotEmpty) '(iOS $systemVersion)',
        ].join(' ').trim();
      }

      if (UniversalPlatform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        return 'macOS ${info.osRelease}';
      }

      if (UniversalPlatform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        return 'Windows ${info.productName} (${info.displayVersion})';
      }

      if (UniversalPlatform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        return 'Linux ${info.prettyName}';
      }

      if (UniversalPlatform.isWeb) {
        final info = await deviceInfo.webBrowserInfo;
        final vendor = info.vendor;
        final browserName = describeEnum(info.browserName);
        return [vendor, browserName]
            .where((part) => part != null && part.isNotEmpty)
            .join(' ');
      }
    } catch (_) {
      // Ignore failures and fall back below
    }

    return describeEnum(defaultTargetPlatform);
  }

  static Future<String?> userAgent() async {
    if (!UniversalPlatform.isWeb) return null;

    try {
      final info = await DeviceInfoPlugin().webBrowserInfo;
      return info.userAgent;
    } catch (_) {
      return null;
    }
  }
}

import 'package:flutter/foundation.dart';

class PathMapper {
  /// MAMP 的基礎 URL
  static const String mampBaseUrl = 'http://localhost:8888/here4help';

  /// 專案實際路徑
  static const String projectPath = '/Users/eliasscott/here4help';

  /// MAMP 符號連結路徑
  static const String mampSymlinkPath = '/Applications/MAMP/htdocs/here4help';

  /// 將資料庫中的路徑映射到可訪問的 URL
  static String mapDatabasePathToUrl(String? databasePath) {
    if (databasePath == null || databasePath.isEmpty) {
      return '';
    }

    // 如果已經是完整 URL，直接返回
    if (databasePath.startsWith('http://') ||
        databasePath.startsWith('https://')) {
      return databasePath;
    }

    // 如果是本地資源路徑（assets/），直接返回
    if (databasePath.startsWith('assets/')) {
      return databasePath;
    }

    // 移除開頭的斜線
    String cleanPath =
        databasePath.startsWith('/') ? databasePath.substring(1) : databasePath;

    // 檢查是否是 Flutter assets 路徑
    if (cleanPath.startsWith('assets/')) {
      return cleanPath;
    }

    // 檢查是否是後端上傳的圖片路徑
    if (cleanPath.startsWith('backend/uploads/')) {
      return '$mampBaseUrl/$cleanPath';
    }

    // 檢查是否是測試圖片路徑
    if (cleanPath.startsWith('test_images/')) {
      return '$mampBaseUrl/$cleanPath';
    }

    // 預設情況：假設是相對於 MAMP 根目錄的路徑
    return '$mampBaseUrl/$cleanPath';
  }

  /// 將專案路徑映射到 MAMP URL
  static String mapProjectPathToMampUrl(String projectRelativePath) {
    if (projectRelativePath.startsWith('/')) {
      projectRelativePath = projectRelativePath.substring(1);
    }

    // 移除專案根目錄路徑
    if (projectRelativePath.startsWith('here4help/')) {
      projectRelativePath = projectRelativePath.substring('here4help/'.length);
    }

    return '$mampBaseUrl/$projectRelativePath';
  }

  /// 檢查路徑是否為 Flutter assets
  static bool isFlutterAsset(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('assets/');
  }

  /// 檢查路徑是否為後端上傳檔案
  static bool isBackendUpload(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('backend/uploads/') || path.startsWith('uploads/');
  }

  /// 檢查路徑是否為測試圖片
  static bool isTestImage(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('test_images/');
  }

  /// 獲取預設頭像路徑
  static String getDefaultAvatarPath() {
    return 'assets/images/avatar/avatar-1.png';
  }

  /// 調試路徑映射
  static void debugPathMapping(String? originalPath) {
    if (!kDebugMode) return;

    print('🔍 路徑映射調試');
    print('📁 原始路徑: $originalPath');

    if (originalPath == null || originalPath.isEmpty) {
      print('❌ 路徑為空');
      return;
    }

    if (isFlutterAsset(originalPath)) {
      print('✅ Flutter assets 路徑');
      print('📦 資源路徑: $originalPath');
    } else if (isBackendUpload(originalPath)) {
      print('✅ 後端上傳檔案');
      String mappedUrl = mapDatabasePathToUrl(originalPath);
      print('🌐 映射 URL: $mappedUrl');
    } else if (isTestImage(originalPath)) {
      print('✅ 測試圖片');
      String mappedUrl = mapDatabasePathToUrl(originalPath);
      print('🌐 映射 URL: $mappedUrl');
    } else {
      print('⚠️ 未知路徑類型');
      String mappedUrl = mapDatabasePathToUrl(originalPath);
      print('🌐 預設映射 URL: $mappedUrl');
    }
  }
}

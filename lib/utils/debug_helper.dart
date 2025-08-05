import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';
import 'image_helper.dart';

class DebugHelper {
  /// 診斷用戶頭像路徑問題
  static void diagnoseAvatarPath(String? avatarUrl, String userEmail) {
    if (!kDebugMode) return;

    print('🔍 診斷用戶頭像路徑問題');
    print('📧 用戶郵箱: $userEmail');
    print('🖼️ 原始頭像路徑: $avatarUrl');

    if (avatarUrl == null || avatarUrl.isEmpty) {
      print('❌ 頭像路徑為空或 null');
      return;
    }

    // 檢查路徑類型
    if (ImageHelper.isNetworkImage(avatarUrl)) {
      print('✅ 網路圖片路徑');
      print('🌐 完整 URL: $avatarUrl');
    } else if (ImageHelper.isLocalAsset(avatarUrl)) {
      print('✅ 本地資源路徑');
      print('📁 資源路徑: $avatarUrl');
    } else {
      print('⚠️ 相對路徑，需要構建完整 URL');
      String fullUrl = EnvironmentConfig.getFullImageUrl(avatarUrl);
      print('🔗 構建後的完整 URL: $fullUrl');
    }

    // 打印環境信息
    EnvironmentConfig.printEnvironmentInfo();
  }

  /// 測試圖片 URL 是否可訪問
  static Future<bool> testImageUrl(String url) async {
    try {
      final response = await Future.delayed(const Duration(seconds: 2));
      // 這裡可以添加實際的 HTTP 請求來測試圖片 URL
      print('✅ 圖片 URL 測試通過: $url');
      return true;
    } catch (e) {
      print('❌ 圖片 URL 測試失敗: $url');
      print('💥 錯誤: $e');
      return false;
    }
  }

  /// 打印用戶資料中的圖片相關信息
  static void printUserImageInfo(Map<String, dynamic> userData) {
    if (!kDebugMode) return;

    print('👤 用戶圖片信息診斷');
    print('🆔 用戶 ID: ${userData['id']}');
    print('📧 郵箱: ${userData['email']}');
    print('🖼️ 頭像路徑: ${userData['avatar_url']}');

    // 診斷頭像路徑
    diagnoseAvatarPath(userData['avatar_url'], userData['email']);
  }
}

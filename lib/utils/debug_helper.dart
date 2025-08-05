import 'package:flutter/foundation.dart';
import '../config/environment_config.dart';
import 'image_helper.dart';

class DebugHelper {
  /// 診斷用戶頭像路徑問題
  static void diagnoseAvatarPath(String? avatarUrl, String userEmail) {
    if (!kDebugMode) return;
    // Debug print statements removed
  }

  /// 測試圖片 URL 是否可訪問
  static Future<bool> testImageUrl(String url) async {
    try {
      final response = await Future.delayed(const Duration(seconds: 2));
      // 這裡可以添加實際的 HTTP 請求來測試圖片 URL
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 打印用戶資料中的圖片相關信息
  static void printUserImageInfo(Map<String, dynamic> userData) {
    if (!kDebugMode) return;
    // Debug print statements removed
  }
}

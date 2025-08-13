import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/services/auth_service.dart';

/// 調試和修復認證問題的輔助工具
class DebugAuthHelper {
  /// 完全清除所有認證數據並強制重新登入
  static Future<void> forceLogoutAndClear() async {
    try {
      debugPrint('🧹 開始強制清除所有認證數據...');

      final prefs = await SharedPreferences.getInstance();

      // 1. 清除 AuthService 的所有 token
      await AuthService.logout();
      debugPrint('✅ AuthService tokens 已清除');

      // 2. 清除所有可能的認證相關 keys
      final allKeys = prefs.getKeys().toList();
      final authKeys = allKeys.where((key) =>
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('auth') ||
          key.toLowerCase().contains('jwt') ||
          key.toLowerCase().contains('user') ||
          key.startsWith('user_'));

      for (String key in authKeys) {
        await prefs.remove(key);
        debugPrint('✅ 清除: $key');
      }

      // 3. 清除圖片緩存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('✅ 圖片緩存已清除');

      debugPrint('🎉 所有認證數據清除完成！請重新登入。');
    } catch (e) {
      debugPrint('❌ 清除認證數據失敗: $e');
      rethrow;
    }
  }

  /// 檢查當前認證狀態
  static Future<void> debugCurrentAuthState() async {
    try {
      debugPrint('🔍 === 當前認證狀態檢查 ===');

      // 檢查 token
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('🔍 狀態：未登入（無 token）');
        return;
      }

      debugPrint('🔍 Token 長度: ${token.length}');
      debugPrint(
          '🔍 Token 前 20 字元: ${token.substring(0, token.length > 20 ? 20 : token.length)}');

      // 檢查 token 格式
      if (token.startsWith('eyJ')) {
        debugPrint('❌ 問題：JWT 格式的 token');
        debugPrint('💡 解決方案：需要清除並重新登入');
      } else {
        debugPrint('✅ Token 格式正確');
      }

      // 檢查 SharedPreferences 中的用戶資料
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final avatarUrl = prefs.getString('user_avatarUrl');

      debugPrint('🔍 SharedPreferences 用戶資料:');
      debugPrint('  - Email: $email');
      debugPrint('  - Avatar URL: ${avatarUrl ?? "NULL"}');
    } catch (e) {
      debugPrint('❌ 檢查認證狀態失敗: $e');
    }
  }

  /// 測試 API 連接
  static Future<void> testApiConnection() async {
    try {
      debugPrint('🔍 === 測試 API 連接 ===');

      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('❌ 無 token，無法測試 API');
        return;
      }

      // 嘗試調用 profile API
      try {
        await AuthService.getProfile();
        debugPrint('✅ API 調用成功');
      } catch (e) {
        debugPrint('❌ API 調用失敗: $e');
        debugPrint('💡 建議：清除 token 並重新登入');
      }
    } catch (e) {
      debugPrint('❌ 測試 API 失敗: $e');
    }
  }
}

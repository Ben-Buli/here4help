import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/services/auth_service.dart';

/// 用於重置認證狀態的輔助工具
class AuthResetHelper {
  /// 完全清除所有認證和用戶數據
  static Future<void> clearAllAuthData() async {
    try {
      debugPrint('🧹 開始清除所有認證數據...');

      final prefs = await SharedPreferences.getInstance();

      // 清除 AuthService token
      await AuthService.logout();
      debugPrint('✅ AuthService token 已清除');

      // 清除 UserService 相關的 SharedPreferences
      final userKeys = [
        'user_id',
        'user_name',
        'user_nickname',
        'user_email',
        'user_points',
        'user_avatarUrl',
        'user_primaryLang',
        'user_permission',
        'user_phone',
        'user_status',
        'user_provider',
        'user_created_at',
        'user_updated_at',
        'user_referral_code',
        'user_google_id',
      ];

      for (String key in userKeys) {
        await prefs.remove(key);
      }
      debugPrint('✅ UserService SharedPreferences 已清除');

      // 清除可能的舊 token（如果使用了不同的 key）
      final allKeys = prefs.getKeys();
      for (String key in allKeys) {
        if (key.toLowerCase().contains('token') ||
            key.toLowerCase().contains('auth') ||
            key.toLowerCase().contains('jwt')) {
          await prefs.remove(key);
          debugPrint('✅ 清除可疑的認證 key: $key');
        }
      }

      // 清除圖片緩存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      debugPrint('✅ 圖片緩存已清除');

      debugPrint('🎉 所有認證數據清除完成！請重新登入。');
    } catch (e) {
      debugPrint('❌ 清除認證數據失敗: $e');
      rethrow;
    }
  }

  /// 檢查當前 token 格式
  static Future<void> debugCurrentToken() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('🔍 當前沒有 token');
        return;
      }

      debugPrint('🔍 當前 token 長度: ${token.length}');
      debugPrint(
          '🔍 Token 前 20 字元: ${token.substring(0, token.length > 20 ? 20 : token.length)}');

      // 檢查是否為 JWT 格式 (通常以 eyJ 開頭)
      if (token.startsWith('eyJ')) {
        debugPrint('⚠️ 檢測到 JWT 格式的 token！');
        debugPrint('⚠️ 但後端期望 base64 編碼的 JSON 格式');
        debugPrint('💡 建議清除此 token 並重新登入');
      } else {
        debugPrint('✅ Token 格式看起來正確（非 JWT）');
      }
    } catch (e) {
      debugPrint('❌ 檢查 token 失敗: $e');
    }
  }
}

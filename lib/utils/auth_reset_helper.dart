import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
    } catch (e) {
      debugPrint('❌ 檢查 token 失敗: $e');
    }
  }

  /// 驗證 JWT 結構
  static void _validateJWTStructure(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        debugPrint('✅ JWT 結構正確：3 個部分');

        // 檢查 header 部分
        try {
          final header = parts[0];
          final decodedHeader = _base64UrlDecode(header);
          debugPrint('🔍 JWT Header: $decodedHeader');
        } catch (e) {
          debugPrint('⚠️ JWT Header 解碼失敗: $e');
        }

        // 檢查 payload 部分（不顯示敏感信息）
        try {
          final payload = parts[1];
          final decodedPayload = _base64UrlDecode(payload);
          debugPrint('🔍 JWT Payload 長度: ${decodedPayload.length} 字元');
        } catch (e) {
          debugPrint('⚠️ JWT Payload 解碼失敗: $e');
        }

        // 檢查 signature 部分
        final signature = parts[2];
        debugPrint('🔍 JWT Signature 長度: ${signature.length} 字元');
      } else {
        debugPrint('⚠️ JWT 結構不正確：${parts.length} 個部分（期望 3 個）');
      }
    } catch (e) {
      debugPrint('❌ JWT 結構驗證失敗: $e');
    }
  }

  /// Base64 URL 解碼（JWT 使用）
  static String _base64UrlDecode(String input) {
    // 替換 URL 安全字符
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');

    // 添加填充
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    // Base64 解碼
    final bytes = base64Decode(normalized);
    return utf8.decode(bytes);
  }

  /// 檢查 JWT Token 是否即將過期
  static Future<bool> isJWTTokenExpiringSoon() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || !token.startsWith('eyJ')) {
        return false; // 不是 JWT 或沒有 token
      }

      final parts = token.split('.');
      if (parts.length != 3) {
        return false; // 不是有效的 JWT
      }

      try {
        final payload = parts[1];
        final decodedPayload = _base64UrlDecode(payload);
        final payloadData = jsonDecode(decodedPayload);

        final exp = payloadData['exp'];
        if (exp == null) {
          return false; // 沒有過期時間
        }

        final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();
        final timeUntilExpiry = expirationTime.difference(now);

        // 如果 30 分鐘內過期，認為即將過期
        return timeUntilExpiry.inMinutes <= 30;
      } catch (e) {
        debugPrint('❌ 檢查 JWT 過期時間失敗: $e');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 檢查 JWT Token 狀態失敗: $e');
      return false;
    }
  }

  /// 獲取 JWT Token 的過期時間
  static Future<DateTime?> getJWTTokenExpiration() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || !token.startsWith('eyJ')) {
        return null; // 不是 JWT 或沒有 token
      }

      final parts = token.split('.');
      if (parts.length != 3) {
        return null; // 不是有效的 JWT
      }

      try {
        final payload = parts[1];
        final decodedPayload = _base64UrlDecode(payload);
        final payloadData = jsonDecode(decodedPayload);

        final exp = payloadData['exp'];
        if (exp == null) {
          return null; // 沒有過期時間
        }

        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      } catch (e) {
        debugPrint('❌ 獲取 JWT 過期時間失敗: $e');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 獲取 JWT Token 過期時間失敗: $e');
      return null;
    }
  }
}

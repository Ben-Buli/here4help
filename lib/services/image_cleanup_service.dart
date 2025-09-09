import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:flutter/foundation.dart';

/// 圖片清理服務
class ImageCleanupService {
  /// 清理失敗的圖片上傳檔案
  static Future<bool> cleanupFailedUpload(String filePath) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        debugPrint('❌ 無法取得認證 token');
        return false;
      }

      final response = await http.post(
        Uri.parse(AppConfig.api('/chat/cleanup_failed_upload.php')),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'file_path': filePath,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ 成功清理失敗的圖片檔案: $filePath');
          return true;
        } else {
          debugPrint('❌ 清理圖片檔案失敗: ${data['message']}');
          return false;
        }
      } else {
        debugPrint('❌ 清理圖片檔案 HTTP 錯誤: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 清理圖片檔案異常: $e');
      return false;
    }
  }

  /// 批量清理多個失敗的圖片檔案
  static Future<int> cleanupMultipleFailedUploads(
      List<String> filePaths) async {
    int successCount = 0;

    for (final filePath in filePaths) {
      if (await cleanupFailedUpload(filePath)) {
        successCount++;
      }
      // 添加小延遲避免過於頻繁的請求
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('✅ 批量清理完成: $successCount/${filePaths.length} 個檔案');
    return successCount;
  }

  /// 從上傳結果中提取檔案路徑
  static String? extractFilePathFromUploadResult(
      Map<String, dynamic> uploadResult) {
    try {
      return uploadResult['data']?['path'] ?? uploadResult['data']?['url'];
    } catch (e) {
      debugPrint('❌ 無法從上傳結果中提取檔案路徑: $e');
      return null;
    }
  }
}

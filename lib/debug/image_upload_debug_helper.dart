import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 圖片上傳調試助手
/// 在聊天頁面添加一個浮動按鈕，快速訪問圖片上傳測試工具
class ImageUploadDebugHelper {
  /// 創建調試浮動按鈕
  static Widget createDebugButton(BuildContext context) {
    return Positioned(
      top: 100,
      right: 16,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        onPressed: () => _showDebugMenu(context),
        child: const Icon(Icons.bug_report),
      ),
    );
  }

  /// 顯示調試菜單
  static void _showDebugMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🔧 圖片上傳調試工具',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('圖片上傳測試'),
                subtitle: const Text('測試圖片選擇、壓縮、縮圖生成等功能'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/debug/image-upload');
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.green),
                title: const Text('當前環境信息'),
                subtitle: const Text('查看平台、壓縮支援等信息'),
                onTap: () {
                  Navigator.pop(context);
                  _showEnvironmentInfo(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.help, color: Colors.purple),
                title: const Text('常見問題解決'),
                subtitle: const Text('查看圖片上傳常見問題和解決方案'),
                onTap: () {
                  Navigator.pop(context);
                  _showTroubleshootingGuide(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 顯示環境信息
  static void _showEnvironmentInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('環境信息'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('平台', _getPlatformInfo()),
                _buildInfoRow('Debug 模式', _getDebugMode()),
                _buildInfoRow('圖片壓縮支援', _getCompressionSupport()),
                _buildInfoRow('Web 兼容模式', _getWebCompatibility()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  /// 顯示故障排除指南
  static void _showTroubleshootingGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('常見問題解決'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTroubleshootingItem(
                  '❌ "_Namespace" 錯誤',
                  '這是 Web 環境下的文件系統訪問限制\n解決方案：使用 Web 兼容的圖片處理方法',
                ),
                const SizedBox(height: 12),
                _buildTroubleshootingItem(
                  '❌ "Platform._operatingSystem" 錯誤',
                  '這是 Web 環境下的平台檢測限制\n解決方案：使用簡化的壓縮參數',
                ),
                const SizedBox(height: 12),
                _buildTroubleshootingItem(
                  '❌ 圖片尺寸太小',
                  '圖片必須至少 320x320 像素\n解決方案：選擇更大尺寸的圖片',
                ),
                const SizedBox(height: 12),
                _buildTroubleshootingItem(
                  '❌ 檔案過大',
                  '圖片檔案不能超過 10MB\n解決方案：選擇較小的圖片或進行預壓縮',
                ),
                const SizedBox(height: 12),
                _buildTroubleshootingItem(
                  '❌ 不支援的格式',
                  '只支援 JPG、PNG、WebP 格式\n解決方案：轉換圖片格式',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  static Widget _buildTroubleshootingItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  static String _getPlatformInfo() {
    try {
      // 使用 kIsWeb 來判斷平台
      return const bool.fromEnvironment('dart.library.js_util')
          ? 'Web'
          : 'Native';
    } catch (e) {
      return '未知';
    }
  }

  static String _getDebugMode() {
    return const bool.fromEnvironment('dart.vm.product') ? '否' : '是';
  }

  static String _getCompressionSupport() {
    return 'flutter_image_compress 支援';
  }

  static String _getWebCompatibility() {
    return const bool.fromEnvironment('dart.library.js_util') ? '啟用' : '不適用';
  }
}

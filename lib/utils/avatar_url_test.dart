import 'package:flutter/foundation.dart';
import 'avatar_url_manager.dart';

/// 頭像 URL 管理器測試
/// 用於驗證不同格式的頭像路徑處理
class AvatarUrlTest {
  /// 執行所有測試
  static void runAllTests() {
    if (!kDebugMode) return;

    // debugPrint('🧪 開始頭像 URL 管理器測試...');

    testLocalAssets();
    testBackendUploads();
    testHttpUrls();
    testInvalidPaths();
    testDatabaseFormatting();
    testMigration();

    // debugPrint('✅ 頭像 URL 管理器測試完成！');
  }

  /// 測試本地資源路徑
  static void testLocalAssets() {
    debugPrint('\n📁 測試本地資源路徑:');

    final testCases = [
      'backend/uploads/avatars/avatar-1.png',
      'backend/uploads/avatars/avatar-4.png',
      'backend/uploads/avatars/avatar-1.png',
    ];

    for (final testCase in testCases) {
      final pathType = AvatarUrlManager.getPathType(testCase);
      final resolvedUrl = AvatarUrlManager.resolveAvatarUrl(testCase);
      final isLocal = AvatarUrlManager.isLocalAsset(testCase);

      // debugPrint('  輸入: $testCase');
      // debugPrint('  類型: ${pathType.name}');
      // debugPrint('  解析: $resolvedUrl');
      // debugPrint('  本地: $isLocal');
      // debugPrint('  ---');
    }
  }

  /// 測試後端上傳路徑
  static void testBackendUploads() {
    debugPrint('\n🔄 測試後端上傳路徑:');

    final testCases = [
      '/backend/uploads/avatars/compressed_avatar_2_1755973715.png',
      'backend/uploads/avatars/avatar_123_1234567890.jpg',
      '/backend/uploads/avatars/compressed_avatar_5_1755973800.webp',
    ];

    for (final testCase in testCases) {
      final pathType = AvatarUrlManager.getPathType(testCase);
      final resolvedUrl = AvatarUrlManager.resolveAvatarUrl(testCase);
      final isNetwork = AvatarUrlManager.isNetworkImage(testCase);
      final dbFormat = AvatarUrlManager.formatForDatabase(resolvedUrl);

      // debugPrint('  輸入: $testCase');
      // debugPrint('  類型: ${pathType.name}');
      // debugPrint('  解析: $resolvedUrl');
      // debugPrint('  網路: $isNetwork');
      // debugPrint('  資料庫格式: $dbFormat');
      // debugPrint('  ---');
    }
  }

  /// 測試 HTTP URL
  static void testHttpUrls() {
    // debugPrint('\n🌐 測試 HTTP URL:');

    final testCases = [
      'https://example.com/avatar.jpg',
      'http://localhost:8888/here4help/backend/uploads/avatars/avatar.png',
      'https://cdn.example.com/user/123/avatar.webp',
    ];

    for (final testCase in testCases) {
      final pathType = AvatarUrlManager.getPathType(testCase);
      final resolvedUrl = AvatarUrlManager.resolveAvatarUrl(testCase);
      final isNetwork = AvatarUrlManager.isNetworkImage(testCase);

      // debugPrint('  輸入: $testCase');
      // debugPrint('  類型: ${pathType.name}');
      // debugPrint('  解析: $resolvedUrl');
      // debugPrint('  網路: $isNetwork');
      // debugPrint('  ---');
    }
  }

  /// 測試無效路徑
  static void testInvalidPaths() {
    // debugPrint('\n❌ 測試無效路徑:');

    final testCases = [
      null,
      '',
      'invalid/path/avatar.jpg',
      'random_string',
      '/some/unknown/path.png',
    ];

    for (final testCase in testCases) {
      final pathType = AvatarUrlManager.getPathType(testCase);
      final resolvedUrl = AvatarUrlManager.resolveAvatarUrl(testCase);

      // debugPrint('  輸入: ${testCase ?? "null"}');
      // debugPrint('  類型: ${pathType.name}');
      // debugPrint('  解析: $resolvedUrl');
      // debugPrint('  ---');
    }
  }

  /// 測試資料庫格式化
  static void testDatabaseFormatting() {
    debugPrint('\n💾 測試資料庫格式化:');

    final testCases = [
      'http://localhost:8888/here4help/backend/uploads/avatars/avatar.jpg',
      'backend/uploads/avatars/avatar-1.png',
      '/backend/uploads/avatars/compressed_avatar_2_1755973715.png',
      'backend/uploads/avatars/avatar_123.png',
    ];

    for (final testCase in testCases) {
      final dbFormat = AvatarUrlManager.formatForDatabase(testCase);

      // debugPrint('  輸入: $testCase');
      // debugPrint('  資料庫格式: $dbFormat');
      // debugPrint('  ---');
    }
  }

  /// 測試舊路徑遷移
  static void testMigration() {
    // debugPrint('\n🔄 測試舊路徑遷移:');

    final testCases = [
      'test_images/avatar/avatar-1.png',
      'uploads/avatars/old_avatar.jpg',
      '/uploads/avatars/old_avatar.jpg',
      'backend/uploads/avatars/avatar-2.png', // 已經是新格式
    ];

    for (final testCase in testCases) {
      final migratedPath = AvatarUrlManager.migrateOldAvatarPath(testCase);

      // debugPrint('  舊路徑: $testCase');
      // debugPrint('  遷移後: $migratedPath');
      // debugPrint('  ---');
    }
  }

  /// 測試隨機預設頭像
  static void testRandomDefaultAvatars() {
    // debugPrint('\n🎲 測試隨機預設頭像:');

    for (int i = 0; i < 5; i++) {
      final randomAvatar = AvatarUrlManager.getRandomDefaultAvatar();
      // debugPrint('  隨機頭像 ${i + 1}: $randomAvatar');
    }
  }
}

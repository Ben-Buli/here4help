import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:here4help/config/environment_config_legacy.dart';

/// 頭像快取管理器
/// 提供記憶體快取和磁碟快取功能，避免重複載入相同的頭像圖片
class AvatarCacheManager {
  static final AvatarCacheManager _instance = AvatarCacheManager._internal();
  factory AvatarCacheManager() => _instance;
  AvatarCacheManager._internal();

  // 記憶體快取：存儲已載入的圖片數據
  static final Map<String, Uint8List> _memoryCache = {};

  // 載入中的 URL 集合，避免重複請求
  static final Set<String> _loadingUrls = {};

  // 失敗的 URL 集合（從現有的 AvatarErrorCache 遷移過來）
  static final Set<String> _failedUrls = {};

  // 快取配置
  static const int _maxMemoryCacheSize = 50; // 最多快取 50 張圖片
  static const int _maxCacheAge = 3600000; // 1小時過期時間（毫秒）

  // 快取時間戳記錄
  static final Map<String, int> _cacheTimestamps = {};

  /// 獲取頭像圖片數據
  /// 優先從快取讀取，如果沒有則從網路載入並快取
  static Future<Uint8List?> getAvatarData(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    // 正規化路徑
    final resolvedPath = _resolveAvatarPath(avatarPath);

    // 檢查是否為失敗的 URL
    if (_failedUrls.contains(resolvedPath)) {
      debugPrint('🚫 [AvatarCache] URL 在失敗清單中，跳過載入: $resolvedPath');
      return null;
    }

    // 檢查記憶體快取
    if (_memoryCache.containsKey(resolvedPath)) {
      final timestamp = _cacheTimestamps[resolvedPath] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 檢查快取是否過期
      if (now - timestamp < _maxCacheAge) {
        debugPrint('✅ [AvatarCache] 從記憶體快取讀取: $resolvedPath');
        return _memoryCache[resolvedPath];
      } else {
        // 快取過期，移除
        debugPrint('⏰ [AvatarCache] 快取過期，移除: $resolvedPath');
        _memoryCache.remove(resolvedPath);
        _cacheTimestamps.remove(resolvedPath);
      }
    }

    // 檢查是否正在載入中
    if (_loadingUrls.contains(resolvedPath)) {
      debugPrint('⏳ [AvatarCache] 圖片載入中，等待: $resolvedPath');
      // 等待載入完成
      while (_loadingUrls.contains(resolvedPath)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // 載入完成後再次檢查快取
      return _memoryCache[resolvedPath];
    }

    // 開始載入
    _loadingUrls.add(resolvedPath);

    try {
      Uint8List? imageData;

      if (resolvedPath.startsWith('assets/')) {
        // 載入 Asset 圖片
        imageData = await _loadAssetImage(resolvedPath);
      } else if (resolvedPath.startsWith('http://') ||
          resolvedPath.startsWith('https://')) {
        // 載入網路圖片
        imageData = await _loadNetworkImage(resolvedPath);
      }

      if (imageData != null) {
        // 快取成功載入的圖片
        _cacheImage(resolvedPath, imageData);
        debugPrint('✅ [AvatarCache] 圖片載入並快取成功: $resolvedPath');
        return imageData;
      } else {
        // 載入失敗，加入失敗清單
        _failedUrls.add(resolvedPath);
        debugPrint('❌ [AvatarCache] 圖片載入失敗: $resolvedPath');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [AvatarCache] 載入圖片時發生錯誤: $resolvedPath, 錯誤: $e');
      _failedUrls.add(resolvedPath);
      return null;
    } finally {
      _loadingUrls.remove(resolvedPath);
    }
  }

  /// 正規化頭像路徑
  static String _resolveAvatarPath(String avatarPath) {
    if (avatarPath.startsWith('http://') ||
        avatarPath.startsWith('https://') ||
        avatarPath.startsWith('assets/')) {
      return avatarPath;
    }
    // 相對路徑轉為完整 URL
    return EnvironmentConfig.getFullImageUrl(avatarPath);
  }

  /// 載入 Asset 圖片
  static Future<Uint8List?> _loadAssetImage(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      debugPrint('❌ [AvatarCache] Asset 載入失敗: $assetPath, 錯誤: $e');
      return null;
    }
  }

  /// 載入網路圖片
  static Future<Uint8List?> _loadNetworkImage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Here4Help-App/1.0',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        debugPrint(
            '❌ [AvatarCache] HTTP 錯誤: $url, 狀態碼: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [AvatarCache] 網路載入失敗: $url, 錯誤: $e');
      return null;
    }
  }

  /// 快取圖片數據
  static void _cacheImage(String path, Uint8List imageData) {
    // 檢查快取大小，如果超過限制則清理舊的快取
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _cleanOldCache();
    }

    _memoryCache[path] = imageData;
    _cacheTimestamps[path] = DateTime.now().millisecondsSinceEpoch;

    debugPrint('💾 [AvatarCache] 圖片已快取: $path (快取大小: ${_memoryCache.length})');
  }

  /// 清理舊的快取
  static void _cleanOldCache() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final toRemove = <String>[];

    // 找出過期的快取
    for (final entry in _cacheTimestamps.entries) {
      if (now - entry.value > _maxCacheAge) {
        toRemove.add(entry.key);
      }
    }

    // 如果沒有過期的，移除最舊的一半
    if (toRemove.isEmpty) {
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      const removeCount = _maxMemoryCacheSize ~/ 2;
      for (int i = 0; i < removeCount && i < sortedEntries.length; i++) {
        toRemove.add(sortedEntries[i].key);
      }
    }

    // 移除快取
    for (final path in toRemove) {
      _memoryCache.remove(path);
      _cacheTimestamps.remove(path);
    }

    debugPrint('🧹 [AvatarCache] 清理了 ${toRemove.length} 個舊快取');
  }

  /// 預載入頭像（批量載入）
  static Future<void> preloadAvatars(List<String> avatarPaths) async {
    final futures = avatarPaths
        .where((path) => path.isNotEmpty)
        .map((path) => getAvatarData(path));

    await Future.wait(futures);
    debugPrint('🚀 [AvatarCache] 預載入完成: ${avatarPaths.length} 個頭像');
  }

  /// 清空所有快取
  static void clearAllCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _failedUrls.clear();
    _loadingUrls.clear();
    debugPrint('🧹 [AvatarCache] 已清空所有快取');
  }

  /// 移除特定 URL 的快取
  static void removeCacheForUrl(String url) {
    final resolvedPath = _resolveAvatarPath(url);
    _memoryCache.remove(resolvedPath);
    _cacheTimestamps.remove(resolvedPath);
    _failedUrls.remove(resolvedPath);
    debugPrint('🗑️ [AvatarCache] 已移除快取: $resolvedPath');
  }

  /// 獲取快取統計信息
  static Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'failed_urls_count': _failedUrls.length,
      'loading_urls_count': _loadingUrls.length,
      'max_cache_size': _maxMemoryCacheSize,
      'cache_age_ms': _maxCacheAge,
    };
  }

  /// 檢查 URL 是否在快取中
  static bool isCached(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return false;
    final resolvedPath = _resolveAvatarPath(avatarPath);
    return _memoryCache.containsKey(resolvedPath);
  }

  /// 檢查 URL 是否載入失敗
  static bool isFailedUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) return false;
    final resolvedPath = _resolveAvatarPath(avatarPath);
    return _failedUrls.contains(resolvedPath);
  }
}

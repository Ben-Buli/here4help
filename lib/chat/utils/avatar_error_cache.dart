/// 頭像錯誤快取管理器
class AvatarErrorCache {
  static final Set<String> _failedUrls = <String>{};
  static const int _maxCacheSize = 100;

  /// 檢查 URL 是否已知載入失敗
  static bool isFailedUrl(String url) => _failedUrls.contains(url);

  /// 添加失敗的 URL 到快取
  static void addFailedUrl(String url) {
    if (_failedUrls.length >= _maxCacheSize) {
      // 移除最舊的一半條目，防止快取無限增長
      final toRemove = _failedUrls.take(_maxCacheSize ~/ 2).toList();
      _failedUrls.removeAll(toRemove);
    }
    _failedUrls.add(url);
  }

  /// 清空快取（調試用）
  static void clearCache() => _failedUrls.clear();

  /// 獲取快取大小（調試用）
  static int get cacheSize => _failedUrls.length;
}

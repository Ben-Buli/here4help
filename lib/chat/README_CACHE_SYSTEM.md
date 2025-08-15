# Chat 頁面快取系統

## 🎯 概述

這個快取系統為 `/chat` 頁面提供了低頻更新的數據管理，實現了「秒開」的用戶體驗。

## 🚀 核心功能

### 1. 快取策略
- **App 啟動** → 顯示快取（秒開）
- **進入頁面** → 輕量檢查有無變更
- **有變更** → 局部更新 + 動畫提示
- **有人應徵** → 後端推事件或推播觸發更新

### 2. 快取有效期
- **24小時**：快取數據在24小時內被認為是有效的
- **自動過期**：超過24小時後自動標記為過期，需要重新載入

## 🏗️ 架構組件

### ChatCacheManager
核心快取管理類，負責：
- 數據的載入、儲存和更新
- 快取狀態管理
- 增量更新檢查

### UpdateStatusIndicator
更新狀態指示器，提供：
- 實時更新狀態顯示
- 動畫提示效果
- 用戶友好的狀態反饋

### ChatProviders
Provider 配置，確保：
- 快取管理器在整個聊天頁面可用
- 狀態的響應式更新

## 📱 使用流程

### 初始化階段
```dart
// 1. App 啟動時自動載入快取
await _cacheManager.initializeCache();

// 2. 如果快取有效，直接使用
if (_cacheManager.isCacheValid && !_cacheManager.isCacheEmpty) {
  await _loadDataFromCache();
  // 顯示快取數據（秒開）
} else {
  // 執行完整載入
  await _loadChatData();
}
```

### 進入頁面後
```dart
// 輕量檢查更新
void _checkForUpdatesAfterEnter() {
  Future.delayed(const Duration(seconds: 1), () {
    if (mounted) {
      _cacheManager.checkForUpdates();
    }
  });
}
```

### 用戶手動刷新
```dart
// Pull-to-refresh 時調用
onRefresh: () async {
  await _cacheManager.forceRefresh();
  await _loadDataFromCache();
  _pagingController.refresh();
}
```

## 🔄 更新機制

### 增量更新檢查
```dart
Future<bool> _checkForDataUpdates() async {
  // 檢查快取是否過期
  if (!isCacheValid) {
    return true;
  }
  
  // 可以添加其他檢查邏輯
  // 例如：檢查 updated_after 時間戳
  // 例如：檢查應徵者數量變化
  
  return false;
}
```

### 局部更新
```dart
Future<void> _performIncrementalUpdate() async {
  try {
    // 只更新變更的部分
    await _loadPostedTasksData();
    await _loadMyWorksData();
  } catch (e) {
    // 如果增量更新失敗，回退到完整更新
    await _loadFullData();
  }
}
```

## 💾 數據儲存

### SharedPreferences 鍵值
- `chat_posted_tasks_cache`：Posted Tasks 快取
- `chat_my_works_cache`：My Works 快取
- `chat_last_update`：最後更新時間
- `chat_cache_version`：快取版本

### 快取數據結構
```dart
// Posted Tasks 快取
{
  'id': 'task_id',
  'title': '任務標題',
  'applications': [
    {
      'application_id': 'app_id',
      'applier_name': '應徵者姓名',
      // ... 其他應徵者資料
    }
  ]
}

// My Works 快取
{
  'id': 'task_id',
  'title': '任務標題',
  'application_status': '應徵狀態',
  // ... 其他任務資料
}
```

## 🎨 UI 組件

### UpdateStatusBanner
全寬狀態橫幅，顯示：
- 更新中狀態
- 更新完成提示
- 已是最新提示

### UpdateStatusIndicator
圓角狀態指示器，提供：
- 滑動動畫效果
- 彈性動畫曲線
- 狀態圖標和文字

## 🔧 配置選項

### 快取有效期
```dart
// 在 ChatCacheManager 中修改
bool get isCacheValid {
  if (_lastUpdate == null) return false;
  final now = DateTime.now();
  final difference = now.difference(_lastUpdate!);
  return difference.inHours < 24; // 可調整小時數
}
```

### 更新檢查延遲
```dart
// 在 ChatListPage 中調整
void _checkForUpdatesAfterEnter() {
  Future.delayed(const Duration(seconds: 1), () { // 可調整秒數
    if (mounted) {
      _cacheManager.checkForUpdates();
    }
  });
}
```

## 🚨 錯誤處理

### 快取載入失敗
- 自動回退到完整載入
- 記錄錯誤日誌
- 用戶友好的錯誤提示

### 增量更新失敗
- 自動回退到完整更新
- 保持應用穩定性
- 不影響用戶體驗

## 📊 性能優化

### 記憶體管理
- 及時清理無用快取
- 避免記憶體洩漏
- 優化數據結構

### 網路請求優化
- 減少不必要的 API 調用
- 智能的更新檢查
- 批量數據處理

## 🔮 未來擴展

### 推播通知
- 後端推事件觸發更新
- 實時數據同步
- 用戶主動通知

### 智能快取
- 基於用戶行為的快取策略
- 預測性數據載入
- 自適應快取大小

### 離線支援
- 完全離線模式
- 數據同步機制
- 衝突解決策略

## 📝 使用注意事項

1. **快取一致性**：確保快取數據與後端數據的一致性
2. **記憶體管理**：定期清理過期快取，避免記憶體佔用過大
3. **錯誤處理**：妥善處理快取載入和更新失敗的情況
4. **用戶體驗**：提供清晰的更新狀態提示，讓用戶了解當前狀態
5. **性能監控**：監控快取系統的性能指標，及時優化

## 🎉 總結

這個快取系統通過智能的數據管理和用戶友好的狀態提示，實現了：
- **秒開體驗**：App 啟動時立即顯示快取數據
- **智能更新**：輕量檢查更新，避免不必要的網路請求
- **流暢動畫**：優雅的狀態提示和更新動畫
- **穩定可靠**：完善的錯誤處理和回退機制

為用戶提供了快速、流暢、可靠的聊天頁面體驗！

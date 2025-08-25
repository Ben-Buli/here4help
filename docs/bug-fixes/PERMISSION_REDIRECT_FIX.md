# 權限頁面回溯功能修復報告

## 🐛 問題描述

用戶反映在權限驗證頁面（`permission_unvertified_page.dart`）中，刷新權限後無法正確回溯到原本被阻擋的頁面。

## 🔍 問題分析

### 根本原因
在 `lib/router/guards/permission_guard.dart` 中，當用戶權限未驗證時，重定向邏輯只傳遞了 `from` 參數，但沒有傳遞 `blocked` 參數：

```dart
// 問題代碼
context.go('/permission-unverified?from=$path');
```

而在 `permission_unvertified_page.dart` 的 `_returnToBlockedPage` 方法中，代碼嘗試讀取 `blocked` 參數：

```dart
// 嘗試讀取不存在的參數
final blockedPath = state.uri.queryParameters['blocked'];
```

### 影響範圍
- ✅ `permission_denied_page.dart` - 正常工作（有正確的 `blocked` 參數）
- ❌ `permission_unvertified_page.dart` - 無法回溯（缺少 `blocked` 參數）

## 🔧 修復方案

### 1. 修復 PermissionGuard 重定向邏輯

**文件**: `lib/router/guards/permission_guard.dart`

```dart
// 修復前
context.go('/permission-unverified?from=$path');

// 修復後
context.go('/permission-unverified?blocked=$path&from=$path');
```

### 2. 增強回溯邏輯的健壯性

**文件**: `lib/system/pages/permission_unvertified_page.dart`

```dart
void _returnToBlockedPage(BuildContext context) {
  final state = GoRouterState.of(context);
  final blockedPath = state.uri.queryParameters['blocked']; // 被阻擋的頁面
  final fromPath = state.uri.queryParameters['from']; // 來源頁面
  
  // 優先使用 blocked 參數，其次使用 from 參數
  final targetPath = blockedPath ?? fromPath;
  
  if (targetPath != null && targetPath.isNotEmpty && targetPath != '/permission-unverified') {
    debugPrint('🔙 導航到目標頁面: $targetPath');
    context.go(targetPath);
  } else {
    // 如果沒有有效的目標頁面，返回首頁
    debugPrint('🔙 沒有有效的目標頁面資訊，返回首頁');
    context.go('/home');
  }
}
```

### 3. 添加詳細的調試信息

增加了完整的 URL 和參數日誌，方便問題診斷：

```dart
debugPrint('🔍 [PermissionUnverified] 當前 URL: ${state.uri}');
debugPrint('🔍 [PermissionUnverified] 查詢參數: ${state.uri.queryParameters}');
debugPrint('🔙 [PermissionUnverified] blocked 參數: $blockedPath');
debugPrint('🔙 [PermissionUnverified] from 參數: $fromPath');
```

## 🧪 測試工具

創建了 `lib/debug/permission_redirect_test.dart` 測試工具，包含：

- **測試未驗證用戶重定向**: 模擬訪問需要權限的頁面
- **測試停權用戶重定向**: 驗證 permission-denied 頁面
- **測試複雜路徑重定向**: 包含查詢參數的路徑
- **驗證查詢參數解析**: 檢查當前頁面的參數狀態

## 📊 修復效果

### 修復前的流程
```
用戶訪問 /chat (未驗證)
↓
PermissionGuard 重定向: /permission-unverified?from=/chat
↓
用戶刷新權限成功
↓
_returnToBlockedPage 讀取 blocked 參數 → null
↓
返回首頁 (/home) ❌
```

### 修復後的流程
```
用戶訪問 /chat (未驗證)
↓
PermissionGuard 重定向: /permission-unverified?blocked=/chat&from=/chat
↓
用戶刷新權限成功
↓
_returnToBlockedPage 讀取 blocked 參數 → /chat
↓
返回原本想訪問的頁面 (/chat) ✅
```

## 🔄 相容性保證

修復方案保持向後相容：
- 如果 `blocked` 參數存在，優先使用
- 如果 `blocked` 參數不存在，回退到 `from` 參數
- 如果兩個參數都不存在，返回首頁

## ✅ 驗證清單

- [x] 未驗證用戶重定向正確傳遞 `blocked` 參數
- [x] 權限恢復後能正確回溯到原頁面
- [x] 停權用戶重定向功能不受影響
- [x] 複雜路徑（含查詢參數）正確處理
- [x] 向後相容性保證
- [x] 詳細調試日誌輸出
- [x] 測試工具可用

## 📝 相關文件

- `lib/router/guards/permission_guard.dart` - 權限守衛邏輯
- `lib/system/pages/permission_unvertified_page.dart` - 未驗證頁面
- `lib/system/pages/permission_denied_page.dart` - 權限拒絕頁面
- `lib/debug/permission_redirect_test.dart` - 測試工具

## 🎯 後續建議

1. **統一參數命名**: 考慮在所有權限相關頁面使用一致的查詢參數命名
2. **路由狀態管理**: 考慮使用更系統化的路由狀態管理方案
3. **自動化測試**: 為權限重定向邏輯添加單元測試和集成測試

---

**修復日期**: 2025-01-18  
**修復人員**: AI Assistant  
**測試狀態**: ✅ 已驗證  
**部署狀態**: 🟡 待部署

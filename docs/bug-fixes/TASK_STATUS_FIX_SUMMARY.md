# 任務狀態顯示不一致問題修復總結

## 問題描述
在 `chat_list_page.dart` 和 `chat_detail_page.dart` 中存在任務狀態映射不一致的問題，導致相同的任務狀態在不同頁面顯示不同的文字。同時，在 `task_create_page.dart` 中存在未定義的 `languageMap` 錯誤，導致 Xcode 啟動失敗。

## 問題原因
1. 兩個文件都定義了自己的 `statusString` 映射
2. 映射內容雖然相同，但定義方式不一致（一個是 `const`，一個是 `final`）
3. 缺乏統一的狀態管理機制
4. `task_create_page.dart` 中使用了未定義的 `languageMap` 變量

## 解決方案

### 1. 創建統一的狀態常量文件
創建了 `lib/constants/task_status.dart` 文件，包含：
- 統一的狀態名稱映射
- 狀態進度對應表
- 狀態排序權重
- 實用的工具方法

### 2. 更新 chat_list_page.dart
- 移除了本地的 `statusString` 定義
- 導入 `TaskStatus` 常量
- 將所有 `statusString` 引用替換為 `TaskStatus.statusString`
- 使用 `TaskStatus.getDisplayStatus()` 方法獲取顯示狀態

### 3. 更新 chat_detail_page.dart
- 移除了本地的 `statusString` 定義
- 導入 `TaskStatus` 常量
- 將所有 `statusString` 引用替換為 `TaskStatus.statusString`
- 簡化 `_getProgressData` 方法，使用 `TaskStatus.getProgressData()`

### 4. 修復 task_create_page.dart 中的 languageMap 錯誤
- 將 `languageMap[code]` 替換為從 `_languages` 列表中查找對應的語言名稱
- 修復了語言選擇器中的 `entry.key` 和 `entry.value` 錯誤，改為使用 `lang['code']` 和 `lang['native']`
- 確保語言選擇功能正常工作

## 修復結果

### 統一的狀態映射
```dart
static const Map<String, String> statusString = {
  'open': 'Open',
  'in_progress': 'In Progress',
  'in_progress_tasker': 'In Progress (Tasker)',
  'applying_tasker': 'Applying (Tasker)',
  'rejected_tasker': 'Rejected (Tasker)',
  'pending_confirmation': 'Pending Confirmation',
  'pending_confirmation_tasker': 'Pending Confirmation (Tasker)',
  'dispute': 'Dispute',
  'completed': 'Completed',
  'completed_tasker': 'Completed (Tasker)',
};
```

### 實用的工具方法
- `TaskStatus.getDisplayStatus(status)` - 獲取顯示狀態
- `TaskStatus.getProgressData(status)` - 獲取進度數據
- `TaskStatus.getStatusOrder(status)` - 獲取狀態排序權重

### 語言選擇器修復
```dart
// 修復前
label: Text(languageMap[code] ?? code),

// 修復後
final language = _languages.firstWhere(
  (lang) => lang['code'] == code,
  orElse: () => {'native': code},
);
return Chip(
  label: Text(language['native'] ?? code),
);
```

## 驗證結果
- ✅ 所有相關文件都通過了 Dart 分析檢查
- ✅ 沒有與狀態顯示相關的錯誤
- ✅ 狀態映射現在完全一致
- ✅ iOS 構建成功，Xcode 可以正常啟動
- ✅ 語言選擇功能正常工作

## 後續建議
1. 在添加新的任務狀態時，只需要在 `TaskStatus` 類中更新
2. 其他需要使用任務狀態的文件應該導入 `TaskStatus` 常量
3. 考慮為狀態添加更多的工具方法，如狀態轉換驗證等
4. 定期檢查是否有未定義的變量引用

## 影響範圍
- ✅ `lib/chat/pages/chat_list_page.dart`
- ✅ `lib/chat/pages/chat_detail_page.dart`
- ✅ `lib/task/pages/task_create_page.dart`
- ✅ `lib/constants/task_status.dart` (新增)

修復完成時間：2024年12月19日 
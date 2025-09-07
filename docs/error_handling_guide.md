# 前端錯誤處理包裝指南

## 概述

為了提供更好的使用者體驗，我們實作了統一的錯誤處理系統，將技術性的 exception 錯誤訊息轉換為使用者友善的訊息。

## 核心組件

### 1. ErrorHandlerService

統一的錯誤處理服務，提供以下功能：

- **getUserFriendlyMessage()**: 將技術錯誤轉換為使用者友善訊息
- **getOperationErrorMessage()**: 根據操作類型提供特定錯誤訊息
- **logError()**: 在 debug 模式下記錄錯誤詳情
- **isAuthError()**: 檢查是否為認證相關錯誤
- **isNetworkError()**: 檢查是否為網路相關錯誤

### 2. ErrorDisplayWidget

統一的錯誤顯示 Widget，提供一致的錯誤 UI 體驗。

### 3. ErrorSnackBar

錯誤 SnackBar 輔助類，提供快速顯示錯誤訊息的方法。

## 使用方式

### 在 API 服務中

```dart
// 舊的方式 ❌
} catch (e) {
  throw Exception('網路錯誤: $e');
}

// 新的方式 ✅
} catch (e) {
  ErrorHandlerService.logError('ServiceName.methodName', e);
  throw Exception(ErrorHandlerService.getOperationErrorMessage('load_tasks', e));
}
```

### 在 UI 組件中

```dart
// 舊的方式 ❌
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed: $e')),
  );
}

// 新的方式 ✅
} catch (e) {
  ErrorHandlerService.logError('ComponentName.methodName', e);
  ErrorSnackBar.show(context, e, operation: 'accept_application');
}
```

### 錯誤頁面顯示

```dart
// 使用 ErrorDisplayWidget
ErrorDisplayWidget(
  error: error,
  context: 'Loading tasks',
  onRetry: () => _loadTasks(),
)
```

## 支援的操作類型

- `login` - 登入操作
- `register` - 註冊操作
- `load_tasks` - 載入任務
- `create_task` - 建立任務
- `update_task` - 更新任務
- `delete_task` - 刪除任務
- `accept_application` - 接受申請
- `submit_rating` - 提交評分
- `upload_file` - 檔案上傳
- `send_message` - 發送訊息
- `block_user` - 封鎖用戶

## 錯誤訊息對應

### 網路錯誤
- 原始：`SocketException: Network unreachable`
- 友善：`網路連線異常，請檢查您的網路設定`

### HTTP 錯誤
- 原始：`Exception: HTTP 404: Not Found`
- 友善：`請求的資源不存在，請稍後再試`

### 認證錯誤
- 原始：`Exception: HTTP 401: Unauthorized`
- 友善：`登入已過期，請重新登入`

### 業務邏輯錯誤
- 原始：`Exception: This user has already been assigned`
- 友善：`此用戶已經被指派為此任務的執行者`

## 最佳實踐

### 1. 記錄錯誤
始終在 catch 區塊中記錄錯誤：
```dart
} catch (e) {
  ErrorHandlerService.logError('Context', e);
  // 處理錯誤...
}
```

### 2. 使用操作特定的錯誤處理
```dart
ErrorSnackBar.show(context, e, operation: 'accept_application');
```

### 3. 提供重試機制
```dart
ErrorDisplayWidget(
  error: error,
  onRetry: () => _retryOperation(),
)
```

### 4. 區分錯誤類型
```dart
if (ErrorHandlerService.isAuthError(error)) {
  // 導向登入頁面
} else if (ErrorHandlerService.isNetworkError(error)) {
  // 顯示網路錯誤提示
}
```

## 已更新的檔案

### API 服務
- `lib/task/services/ratings_service.dart`
- `lib/services/api/review_api.dart`

### UI 組件
- `lib/chat/pages/chat_detail_page.dart`

### 新增檔案
- `lib/services/error_handler_service.dart`
- `lib/widgets/error_display_widget.dart`

## 效果對比

### 修正前
```
❌ Exception: SocketException: Failed host lookup: 'api.example.com'
❌ Exception: HTTP 404: {"error": "Task not found", "code": "TASK_NOT_FOUND"}
❌ Exception: This user has already been assigned as the tasker for this task
```

### 修正後
```
✅ 網路連線異常，請檢查您的網路設定
✅ 請求的資源不存在，請稍後再試
✅ 此用戶已經被指派為此任務的執行者
```

這樣的錯誤處理系統提供了：
- 🎯 **使用者友善**：清楚易懂的錯誤訊息
- 🔧 **開發者友善**：詳細的錯誤記錄（僅在 debug 模式）
- 🎨 **一致的 UI**：統一的錯誤顯示風格
- 🔄 **可重試**：提供重試機制
- 📱 **響應式**：適應不同的錯誤類型

# 遷移指南：從假資料到後端 API

## 已完成的工作

### ✅ 已移除的假資料檔案
- `lib/constants/demo_users.dart` - 已刪除
- `lib/task/services/global_task_list.dart` - 已刪除

### ✅ 已創建的新服務
- `lib/task/services/task_service.dart` - 任務服務，使用後端 API
- `lib/task/services/application_question_service.dart` - 應用問題服務，使用後端 API

### ✅ 已修改的檔案
- `lib/auth/services/user_service.dart` - 已修改為使用後端 API 登入
- `lib/task/pages/task_list_page.dart` - 已修改為使用 TaskService
- `lib/task/pages/task_preview_page.dart` - 已修改為使用 TaskService

## 已完成的工作

### ✅ 已移除的假資料檔案
- `lib/constants/demo_users.dart` - 已刪除
- `lib/task/services/global_task_list.dart` - 已刪除

### ✅ 已創建的新服務
- `lib/task/services/task_service.dart` - 任務服務，使用後端 API
- `lib/task/services/application_question_service.dart` - 應用問題服務，使用後端 API

### ✅ 已修改的檔案
- `lib/auth/services/user_service.dart` - 已修改為使用後端 API 登入
- `lib/task/pages/task_list_page.dart` - 已修改為使用 TaskService
- `lib/task/pages/task_preview_page.dart` - 已修改為使用 TaskService
- `lib/task/pages/task_apply_page.dart` - 已修改為使用 TaskService
- `lib/chat/pages/chat_detail_page.dart` - 已修改為使用 TaskService
- `lib/chat/pages/chat_list_page.dart` - 已修改為使用 TaskService
- `lib/chat/services/global_chat_room.dart` - 已修改為使用 TaskService
- `lib/task/models/task_model.dart` - 為 `ApplicationQuestionModel` 添加了 `copyWith` 方法

## 遷移完成狀態

### ✅ 所有主要修改已完成
- 所有 `GlobalTaskList` 引用已替換為 `TaskService`
- 所有 `demo_users` 引用已替換為後端 API
- 所有 import 語句已更新
- 所有編譯錯誤已修復

### 🔄 剩餘的優化項目（非必要）
- 移除未使用的 import 語句
- 修復一些警告訊息（如 `withOpacity` 已棄用）
- 優化一些代碼風格問題

### 🔄 需要更新的 import 語句

在所有使用 `GlobalTaskList` 的檔案中，將：
```dart
import 'package:here4help/task/services/global_task_list.dart';
```

改為：
```dart
import 'package:here4help/task/services/task_service.dart';
```

## 後端 API 需求

### 任務相關 API
- `GET /backend/api/tasks/list.php` - 獲取任務列表
- `POST /backend/api/tasks/create.php` - 創建新任務
- `PUT /backend/api/tasks/{id}/status.php` - 更新任務狀態

### 應用問題相關 API
- `GET /backend/api/tasks/questions.php` - 獲取應用問題列表
- `POST /backend/api/tasks/questions.php` - 創建新應用問題
- `PUT /backend/api/tasks/questions.php/{id}` - 更新應用問題回覆

## 測試步驟

1. 確保後端 API 正常運行
2. 測試用戶登入功能
3. 測試任務列表載入
4. 測試任務創建功能
5. 測試任務狀態更新
6. 測試聊天功能中的任務狀態更新

## 注意事項

- 所有假資料已被移除，應用程式現在完全依賴後端 API
- 確保後端 API 返回的資料格式與前端期望的格式一致
- 如果後端 API 尚未完全實現，可能需要先實現對應的 API 端點 
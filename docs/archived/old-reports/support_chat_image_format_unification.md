# 客服聊天室圖片訊息格式統一化

## 問題解決

### 圖片上傳失敗問題
如果遇到客服聊天室圖片上傳失敗，可能的原因和解決方案：

#### 1. 檔案路徑問題
**問題**：Laravel 管理員後台使用 `storage_path('app/public/uploads/support_chat')` 存儲檔案
**解決**：修改為使用與 PHP 後端相同的路徑 `base_path('../backend/uploads/support_chat')`

#### 2. 資料庫欄位不匹配
**問題**：`admin_activity_logs` 表欄位名稱不一致
- 錯誤使用：`table_name`, `record_id`, `old_data`, `new_data`
- 正確使用：`resource_type`, `resource_id`, `old_values`, `new_values`

**解決**：統一使用正確的欄位名稱

#### 3. 檔案大小獲取錯誤
**問題**：使用 `$file->getSize()` 在檔案移動後可能失敗
**解決**：使用 `filesize($filePath)` 獲取實際檔案大小

### 圖片路徑不匹配問題
如果遇到 `uploads/support_chat/att_xxx.jpeg` 格式的圖片無法載入，這是因為：

1. **檔案名前綴問題**：`att_` 前綴表示檔案是通過一般聊天室 API 上傳的
2. **實際存儲位置**：檔案實際存儲在 `backend/uploads/chat/` 目錄中
3. **路徑不匹配**：資料庫記錄的路徑與實際檔案位置不符

### 解決方案

#### 1. 自動路徑修正
系統已實現智能路徑修正：
- 後台客服聊天室：自動將 `uploads/support_chat/att_` 路徑修正為 `uploads/chat/att_`
- Flutter App：PathMapper 自動處理路徑修正

#### 2. 資料庫修復腳本
執行 `database_fixes/fix_support_chat_image_path_mismatch.sql` 來修復現有記錄：

```sql
-- 修復路徑不匹配的記錄
UPDATE support_chat_messages 
SET content = REPLACE(content, 'uploads/support_chat/att_', 'uploads/chat/att_')
WHERE kind = 'image' 
  AND content LIKE 'uploads/support_chat/att_%';
```

#### 3. 目錄結構
確保以下目錄存在：
```
backend/uploads/
├── chat/                    # 一般聊天室圖片
└── support_chat/           # 客服聊天室圖片
```

## 概述
統一了 `support_chat_messages` 資料表中圖片訊息的寫入格式，並整合了後台客服聊天室和 Flutter app 的圖片讀取邏輯。

## 主要更改

### 1. 統一圖片路徑格式
- **新格式**: `uploads/support_chat/{檔案名稱.格式}`
- **舊格式**: `backend/uploads/chat/{檔案名稱.格式}`

### 2. 後端 API 更改

#### 修改 `backend/api/chat/upload_attachment.php`
- 根據聊天室類型決定儲存位置
- 客服聊天室：`uploads/support_chat/`
- 一般聊天室：`uploads/chat/`

#### 新增 `backend/api/admin/support/upload-image.php`
- 管理員專用的客服聊天室圖片上傳 API
- 支援 JWT 管理員認證
- 權限檢查：只有負責該聊天室的管理員可以上傳

#### 更新 `admin/app/Http/Controllers/Admin/SupportController.php`
- 新增 `uploadImage` 方法
- 整合到 Laravel 管理員後台

### 3. 前端更改

#### 後台客服聊天室 (`admin/frontend/src/views/SupportChatDetailView.vue`)
- 更新 `getImageUrl` 方法支援新格式
- 更新 `uploadImage` 方法使用新的管理員 API
- 向後兼容舊格式

#### 後台客服聊天室列表 (`admin/frontend/src/views/SupportChatListView.vue`)
- 更新 `getAvatarUrl` 方法支援新格式
- 向後兼容舊格式

### 4. Flutter App 更改

#### 更新 `lib/utils/path_mapper.dart`
- 支援 `uploads/` 開頭的路徑
- 更新 `isBackendUpload` 方法
- 向後兼容舊格式

#### 更新圖片 URL 提取邏輯
- `lib/chat/pages/chat_detail_page.dart`
- `lib/account/pages/support_chat_detail_page.dart`
- 支援 `webp` 格式
- 支援多種相對路徑格式

### 5. 資料庫更新

#### 創建 `database_fixes/update_support_chat_image_paths.sql`
- 更新現有圖片訊息的路徑格式
- 從 `backend/uploads/chat/` 更新為 `uploads/support_chat/`
- 包含檢查和統計查詢

### 6. 路由配置

#### 更新 `admin/routes/api.php`
- 新增管理員圖片上傳路由：`POST /admin/support/upload-image`

## 向後兼容性

所有更改都保持向後兼容：
- 支援舊格式的圖片路徑讀取
- 支援多種路徑格式（`backend/uploads/`、`uploads/`、`/backend/uploads/`、`/uploads/`）
- 支援多種圖片格式（`png`、`jpg`、`jpeg`、`gif`、`webp`）

## 使用方式

### 後台管理員上傳圖片
```javascript
const formData = new FormData()
formData.append('image', file)
formData.append('room_id', roomId)

const response = await fetch('/api/admin/support/upload-image', {
  method: 'POST',
  body: formData,
  headers: {
    'Authorization': `Bearer ${localStorage.getItem('admin_token')}`
  }
})
```

### Flutter App 讀取圖片
```dart
// 自動處理多種路徑格式
final imageUrl = PathMapper.mapDatabasePathToUrl(imagePath)
```

## 檔案結構

```
backend/uploads/
├── chat/                    # 一般聊天室圖片
└── support_chat/           # 客服聊天室圖片
    ├── admin_support_xxx.png
    └── support_xxx.jpg
```

## 注意事項

1. 執行資料庫更新腳本前請先備份
2. 確保上傳目錄權限正確設置
3. 管理員上傳需要相應的聊天室權限
4. 圖片大小限制：5MB
5. 支援的圖片格式：PNG、JPG、JPEG、GIF、WEBP

# 客服聊天室圖片讀取問題分析報告

## 發現的問題

### 1. 路徑不匹配問題
**問題描述**：資料庫記錄的路徑與實際檔案位置不符

**具體案例**：
- 資料庫記錄：`uploads/support_chat/att_68c05b65ddbb3.webp`
- 實際檔案位置：`backend/uploads/chat/att_68c05b65ddbb3.webp`
- 原因：`att_` 前綴表示檔案是通過一般聊天室 API 上傳的

### 2. 檔案副檔名不匹配
**問題描述**：資料庫記錄的副檔名與實際檔案副檔名不符

**具體案例**：
- 資料庫記錄：`uploads/support_chat/wallpaper.jpeg`
- 實際檔案：`backend/uploads/support_chat/wallpaper.jpg`
- 原因：上傳時副檔名處理不一致

### 3. 檔案不存在
**問題描述**：資料庫中有記錄但檔案不存在

**具體案例**：
- 資料庫記錄：`test-image.jpg`
- 實際檔案：不存在
- 原因：可能是測試資料或檔案被刪除

## 資料庫記錄分析

```sql
-- 當前資料庫中的圖片記錄
SELECT id, room_id, content, kind, created_at 
FROM support_chat_messages 
WHERE kind = 'image' 
ORDER BY created_at DESC;

-- 結果：
-- id=26, content='test-image.jpg' (檔案不存在)
-- id=19, content='uploads/support_chat/flower.jpg' (檔案存在)
-- id=18, content='uploads/support_chat/cat.jpeg' (檔案存在)
-- id=17, content='uploads/support_chat/wallpaper.jpeg' (副檔名不匹配)
-- id=16, content='uploads/support_chat/cat.jpeg' (檔案存在)
-- id=15, content='uploads/support_chat/flower.jpg' (檔案存在)
-- id=12, content='uploads/support_chat/att_68c05b65ddbb3.webp' (路徑不匹配)
```

## 實際檔案狀況

```
backend/uploads/support_chat/
├── cat.jpeg ✅
├── flower.jpg ✅
└── wallpaper.jpg ✅ (但資料庫記錄是 wallpaper.jpeg)

backend/uploads/chat/
└── att_68c05b65ddbb3.webp ✅ (但資料庫記錄在 support_chat 路徑)
```

## 解決方案

### 1. 修復路徑不匹配
```sql
-- 將 att_ 前綴的檔案路徑從 support_chat 改為 chat
UPDATE support_chat_messages 
SET content = REPLACE(content, 'uploads/support_chat/att_', 'uploads/chat/att_')
WHERE kind = 'image' 
  AND content LIKE 'uploads/support_chat/att_%';
```

### 2. 修復副檔名不匹配
```sql
-- 將 wallpaper.jpeg 改為 wallpaper.jpg
UPDATE support_chat_messages 
SET content = 'uploads/support_chat/wallpaper.jpg'
WHERE kind = 'image' 
  AND content = 'uploads/support_chat/wallpaper.jpeg';
```

### 3. 清理不存在的檔案記錄
```sql
-- 刪除不存在的檔案記錄
DELETE FROM support_chat_messages 
WHERE kind = 'image' 
  AND content = 'test-image.jpg';
```

## 前端處理邏輯

### 智能路徑修正
```javascript
function getImageUrl(imagePath) {
  if (!imagePath) return '';
  
  // 處理 att_ 前綴檔案的路徑修正
  if (imagePath.startsWith('uploads/support_chat/')) {
    const fileName = imagePath.split('/').pop();
    if (fileName && fileName.startsWith('att_')) {
      return imagePath.replace('uploads/support_chat/', 'uploads/chat/');
    }
  }
  
  return imagePath;
}
```

### Flutter PathMapper 處理
```dart
static String mapDatabasePathToUrl(String? databasePath) {
  if (cleanPath.startsWith('uploads/support_chat/')) {
    final fileName = cleanPath.split('/').last;
    if (fileName.startsWith('att_')) {
      cleanPath = cleanPath.replaceFirst('uploads/support_chat/', 'uploads/chat/');
    }
  }
  return '$baseUrl/$cleanPath';
}
```

## 建議

1. **立即執行**：運行資料庫修復腳本
2. **長期解決**：統一圖片上傳 API 的路徑處理
3. **監控**：添加檔案存在性檢查
4. **測試**：使用測試頁面驗證修復效果

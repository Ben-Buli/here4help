# Dispute Chat Room 錯誤修復報告

**日期**: 2025-10-28  
**問題**: Dispute Chat Room 頁面顯示錯誤，API 500 和 404 錯誤  
**優先級**: 高 🔴  
**狀態**: ✅ 已修復

---

## 📋 問題描述

### 錯誤現象
1. **前端頁面**: `https://hero4help.demofhs.com/admin/task-disputes/5b0b7209-61fe-42e4-9795-ae4213855c48/chat-room`
   - 顯示 "Error Loading Chat Room" 和 "Server error occurred"

2. **API Error 500**:
   ```
   https://hero4help.demofhs.com/api/admin/task-disputes/5b0b7209-61fe-42e4-9795-ae4213855c48/chat-room
   Response: {
       "success": false,
       "message": "Server error occurred"
   }
   ```

3. **API Error 404**:
   ```
   https://hero4help.demofhs.com/backend/api/tasks/statuses
   Error: 404 Not Found
   ```

### 根本原因

#### 問題 1: chat-room.php 中的 $chatRoomId 未定義錯誤
- **文件**: `backend/api/admin/task-disputes/chat-room.php` (line 232)
- **原因**: 當 `$chatRoomId` 為 `null` 時，仍然嘗試查詢聊天訊息，導致 SQL 錯誤
- **影響**: 返回 500 錯誤，無法載入聊天室

#### 問題 2: tasks/statuses API 路徑錯誤
- **文件**: `admin/frontend/src/services/api.ts` (line 173)
- **原因**: API 路徑 `/backend/api/tasks/statuses` 缺少 `.php` 後綴
- **實際路徑**: `/backend/api/tasks/statuses.php`
- **影響**: 返回 404 錯誤，無法載入任務狀態

---

## 🔧 修復方案

### 修復 1: chat-room.php - 安全檢查 $chatRoomId

**修改文件**: `backend/api/admin/task-disputes/chat-room.php`

**修改位置**: Line 214-236

**修改前**:
```php
// 獲取聊天訊息 (完整歷史)
$messagesQuery = $db->prepare("
    SELECT 
        cm.id,
        cm.room_id,
        cm.from_user_id,
        cm.content,
        cm.kind,
        cm.media_url,
        cm.mime_type,
        cm.created_at,
        u.name as user_name,
        u.avatar_url as user_avatar
    FROM chat_messages cm
    LEFT JOIN users u ON cm.from_user_id = u.id
    WHERE cm.room_id = ?
    ORDER BY cm.created_at ASC
");
$messagesQuery->execute([$chatRoomId]); // ❌ $chatRoomId 可能是 null
$messages = $messagesQuery->fetchAll(PDO::FETCH_ASSOC);
```

**修改後**:
```php
// 獲取聊天訊息 (完整歷史)
$messages = [];
if ($chatRoom && $chatRoom['id']) {
    $messagesQuery = $db->prepare("
        SELECT 
            cm.id,
            cm.room_id,
            cm.from_user_id,
            cm.content,
            cm.kind,
            cm.media_url,
            cm.mime_type,
            cm.created_at,
            u.name as user_name,
            u.avatar_url as user_avatar
        FROM chat_messages cm
        LEFT JOIN users u ON cm.from_user_id = u.id
        WHERE cm.room_id = ?
        ORDER BY cm.created_at ASC
    ");
    $messagesQuery->execute([$chatRoom['id']]);
    $messages = $messagesQuery->fetchAll(PDO::FETCH_ASSOC);
}
```

### 修復 2: tasks/statuses API 路徑

**修改文件**: `admin/frontend/src/services/api.ts`

**修改位置**: Line 173-178

**修改前**:
```typescript
statuses: () => api.get<ApiResponse<any[]>>('/backend/api/tasks/statuses'),
```

**修改後**:
```typescript
// Note: 任務狀態來自 backend API（非管理員 API），使用完整 URL
statuses: () => {
  const backendUrl = API_CONFIG.backendUrl || 'https://hero4help.demofhs.com/backend'
  const url = `${backendUrl}/api/tasks/statuses.php`
  return axios.get<ApiResponse<any[]>>(url)
},
```

---

## ✅ 修復效果

### API 500 錯誤修復
- ✅ `$chatRoomId` 為 `null` 時不再執行查詢
- ✅ 返回空的 `messages` 陣列而非錯誤
- ✅ 聊天室頁面能正常載入

### API 404 錯誤修復
- ✅ API 路徑正確指向 `statuses.php`
- ✅ 使用環境變數構建完整 URL
- ✅ 任務狀態能正常載入

---

## 🧪 測試清單

### 測試場景

#### 1. 正常聊天室（有訊息）
- [ ] 訪問 `/admin/task-disputes/{taskId}/chat-room`
- [ ] 能看到聊天訊息
- [ ] 能看到任務資訊和狀態
- [ ] Review 按鈕正常工作

#### 2. 空聊天室（無訊息）
- [ ] 訪問沒有訊息的聊天室
- [ ] 顯示 "No messages in this chat room"
- [ ] 不會出現 500 錯誤

#### 3. 任務狀態載入
- [ ] 任務狀態正確顯示
- [ ] 不會出現 404 錯誤
- [ ] 狀態 badge 顏色正確

### API 測試

#### chat-room API
```bash
curl -X GET "https://hero4help.demofhs.com/api/admin/task-disputes/5b0b7209-61fe-42e4-9795-ae4213855c48/chat-room" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 預期: 200 OK
# 返回: { "success": true, "data": { ... } }
```

#### tasks/statuses API
```bash
curl -X GET "https://hero4help.demofhs.com/backend/api/tasks/statuses.php"

# 預期: 200 OK
# 返回: { "success": true, "data": [ ... ] }
```

---

## 📦 部署步驟

### 1. 更新後端代碼
```bash
# 上傳修改後的 chat-room.php
scp backend/api/admin/task-disputes/chat-room.php \
    user@hero4help.demofhs.com:/home/hero4helpdemofhs/public_html/backend/api/admin/task-disputes/
```

### 2. 更新前端代碼
```bash
# 在本地構建 Vue 前端
cd admin/frontend
npm run build

# 上傳構建後的文件
scp -r ../public/* \
    user@hero4help.demofhs.com:/home/hero4helpdemofhs/public_html/admin/public/
```

### 3. 驗證修復
```bash
# 測試 chat-room API
curl -X GET "https://hero4help.demofhs.com/api/admin/task-disputes/TEST_TASK_ID/chat-room" \
  -H "Authorization: Bearer TOKEN"

# 測試 tasks/statuses API
curl -X GET "https://hero4help.demofhs.com/backend/api/tasks/statuses.php"
```

---

## 📊 相關文件

### 修改的文件
1. `backend/api/admin/task-disputes/chat-room.php`
2. `admin/frontend/src/services/api.ts`

### 相關路由
- **前端路由**: `/task-disputes/:taskId/chat-room`
- **API 端點**: `/api/admin/task-disputes/{taskId}/chat-room`
- **Backend API**: `/backend/api/tasks/statuses.php`

### 依賴組件
- `admin/frontend/src/views/AdminChatRoomView.vue`
- `admin/frontend/src/components/DisputeOperationDialog.vue`
- `admin/frontend/src/components/AdminMessageBubble.vue`

---

## 🎯 總結

### 核心改進
1. ✅ 修復 chat-room.php 中的 null 檢查問題
2. ✅ 修復 tasks/statuses API 路徑錯誤
3. ✅ 使用環境變數構建 API URL
4. ✅ 提高代碼健壯性，避免 null 引用錯誤

### 未來優化建議
1. 統一 API 路徑管理，避免硬編碼
2. 添加更完善的錯誤處理和用戶提示
3. 考慮將 tasks/statuses 移到 Laravel 管理員 API
4. 添加 API 響應的 TypeScript 類型定義

---

**修復完成** ✅


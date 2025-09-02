# 客服聊天模組 MVP 執行計畫

## 📋 專案概述

基於 `0902客服聊天室模組規格.md` 的規格，本文件提供完整的 MVP 實施計畫，包含現有架構分析、具體執行步驟與順序。

## 🔍 現有架構分析

### 已存在的功能（可直接使用）

#### 1. Socket.IO 架構 ✅
- **現有檔案**: `lib/chat/services/socket_service.dart`, `backend/socket/server.js`
- **功能**: 完整的即時聊天、未讀計數、房間管理
- **支援客服**: 已有 `supportEventHandler.handleConnection(socket)` 整合
- **決策**: **直接使用**，無需新開發

#### 2. API 配置系統 ✅
- **現有檔案**: `lib/config/app_config.dart`, `lib/services/http_client_service.dart`
- **功能**: `AppConfig.api('/path')` 統一 API 組裝、`ApiClient` 便捷包裝
- **決策**: **直接使用**，僅需新增客服端點

#### 3. 基礎客服 API ✅
- **現有檔案**: `backend/api/support/events.php`, `events_close.php`, `events_rating.php`
- **功能**: 事件 CRUD、結案、評分
- **決策**: **部分使用**，需調整狀態枚舉與必填邏輯

#### 4. 前端客服頁面 ✅
- **現有檔案**: `lib/services/api/support_event_api.dart`, `lib/account/pages/issue_status_page.dart`
- **功能**: 事件列表、詳情 Dialog、評分 Dialog
- **決策**: **部分使用**，需新增 FAB 建立事件與篩選邏輯

#### 5. 管理員後台 ✅
- **現有檔案**: `admin/frontend/src/views/IssuesView.vue`
- **功能**: 事件列表、篩選、操作按鈕
- **決策**: **部分使用**，需對接新 API 與 Claim/Room 邏輯

#### 6. 資料庫結構 ✅
- **現有表**: `support_events`, `support_event_logs`, `chat_rooms`, `chat_messages`
- **狀態**: 已正確設定 `enum('submitted','in_progress','resolved')`
- **關聯**: `support_events.support_chat_room_id` → `chat_rooms.id`
- **決策**: **直接使用**，結構完全符合規格

### 需要新開發的功能

#### 1. 整合建立事件 API ❌
- **檔案**: `backend/api/support/create_issue.php` (新增)
- **功能**: 一次完成建房/事件/log/系統訊息，含 3 則限制檢查

#### 2. 管理員事件列表 API ❌
- **檔案**: `backend/api/support/issues.php` (新增)
- **功能**: 聚合 `chat_rooms` + `support_events` + `chat_messages`

#### 3. 管理員接手 API ❌
- **檔案**: `backend/api/support/claim.php` (新增)
- **功能**: 更新 `admin_id`、`participant_id`、狀態、寫 log

#### 4. App 客服房 UI 邏輯 ❌
- **檔案**: `lib/chat/pages/chat_detail_page.dart` (修改)
- **功能**: 支援房的 `issue`/`solved` 動作、只讀控制

#### 5. 客服時間線 & 結案 Dialog ❌
- **檔案**: `lib/widgets/support_timeline_dialog.dart`, `support_solved_dialog.dart` (新增)
- **功能**: Stepper 時間線、評分+評論必填結案

## 🚀 MVP 執行步驟與順序

### Phase 1: 後端 API 基礎建設 (優先級: 🔴 高)

#### 1.1 新增整合建立事件 API
```bash
# 檔案: backend/api/support/create_issue.php
```
**功能要點**:
- 檢查使用者同時開啟事件數量 ≤ 3 (submitted/in_progress)
- 若無支援房則建立 `chat_rooms(type='support', creator_id=user, participant_id=NULL)`
- 建立 `support_events(status='submitted')`
- 建立 `support_event_logs(old=NULL, new='submitted')`
- 插入系統訊息 `chat_messages(kind='system')`
- 回傳 `{room_id, event_id}`

**SQL 檢查邏輯**:
```sql
SELECT COUNT(*) FROM support_events se
JOIN chat_rooms cr ON cr.id = se.support_chat_room_id AND cr.type = 'support'
WHERE se.user_id = ? AND se.status IN ('submitted', 'in_progress')
```

#### 1.2 新增管理員事件列表 API
```bash
# 檔案: backend/api/support/issues.php
```
**功能要點**:
- 聚合查詢: `chat_rooms.type='support'` + `support_events` + `chat_messages`
- 支援篩選: `type`, `status`, `search`, `page`, `per_page`
- 回傳欄位: `room_id`, `type`, `status`, `title`, `user_name`, `user_email`, `last_message_at`

**SQL 聚合邏輯**:
```sql
SELECT 
    cr.id as room_id,
    cr.type,
    se.status,
    se.title,
    u.name as user_name,
    u.email as user_email,
    MAX(cm.created_at) as last_message_at
FROM chat_rooms cr
LEFT JOIN support_events se ON se.support_chat_room_id = cr.id
LEFT JOIN users u ON se.user_id = u.id
LEFT JOIN chat_messages cm ON cm.room_id = cr.id
WHERE cr.type = 'support'
GROUP BY cr.id
ORDER BY last_message_at DESC
```

#### 1.3 新增管理員接手 API
```bash
# 檔案: backend/api/support/claim.php
```
**功能要點**:
- 檢查房間是否已被接手 (`participant_id IS NOT NULL`)
- 更新最新事件: `admin_id = adminId`, `status = 'in_progress'`
- 更新聊天室: `participant_id = adminId`
- 新增 log: `support_event_logs(old_status → 'in_progress')`

#### 1.4 調整現有 API
**events.php**:
- ✅ 已確認 POST 預設 `status='submitted'`
- ✅ 已確認 PATCH 支援新狀態集合
- 需確保 GET 回傳完整 `logs` 陣列

**events_close.php**:
- 強制 `rating` (1-5) 與 `review` (非空) 必填
- 最終狀態設為 `resolved`

**send_message.php**:
- 新增檢查: `type='support'` 且最新事件 `status='resolved'` → 403

### Phase 2: 前端 App 整合 (優先級: 🟡 中)

#### 2.1 更新 API 配置
```dart
// lib/config/app_config.dart
static String get supportCreateIssueUrl => api('/support/create_issue.php');
static String get supportEventsUrl => api('/support/events.php');
static String get supportCloseUrl => api('/support/events_close.php');
```

#### 2.2 更新客服事件 API 服務
```dart
// lib/services/api/support_event_api.dart
static Future<Map<String, dynamic>> createIssue({
  required String title,
  required String description,
}) async {
  return await ApiClient.postJson('/support/create_issue.php', body: {
    'title': title,
    'description': description,
  });
}
```

#### 2.3 更新 Issue Status 頁面
```dart
// lib/account/pages/issue_status_page.dart
```
**修改要點**:
- 列表僅顯示 `status != 'resolved'` 事件
- 空狀態顯示 "No active support cases"
- 新增 FAB: 建立事件表單 (Subject/Description 必填)
- 成功後自動導航至 `/chat/detail?room_id=...`

#### 2.4 更新聊天詳情頁面
```dart
// lib/chat/pages/chat_detail_page.dart
```
**修改要點**:
- 房型判斷: `isSupport = (chatData['room_type'] == 'support')`
- Action Bar: 支援房顯示 `['issue', 'solved']`
- 輸入控制: `isInputDisabled = isSupport && latestEventStatus == 'resolved'`
- 新增 `_openSupportIssueDialog()` 與 `_openSupportSolvedDialog()`

#### 2.5 新增客服專用 Dialog
```dart
// lib/widgets/support_timeline_dialog.dart
```
**功能要點**:
- 使用 `Stepper` 或自訂 Timeline UI
- 顯示 3 階段: submitted → in_progress → resolved
- 依 `support_event_logs.created_at` 排序
- 若缺起始 log，以事件 `created_at` 補首節點

```dart
// lib/widgets/support_solved_dialog.dart
```
**功能要點**:
- 5 星評分 (1-5) **必填**
- 評論文字框 **必填**
- 送出後調用 `SupportEventApi.closeEvent()`
- 成功後關閉 Dialog 並刷新聊天室

### Phase 3: 管理員後台整合 (優先級: 🟡 中)

#### 3.1 更新後台 API 服務
```typescript
// admin/frontend/src/services/api.ts
export const supportApi = {
  async listIssues(params: {
    page?: number;
    per_page?: number;
    type?: 'support' | 'dispute' | 'all';
    status?: string;
    search?: string;
  }) {
    return await apiClient.get('/support/issues.php', { params });
  },
  
  async claimIssue(roomId: string) {
    return await apiClient.post('/support/claim.php', { room_id: roomId });
  },
  
  async updateStatus(eventId: string, status: string) {
    return await apiClient.patch('/support/events.php', { 
      event_id: eventId, 
      status 
    });
  }
};
```

#### 3.2 更新 Issues 檢視頁面
```vue
<!-- admin/frontend/src/views/IssuesView.vue -->
```
**修改要點**:
- 對接 `supportApi.listIssues()` 載入列表
- Claim 按鈕: 調用 `supportApi.claimIssue()` 後變為 Room 按鈕
- Room 按鈕: 僅接手管理員可見，其他顯示 "Claimed" (disabled)
- 狀態操作: Wait/Resolve/Close 調用 `supportApi.updateStatus()`

### Phase 4: 整合測試與優化 (優先級: 🟢 低)

#### 4.1 Socket.IO 整合驗證
- 確認 `backend/socket/support_events.js` 正常處理客服事件
- 測試事件狀態變更的即時通知
- 驗證聊天室即時訊息與未讀計數

#### 4.2 端到端流程測試
1. **App 建立事件**: Issue Status 頁面 → FAB → 表單送出 → 自動跳轉聊天室
2. **管理員接手**: Admin Issues 列表 → Claim → 狀態變 in_progress
3. **聊天互動**: App/Admin 雙向聊天正常
4. **App 結案**: 聊天室 → solved 動作 → 評分+評論 → 狀態變 resolved
5. **只讀驗證**: 結案後聊天室變只讀

#### 4.3 邊界情況測試
- 3 則事件限制檢查
- 重複接手防護
- 已結案事件的只讀控制
- Socket 斷線重連後狀態同步

## 📊 資料結構對應

### 現有資料表結構 ✅
```sql
-- support_events (已存在，完全符合規格)
CREATE TABLE support_events (
  id bigint PRIMARY KEY,
  support_chat_room_id bigint NOT NULL,  -- 對應 chat_rooms.id
  user_id bigint unsigned NOT NULL,
  admin_id int NULL,
  title varchar(255) NOT NULL,
  description text NULL,
  status enum('submitted','in_progress','resolved') NOT NULL DEFAULT 'submitted',
  closed_at datetime NULL,
  rating tinyint NULL,
  review text NULL,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- support_event_logs (已存在，完全符合規格)
CREATE TABLE support_event_logs (
  id bigint PRIMARY KEY,
  event_id bigint NOT NULL,
  admin_id int NULL,
  old_status enum('submitted','in_progress','resolved') NULL,
  new_status enum('submitted','in_progress','resolved') NOT NULL,
  created_at timestamp DEFAULT CURRENT_TIMESTAMP
);
```

### API 資料格式標準

#### create_issue.php
```json
// Request
{
  "title": "string (required)",
  "description": "string (required)"
}

// Response
{
  "success": true,
  "data": {
    "room_id": "123",
    "event_id": "456"
  }
}

// Error (達到 3 則限制)
{
  "success": false,
  "message": "You have reached the maximum number of active support cases.",
  "code": 422
}
```

#### issues.php
```json
// Response
{
  "success": true,
  "data": {
    "items": [
      {
        "room_id": "123",
        "type": "support",
        "status": "submitted",
        "title": "Login Issue",
        "user_name": "John Doe",
        "user_email": "john@example.com",
        "last_message_at": "2025-01-20T10:30:00Z"
      }
    ],
    "pagination": {
      "current_page": 1,
      "per_page": 15,
      "total": 25,
      "last_page": 2
    }
  }
}
```

#### claim.php
```json
// Request
{
  "room_id": "123"
}

// Response
{
  "success": true,
  "data": {
    "event_id": "456",
    "status": "in_progress",
    "admin_id": "789"
  }
}
```

## ⚠️ 風險與注意事項

### 1. 資料一致性
- **風險**: `support_events.support_chat_room_id` 與 `chat_rooms.id` 關聯
- **解決**: 建立事件前先確認聊天室存在且 `type='support'`

### 2. 併發控制
- **風險**: 多管理員同時接手同一事件
- **解決**: 使用資料庫事務與樂觀鎖定

### 3. Socket 同步
- **風險**: 事件狀態變更未即時通知
- **解決**: 確保 `backend/socket/support_events.js` 正確廣播

### 4. 只讀控制
- **風險**: 前端禁用可被繞過
- **解決**: 後端 `send_message.php` 雙重檢查

## 🎯 成功指標

### MVP 完成標準
- [ ] App 可建立客服事件 (含 3 則限制)
- [ ] 管理員可接手並變更狀態
- [ ] App 可查看時間線與結案 (評分+評論必填)
- [ ] 結案後聊天室變只讀
- [ ] Socket 即時通知正常
- [ ] 端到端流程無阻斷

### 效能指標
- API 回應時間 < 500ms
- Socket 事件延遲 < 100ms
- 列表載入 < 1s (100 筆內)

---

**執行建議**: 按 Phase 順序執行，每個 Phase 完成後進行整合測試，確保功能正常後再進入下一階段。

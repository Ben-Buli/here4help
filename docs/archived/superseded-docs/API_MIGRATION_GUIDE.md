# API遷移指南

## 概述

本文檔提供從現有API端點遷移到標準化API端點的詳細指南。

## 遷移對照表

### 1. 認證API遷移

#### 現有端點 → 標準端點
```bash
# 現有
POST /api/admin/login
POST /api/admin/logout
GET  /api/admin/me
POST /api/admin/refresh

# 標準化後
POST /api/admin/v1/auth/login
POST /api/admin/v1/auth/logout
GET  /api/admin/v1/auth/me
POST /api/admin/v1/auth/refresh
```

#### 前端代碼更新
```typescript
// 舊代碼
const response = await api.post('/api/admin/login', { email, password })

// 新代碼
const response = await api.post(API_ENDPOINTS.auth.login(), { email, password })
```

### 2. 用戶管理API遷移

#### 現有端點 → 標準端點
```bash
# 現有
GET    /api/admin/users
GET    /api/admin/users/{id}
PATCH  /api/admin/users/{id}/status
PATCH  /api/admin/users/{id}/permission
POST   /api/admin/users/batch-action

# 標準化後
GET    /api/admin/v1/users
GET    /api/admin/v1/users/{id}
PATCH  /api/admin/v1/users/{id}/status
PATCH  /api/admin/v1/users/{id}/permission
POST   /api/admin/v1/users/batch-action
```

### 3. 任務管理API遷移

#### 現有端點 → 標準端點
```bash
# 現有
GET    /api/admin/tasks
GET    /api/admin/tasks/{id}
PATCH  /api/admin/tasks/{id}/status

# 標準化後
GET    /api/admin/v1/tasks
GET    /api/admin/v1/tasks/{id}
PATCH  /api/admin/v1/tasks/{id}/status
```

### 4. 爭議管理API遷移

#### 現有端點 → 標準端點
```bash
# 現有
GET    /api/admin/task-disputes
GET    /api/admin/task-disputes/{id}
GET    /api/admin/task-disputes/{id}/chat-room
POST   /api/admin/task-disputes/{id}/resolve

# 標準化後
GET    /api/admin/v1/disputes
GET    /api/admin/v1/disputes/{id}
GET    /api/admin/v1/disputes/{id}/chat-room
POST   /api/admin/v1/disputes/{id}/resolve
```

### 5. 客服管理API遷移

#### 現有端點 → 標準端點
```bash
# 現有
GET    /api/admin/support-chat-rooms
GET    /api/admin/support-chat-rooms/{id}
POST   /api/admin/support-chat-rooms/{id}/claim
POST   /api/admin/support-chat-rooms/{id}/transfer
PATCH  /api/admin/support-chat-rooms/{id}/status

# 標準化後
GET    /api/admin/v1/support/issues
GET    /api/admin/v1/support/issues/{id}
POST   /api/admin/v1/support/issues/{id}/claim
POST   /api/admin/v1/support/issues/{id}/transfer
PATCH  /api/admin/v1/support/issues/{id}/status
```

## 前端代碼遷移步驟

### 步驟1: 更新API服務配置

#### 1.1 更新 `src/services/api.ts`
```typescript
// 舊代碼
export const disputeApi = {
  getChatMessages: (disputeId: number) =>
    api.get(`/api/admin/task-disputes/${disputeId}/chat-room`),
}

// 新代碼
export const disputeApi = {
  getChatMessages: (disputeId: number) =>
    api.get(API_ENDPOINTS.disputes.chatRoom(disputeId)),
}
```

#### 1.2 更新組件中的API調用
```typescript
// 舊代碼
const response = await disputeApi.getChatMessages(disputeId)

// 新代碼 - 使用統一的端點配置
const response = await disputeApi.getChatMessages(disputeId)
```

### 步驟2: 更新Vue組件

#### 2.1 更新 `DisputeChatRoomModal.vue`
```typescript
// 舊代碼
const response = await disputeApi.getChatMessages(disputeId)

// 新代碼 - 使用權限服務檢查
import { ChatRoomPermissionService } from '@/services/chat-permission-service'

const config = {
  roomType: 'dispute',
  userRole: 'admin',
  roomStatus: 'open',
  isAssignedAdmin: false
}

const canView = ChatRoomPermissionService.checkPermission(config, 'view')
if (!canView.allowed) {
  throw new Error(canView.reason)
}
```

#### 2.2 更新 `IssuesView.vue`
```typescript
// 舊代碼
const response = await supportApi.listIssues(params)

// 新代碼 - 使用標準化端點
const response = await supportApi.listIssues(params)
```

### 步驟3: 更新環境配置

#### 3.1 創建 `.env` 檔案
```bash
# 複製 .env.example 並調整設定
cp .env.example .env
```

#### 3.2 更新 `vite.config.ts`
```typescript
// 確保代理配置正確
proxy: {
  '/api': {
    target: apiBaseUrl.replace('/backend', ''),
    changeOrigin: true,
    rewrite: (path) => `/here4help/backend${path}`
  }
}
```

## 後端API遷移步驟

### 步驟1: 創建新的標準化端點

#### 1.1 創建 `backend/api/admin/v1/` 目錄結構
```bash
mkdir -p backend/api/admin/v1/{auth,users,tasks,disputes,support}
```

#### 1.2 創建認證API
```php
// backend/api/admin/v1/auth/login.php
<?php
require_once __DIR__ . '/../../../../config/database.php';
require_once __DIR__ . '/../../../../utils/Response.php';
require_once __DIR__ . '/../../../../utils/JWTManager.php';

// 重定向到現有API
header('Location: /here4help/backend/api/admin/login.php');
exit;
?>
```

### 步驟2: 實現向後兼容

#### 2.1 創建重定向端點
```php
// backend/api/admin/v1/auth/login.php
<?php
// 檢查是否為新API調用
if (strpos($_SERVER['REQUEST_URI'], '/v1/') !== false) {
    // 使用新的標準化邏輯
    require_once __DIR__ . '/../../../../api/admin/login.php';
} else {
    // 重定向到舊API
    header('Location: /here4help/backend/api/admin/login.php');
    exit;
}
?>
```

### 步驟3: 更新資料庫查詢

#### 3.1 統一資料表命名
```sql
-- 確保所有API使用相同的資料表結構
-- 例如：統一使用 support_events 而不是 support_chat_rooms
```

## 測試遷移

### 1. 單元測試
```typescript
// 測試新的API端點
describe('API Endpoints', () => {
  it('should use standardized auth endpoints', () => {
    expect(API_ENDPOINTS.auth.login()).toBe('/api/admin/auth/login')
  })
})
```

### 2. 整合測試
```typescript
// 測試API調用
describe('API Integration', () => {
  it('should authenticate with new endpoints', async () => {
    const response = await authApi.login('test@example.com', 'password')
    expect(response.status).toBe(200)
  })
})
```

### 3. 端到端測試
```typescript
// 測試完整流程
describe('E2E Tests', () => {
  it('should complete dispute resolution flow', async () => {
    // 測試爭議解決的完整流程
  })
})
```

## 部署策略

### 1. 藍綠部署
- 部署新API到新環境
- 逐步切換流量
- 監控錯誤率

### 2. 金絲雀部署
- 小比例用戶使用新API
- 監控性能指標
- 逐步擴大比例

### 3. 功能開關
```typescript
// 使用功能開關控制API版本
const useNewAPI = config.features.newApiEndpoints

if (useNewAPI) {
  return API_ENDPOINTS.auth.login()
} else {
  return '/api/admin/login'
}
```

## 監控和回滾

### 1. 監控指標
- API響應時間
- 錯誤率
- 用戶體驗指標

### 2. 回滾計劃
- 保持舊API可用
- 快速切換機制
- 資料一致性檢查

### 3. 告警設定
- 錯誤率超過閾值
- 響應時間異常
- 用戶投訴增加

## 完成檢查清單

### 前端
- [ ] 更新API配置檔案
- [ ] 更新所有組件中的API調用
- [ ] 實施權限管理服務
- [ ] 更新環境配置
- [ ] 執行測試套件

### 後端
- [ ] 創建標準化API端點
- [ ] 實現向後兼容
- [ ] 更新資料庫查詢
- [ ] 執行API測試
- [ ] 更新文檔

### 部署
- [ ] 準備部署環境
- [ ] 設定監控
- [ ] 準備回滾計劃
- [ ] 執行部署
- [ ] 驗證功能

## 常見問題

### Q: 如何處理現有的API調用？
A: 使用向後兼容的重定向，逐步遷移到新端點。

### Q: 如何確保資料一致性？
A: 使用相同的資料庫查詢邏輯，只改變端點路徑。

### Q: 如何處理版本控制？
A: 使用URL版本控制，保持多版本支援。

### Q: 如何監控遷移進度？
A: 使用功能開關和監控指標追蹤遷移狀態。

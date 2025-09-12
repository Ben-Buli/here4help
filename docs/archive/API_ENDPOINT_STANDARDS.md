# API端點標準化規範

## 概述

本文檔定義了Here4Help系統的API端點命名規範，旨在提供一致、可預測和易於維護的API設計。

## 基本原則

### 1. RESTful設計
- 使用HTTP動詞表示操作類型
- 使用名詞表示資源
- 使用階層結構表示資源關係

### 2. 命名規範
- 使用小寫字母和連字符分隔
- 使用複數名詞表示資源集合
- 使用動詞表示動作

### 3. 版本控制
- 所有API端點都包含版本前綴 `/api/v1/`
- 管理員API使用 `/api/admin/v1/` 前綴

## 端點結構

### 基礎結構
```
{base_url}/api/{version}/{resource}/{action?}
```

### 管理員API結構
```
{base_url}/api/admin/{version}/{resource}/{action?}
```

## 資源命名規範

### 1. 核心資源
| 資源 | 端點 | 說明 |
|------|------|------|
| users | `/api/v1/users` | 用戶管理 |
| tasks | `/api/v1/tasks` | 任務管理 |
| disputes | `/api/v1/disputes` | 爭議管理 |
| support | `/api/v1/support` | 客服管理 |
| chat-rooms | `/api/v1/chat-rooms` | 聊天室管理 |

### 2. 管理員資源
| 資源 | 端點 | 說明 |
|------|------|------|
| admin/users | `/api/admin/v1/users` | 管理員用戶管理 |
| admin/tasks | `/api/admin/v1/tasks` | 管理員任務管理 |
| admin/disputes | `/api/admin/v1/disputes` | 管理員爭議管理 |
| admin/support | `/api/admin/v1/support` | 管理員客服管理 |

## HTTP動詞使用規範

### 1. GET - 查詢操作
```bash
# 獲取資源列表
GET /api/v1/users
GET /api/v1/tasks
GET /api/v1/disputes

# 獲取單一資源
GET /api/v1/users/{id}
GET /api/v1/tasks/{id}
GET /api/v1/disputes/{id}

# 獲取子資源
GET /api/v1/users/{id}/activities
GET /api/v1/tasks/{id}/applications
GET /api/v1/disputes/{id}/chat-room
```

### 2. POST - 創建操作
```bash
# 創建新資源
POST /api/v1/users
POST /api/v1/tasks
POST /api/v1/disputes

# 執行動作
POST /api/v1/tasks/{id}/apply
POST /api/v1/disputes/{id}/resolve
POST /api/v1/support/{id}/claim
```

### 3. PUT - 完整更新
```bash
# 完整更新資源
PUT /api/v1/users/{id}
PUT /api/v1/tasks/{id}
```

### 4. PATCH - 部分更新
```bash
# 部分更新資源
PATCH /api/v1/users/{id}/status
PATCH /api/v1/tasks/{id}/status
PATCH /api/v1/disputes/{id}/status
```

### 5. DELETE - 刪除操作
```bash
# 刪除資源
DELETE /api/v1/users/{id}
DELETE /api/v1/tasks/{id}
```

## 具體端點規範

### 1. 認證相關
```bash
# 用戶認證
POST /api/v1/auth/login
POST /api/v1/auth/logout
POST /api/v1/auth/register
GET  /api/v1/auth/me
POST /api/v1/auth/refresh

# 管理員認證
POST /api/admin/v1/auth/login
POST /api/admin/v1/auth/logout
GET  /api/admin/v1/auth/me
POST /api/admin/v1/auth/refresh
```

### 2. 用戶管理
```bash
# 用戶端API
GET    /api/v1/users/{id}
PUT    /api/v1/users/{id}
PATCH  /api/v1/users/{id}/status
GET    /api/v1/users/{id}/activities
GET    /api/v1/users/{id}/point-transactions

# 管理員API
GET    /api/admin/v1/users
POST   /api/admin/v1/users
GET    /api/admin/v1/users/{id}
PUT    /api/admin/v1/users/{id}
PATCH  /api/admin/v1/users/{id}/status
PATCH  /api/admin/v1/users/{id}/permission
POST   /api/admin/v1/users/batch-action
GET    /api/admin/v1/users/{id}/activities
GET    /api/admin/v1/users/{id}/point-transactions
GET    /api/admin/v1/users/{id}/referral-info
```

### 3. 任務管理
```bash
# 用戶端API
GET    /api/v1/tasks
POST   /api/v1/tasks
GET    /api/v1/tasks/{id}
PUT    /api/v1/tasks/{id}
PATCH  /api/v1/tasks/{id}/status
POST   /api/v1/tasks/{id}/apply
POST   /api/v1/tasks/{id}/approve
POST   /api/v1/tasks/{id}/reject
POST   /api/v1/tasks/{id}/complete
POST   /api/v1/tasks/{id}/dispute

# 管理員API
GET    /api/admin/v1/tasks
GET    /api/admin/v1/tasks/{id}
PATCH  /api/admin/v1/tasks/{id}/status
```

### 4. 爭議管理
```bash
# 用戶端API
GET    /api/v1/disputes
POST   /api/v1/disputes
GET    /api/v1/disputes/{id}
GET    /api/v1/disputes/{id}/chat-room
POST   /api/v1/disputes/{id}/messages

# 管理員API
GET    /api/admin/v1/disputes
GET    /api/admin/v1/disputes/{id}
GET    /api/admin/v1/disputes/{id}/chat-room
POST   /api/admin/v1/disputes/{id}/resolve
PATCH  /api/admin/v1/disputes/{id}/status
```

### 5. 客服管理
```bash
# 用戶端API
GET    /api/v1/support/issues
POST   /api/v1/support/issues
GET    /api/v1/support/issues/{id}
GET    /api/v1/support/issues/{id}/chat-room
POST   /api/v1/support/issues/{id}/messages
POST   /api/v1/support/issues/{id}/close
POST   /api/v1/support/issues/{id}/rate

# 管理員API
GET    /api/admin/v1/support/issues
GET    /api/admin/v1/support/issues/{id}
POST   /api/admin/v1/support/issues/{id}/claim
POST   /api/admin/v1/support/issues/{id}/transfer
PATCH  /api/admin/v1/support/issues/{id}/status
GET    /api/admin/v1/support/issues/{id}/chat-room
```

### 6. 聊天室管理
```bash
# 用戶端API
GET    /api/v1/chat-rooms
POST   /api/v1/chat-rooms
GET    /api/v1/chat-rooms/{id}
GET    /api/v1/chat-rooms/{id}/messages
POST   /api/v1/chat-rooms/{id}/messages
PATCH  /api/v1/chat-rooms/{id}/read

# 管理員API
GET    /api/admin/v1/chat-rooms
GET    /api/admin/v1/chat-rooms/{id}
GET    /api/admin/v1/chat-rooms/{id}/messages
POST   /api/admin/v1/chat-rooms/{id}/messages
```

## 查詢參數規範

### 1. 分頁參數
```bash
?page=1&per_page=25&sort_by=created_at&sort_order=desc
```

### 2. 篩選參數
```bash
?status=active&type=support&date_from=2024-01-01&date_to=2024-12-31
```

### 3. 搜尋參數
```bash
?search=keyword&search_fields=title,description
```

## 回應格式規範

### 1. 成功回應
```json
{
  "success": true,
  "data": {
    // 實際資料
  },
  "message": "操作成功",
  "meta": {
    "pagination": {
      "current_page": 1,
      "per_page": 25,
      "total": 100,
      "last_page": 4
    }
  }
}
```

### 2. 錯誤回應
```json
{
  "success": false,
  "message": "錯誤訊息",
  "errors": {
    "field_name": ["錯誤詳情"]
  },
  "code": "ERROR_CODE"
}
```

## 狀態碼規範

### 1. 成功狀態碼
- `200 OK` - 成功獲取資源
- `201 Created` - 成功創建資源
- `204 No Content` - 成功但無內容返回

### 2. 錯誤狀態碼
- `400 Bad Request` - 請求參數錯誤
- `401 Unauthorized` - 未授權
- `403 Forbidden` - 禁止訪問
- `404 Not Found` - 資源不存在
- `422 Unprocessable Entity` - 驗證失敗
- `500 Internal Server Error` - 伺服器錯誤

## 實施計劃

### 階段1: 認證API標準化
- [ ] 統一認證端點命名
- [ ] 標準化認證回應格式
- [ ] 更新前端API調用

### 階段2: 核心資源API標準化
- [ ] 用戶管理API
- [ ] 任務管理API
- [ ] 爭議管理API

### 階段3: 聊天室API標準化
- [ ] 聊天室管理API
- [ ] 訊息管理API
- [ ] 權限控制API

### 階段4: 管理員API標準化
- [ ] 管理員專用端點
- [ ] 權限管理API
- [ ] 系統管理API

## 遷移指南

### 1. 向後兼容
- 保持舊端點可用
- 添加棄用警告
- 提供遷移文檔

### 2. 版本控制
- 使用URL版本控制
- 提供版本切換機制
- 維護多版本支援

### 3. 文檔更新
- 更新API文檔
- 提供遷移範例
- 建立最佳實踐指南

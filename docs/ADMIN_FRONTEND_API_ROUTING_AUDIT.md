# Vue管理員後台API路由完整對照表

## 📊 **路由配置檢查結果**

### **Vite代理配置** ✅
```typescript
// admin/frontend/vite.config.ts
server: {
  proxy: {
    // 管理員API代理 - 路由到Laravel應用
    '/api/admin': {
      target: 'http://localhost:8000',  // Laravel
      changeOrigin: true,
      rewrite: (path) => path
    },
    // 其他API代理 - 路由到PHP後端
    '/api': {
      target: 'http://localhost:8888',  // PHP Backend
      changeOrigin: true,
      rewrite: (path) => `/here4help/backend${path}.php`
    }
  }
}
```

## 🔍 **所有Vue頁面API使用情況**

### **1. 認證相關**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| LoginView.vue | `authApi.login()` | `/api/admin/login` | `POST /api/admin/login` | ✅ |
| AppLayout.vue | `authApi.logout()` | `/api/admin/logout` | `POST /api/admin/logout` | ✅ |
| AppLayout.vue | `authApi.me()` | `/api/admin/me` | `GET /api/admin/me` | ✅ |

### **2. 用戶管理**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| UsersView.vue | `userApi.list()` | `/api/admin/users` | `GET /api/admin/users` | ✅ |
| UsersView.vue | `userApi.batchAction()` | `/api/admin/users/batch-action` | `POST /api/admin/users/batch-action` | ✅ |
| UserDetailView.vue | `userApi.show()` | `/api/admin/users/{id}` | `GET /api/admin/users/{id}` | ✅ |
| UserEditModal.vue | `userApi.updateStatus()` | `/api/admin/users/{id}/status` | `PATCH /api/admin/users/{id}/status` | ✅ |
| UserReviewModal.vue | `userApi.review()` | `/api/admin/users/{id}/review` | `POST /api/admin/users/{id}/review` | ✅ |

### **3. 任務管理**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| TasksView.vue | `taskApi.list()` | `/api/admin/tasks` | `GET /api/admin/tasks` | ✅ |
| TaskDetailView.vue | `taskApi.show()` | `/api/admin/tasks/{id}` | `GET /api/admin/tasks/{id}` | ✅ |
| TaskDetailView.vue | `taskApi.updateStatus()` | `/api/admin/tasks/{id}/status` | `PATCH /api/admin/tasks/{id}/status` | ✅ |

### **4. 爭議管理**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| TaskDisputesView.vue | `disputeApi.list()` | `/api/admin/task-disputes` | `GET /api/admin/disputes` | ⚠️ 路由不匹配 |
| DisputeChatRoomModal.vue | `disputeApi.chatRoom()` | `/api/admin/task-disputes/{id}/chat-room` | `GET /api/admin/disputes/{id}` | ⚠️ 路由不匹配 |
| DisputeReviewDialog.vue | `disputeApi.resolve()` | `/api/admin/task-disputes/{id}/resolve` | `PATCH /api/admin/disputes/{id}/status` | ⚠️ 路由不匹配 |

### **5. 客服管理**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| IssuesView.vue | `supportApi.issues()` | `/api/admin/support-chat-rooms` | `GET /api/admin/support/issues` | ⚠️ 路由不匹配 |
| SupportChatListView.vue | `supportApi.claim()` | `/api/admin/support-chat-rooms/{id}/claim` | `POST /api/admin/support/issues/{id}/accept` | ⚠️ 路由不匹配 |
| AdminChatRoomView.vue | `supportApi.status()` | `/api/admin/support-chat-rooms/{id}/status` | `POST /api/admin/support/issues/{id}/status` | ⚠️ 路由不匹配 |

### **6. 支付管理**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| DepositApprovalPage.vue | `paymentApi.requests()` | `/api/admin/payment/requests` | `GET /api/admin/payment/requests` | ✅ |
| DepositApprovalPage.vue | `paymentApi.approve()` | `/api/admin/payment/requests/{id}/approve` | `POST /api/admin/payment/requests/{id}/approve` | ✅ |
| DepositApprovalPage.vue | `paymentApi.reject()` | `/api/admin/payment/requests/{id}/reject` | `POST /api/admin/payment/requests/{id}/reject` | ✅ |
| OfficialBankAccountPage.vue | `paymentApi.getOfficialAccounts()` | `/api/admin/payment/official-accounts` | `GET /api/admin/payment/official-accounts` | ✅ |
| OfficialBankAccountPage.vue | `paymentApi.setOfficialAccount()` | `/api/admin/payment/official-accounts` | `POST /api/admin/payment/official-accounts` | ✅ |
| FeeManagementPage.vue | `paymentApi.getFeeSettings()` | `/api/admin/payment/fee-settings` | `GET /api/admin/payment/fee-settings` | ✅ |

### **7. 日誌管理**
| 頁面 | API調用 | 前端路由 | Laravel路由 | 狀態 |
|------|---------|----------|-------------|------|
| DashboardView.vue | `logApi.systemStats()` | `/api/admin/logs` | `GET /api/admin/logs/stats` | ⚠️ 路由不匹配 |
| DashboardView.vue | `logApi.activityLogs()` | `/api/admin/logs` | `GET /api/admin/logs/activity` | ⚠️ 路由不匹配 |
| LogsView.vue | `logApi.loginLogs()` | `/api/admin/logs` | `GET /api/admin/logs/login` | ⚠️ 路由不匹配 |
| UserActivitiesView.vue | `userActivityApi.list()` | `/api/admin/user-activities` | `GET /api/admin/user-activities` | ✅ |
| UserTransactionsView.vue | 直接fetch調用 | `/backend/api/admin/users/point-transactions.php` | ❌ 應使用Laravel API |

## ⚠️ **發現的問題**

### **1. 路由不匹配問題**
```typescript
// 前端API端點配置需要修正
export const API_ENDPOINTS = {
  disputes: {
    list: () => getApiUrl('/task-disputes'),        // ❌ 應為 '/disputes'
    show: (id: number) => getApiUrl(`/task-disputes/${id}`),  // ❌ 應為 '/disputes/${id}'
  },
  support: {
    issues: () => getApiUrl('/support-chat-rooms'), // ❌ 應為 '/support/issues'
    claim: (id: number) => getApiUrl(`/support-chat-rooms/${id}/claim`), // ❌ 應為 '/support/issues/${id}/accept'
  },
}
```

### **2. 混合API調用**
UserTransactionsView.vue 直接使用fetch調用PHP後端，應該統一使用Laravel API。

### **3. 欄位命名不一致** ✅ 已修復
- ~~前端: `account_name` ↔ 後端: `account_holder`~~ ✅ 已統一
- ~~前端: `added_value` ↔ 後端: `amount_points`~~ ✅ 已統一

## 🔧 **修復建議**

### **1. 修正API端點配置**
```typescript
// admin/frontend/src/config/api.ts
export const API_ENDPOINTS = {
  // 爭議管理 - 修正路由
  disputes: {
    list: () => getApiUrl('/disputes'),
    show: (id: number) => getApiUrl(`/disputes/${id}`),
    chatRoom: (id: number) => getApiUrl(`/disputes/${id}`),
    resolve: (id: number) => getApiUrl(`/disputes/${id}/status`),
    updateStatus: (id: number) => getApiUrl(`/disputes/${id}/status`),
  },
  
  // 客服管理 - 修正路由
  support: {
    issues: () => getApiUrl('/support/issues'),
    issue: (id: number) => getApiUrl(`/support/issues/${id}`),
    claim: (id: number) => getApiUrl(`/support/issues/${id}/accept`),
    transfer: (id: number) => getApiUrl(`/support/issues/${id}/transfer`),
    status: (id: number) => getApiUrl(`/support/issues/${id}/status`),
  },
  
  // 日誌管理 - 修正路由
  logs: {
    stats: () => getApiUrl('/logs/stats'),
    activity: () => getApiUrl('/logs/activity'),
    login: () => getApiUrl('/logs/login'),
  },
}
```

### **2. 統一UserTransactionsView.vue**
```typescript
// 替換直接fetch調用
// const response = await fetch(`/backend/api/admin/users/point-transactions.php?${params}`)

// 改為使用API服務
const response = await userTransactionApi.list(params)
```

### **3. 確保Laravel路由存在**
檢查 `admin/routes/api.php` 中是否有對應的路由定義。

## ✅ **正常運作的頁面**

以下頁面的API路由配置完全正確：

1. **認證系統**: LoginView.vue, AppLayout.vue
2. **用戶管理**: UsersView.vue, UserDetailView.vue, UserEditModal.vue
3. **任務管理**: TasksView.vue, TaskDetailView.vue
4. **支付管理**: DepositApprovalPage.vue, OfficialBankAccountPage.vue
5. **用戶活動**: UserActivitiesView.vue

## 📊 **統計摘要**

| 類別 | 總數 | 正常 | 需修復 | 完成率 |
|------|------|------|--------|--------|
| **認證相關** | 3 | 3 | 0 | 100% |
| **用戶管理** | 5 | 5 | 0 | 100% |
| **任務管理** | 3 | 3 | 0 | 100% |
| **爭議管理** | 3 | 0 | 3 | 0% |
| **客服管理** | 3 | 0 | 3 | 0% |
| **支付管理** | 6 | 6 | 0 | 100% |
| **日誌管理** | 4 | 1 | 3 | 25% |
| **總計** | 27 | 18 | 9 | 67% |

## 🎯 **優先修復順序**

1. **高優先級**: 爭議管理、客服管理 (影響核心功能)
2. **中優先級**: 日誌管理 (影響監控功能)
3. **低優先級**: UserTransactionsView.vue 統一 (功能正常但架構不一致)

## 📚 **相關文檔**

- `VUE_DATA_FLOW_ANALYSIS.md` - 資料流程分析
- `ADMIN_API_ROUTING_SOLUTION.md` - API路由解決方案
- `admin/routes/api.php` - Laravel路由定義

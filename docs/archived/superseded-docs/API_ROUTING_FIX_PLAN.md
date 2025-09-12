# API路由修復計劃

## 🚨 緊急修復：管理員後台登入問題

### 問題診斷
1. **路由映射錯誤**: Vite代理配置問題
2. **API端點不匹配**: 前端配置與後端實際路徑不符
3. **環境變數缺失**: 缺少 .env 配置檔案

### 立即修復步驟

#### 步驟1: 修復Vite代理配置
```typescript
// admin/frontend/vite.config.ts
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8888',
      changeOrigin: true,
      rewrite: (path) => {
        console.log('Proxy rewrite:', path, '->', `/here4help/backend${path}.php`)
        return `/here4help/backend${path}.php`
      }
    }
  }
}
```

#### 步驟2: 創建環境配置檔案
```bash
# admin/frontend/.env
VITE_API_BASE_URL=http://localhost:8888/here4help/backend
VITE_API_TIMEOUT=10000
VITE_APP_TITLE=Here4Help Admin Panel
VITE_DEBUG_MODE=true
```

#### 步驟3: 驗證API端點
```bash
# 測試命令
curl -X POST http://localhost:8888/here4help/backend/api/admin/login.php \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"password"}'
```

## 🏗️ 長期架構建議

### 推薦架構：共用後端API

#### 優勢分析
1. **統一數據源**: 避免數據不一致
2. **減少維護成本**: 單一業務邏輯維護點
3. **提升開發效率**: 共用API減少重複開發
4. **安全性統一**: 統一的權限控制和安全策略

#### 實施方案

##### 1. API分層設計
```
/backend/api/
├── common/         # 通用API (Flutter + Admin共用)
│   ├── auth/       # 認證相關
│   ├── tasks/      # 任務管理
│   ├── chat/       # 聊天功能
│   └── support/    # 客服功能
├── admin/          # 管理員專用API
│   ├── users/      # 用戶管理
│   ├── analytics/  # 數據分析
│   ├── settings/   # 系統設定
│   └── logs/       # 日誌管理
└── mobile/         # 移動端專用API (如需要)
    └── push/       # 推送通知
```

##### 2. 權限控制策略
```php
// 統一權限檢查
function checkApiPermission($endpoint, $userRole) {
    $adminOnlyEndpoints = ['/admin/', '/analytics/', '/logs/'];
    $userEndpoints = ['/tasks/', '/chat/', '/support/'];
    
    foreach ($adminOnlyEndpoints as $adminPath) {
        if (strpos($endpoint, $adminPath) === 0) {
            return $userRole === 'admin';
        }
    }
    
    return true; // 通用端點允許所有認證用戶
}
```

##### 3. 前端配置統一
```typescript
// 統一API配置
export const API_CONFIG = {
  baseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8888/here4help/backend',
  endpoints: {
    // 通用端點
    common: {
      auth: '/api/auth',
      tasks: '/api/tasks',
      chat: '/api/chat',
      support: '/api/support'
    },
    // 管理員端點
    admin: {
      users: '/api/admin/users',
      analytics: '/api/admin/analytics',
      settings: '/api/admin/settings',
      logs: '/api/admin/logs'
    }
  }
}
```

## 🔄 遷移計劃

### 階段1: 緊急修復 (1-2天)
- [x] 修復Vite代理配置
- [x] 創建環境配置檔案
- [ ] 測試登入功能
- [ ] 驗證其他API端點

### 階段2: 架構優化 (1週)
- [ ] 重構API目錄結構
- [ ] 實施統一權限控制
- [ ] 更新前端API配置
- [ ] 完整測試套件

### 階段3: 功能增強 (2週)
- [ ] API版本控制
- [ ] 統一錯誤處理
- [ ] 性能監控
- [ ] 文檔完善

## 🧪 測試檢查清單

### 管理員後台測試
- [ ] 登入功能
- [ ] 用戶管理
- [ ] 任務管理
- [ ] 爭議處理
- [ ] 客服功能

### Flutter App測試
- [ ] 用戶認證
- [ ] 任務操作
- [ ] 聊天功能
- [ ] 客服支援

### 跨平台一致性測試
- [ ] 數據同步
- [ ] 權限控制
- [ ] 錯誤處理
- [ ] 性能表現

## 📊 監控指標

### API性能指標
- 響應時間 < 200ms
- 錯誤率 < 1%
- 可用性 > 99.9%

### 用戶體驗指標
- 登入成功率 > 99%
- 頁面載入時間 < 3s
- 功能完成率 > 95%

## 🔧 故障排除

### 常見問題
1. **404錯誤**: 檢查代理配置和檔案路徑
2. **CORS錯誤**: 確認後端CORS設定
3. **認證失敗**: 檢查JWT token配置
4. **權限錯誤**: 驗證用戶權限等級

### 調試工具
- 瀏覽器開發者工具
- Postman API測試
- 後端日誌檢查
- 網路流量分析

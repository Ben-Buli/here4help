# 登入API路由修復說明

## 問題描述
登入頁面無法找到路由 `here4help/backend/api/admin/auth/login`，出現 404 錯誤。

## 問題原因
1. **API端點不匹配**: 新的API配置嘗試訪問 `/api/admin/auth/login`，但後端實際端點是 `/api/admin/login`
2. **Vite代理配置問題**: 代理重寫規則沒有正確處理 `.php` 後綴

## 修復方案

### 1. 修復API端點配置
已更新 `admin/frontend/src/config/api.ts` 中的認證端點：

```typescript
// 修復前
auth: {
  login: () => getApiUrl('/auth/login'),  // ❌ 錯誤路徑
  logout: () => getApiUrl('/auth/logout'),
  me: () => getApiUrl('/auth/me'),
  refresh: () => getApiUrl('/auth/refresh'),
},

// 修復後
auth: {
  login: () => getApiUrl('/login'),      // ✅ 正確路徑
  logout: () => getApiUrl('/logout'),
  me: () => getApiUrl('/me'),
  refresh: () => getApiUrl('/refresh'),
},
```

### 2. 修復Vite代理配置
已更新 `admin/frontend/vite.config.ts` 中的代理重寫規則：

```typescript
// 修復前
rewrite: (path) => `/here4help/backend${path}`

// 修復後
rewrite: (path) => {
  // 如果路徑已經以 .php 結尾，直接使用
  if (path.endsWith('.php')) {
    return `/here4help/backend${path}`
  }
  // 否則添加 .php 後綴
  return `/here4help/backend${path}.php`
}
```

### 3. 環境變數配置
建議在 `admin/frontend/` 目錄下創建 `.env` 檔案：

```bash
# API 基礎 URL
VITE_API_BASE_URL=http://localhost:8888/here4help/backend

# API 請求超時時間 (毫秒)
VITE_API_TIMEOUT=10000

# 應用程式標題
VITE_APP_TITLE=Here4Help Admin Panel

# 其他配置...
```

## 修復後的API路由映射

| 前端請求 | Vite代理重寫 | 實際後端端點 |
|----------|-------------|-------------|
| `/api/admin/login` | `/here4help/backend/api/admin/login.php` | `backend/api/admin/login.php` |
| `/api/admin/logout` | `/here4help/backend/api/admin/logout.php` | `backend/api/admin/logout.php` |
| `/api/admin/me` | `/here4help/backend/api/admin/me.php` | `backend/api/admin/me.php` |

## 測試步驟

1. **重啟開發伺服器**:
   ```bash
   cd admin/frontend
   npm run dev
   ```

2. **檢查網路請求**:
   - 打開瀏覽器開發者工具
   - 嘗試登入
   - 檢查 Network 標籤中的請求URL

3. **驗證API響應**:
   - 確認請求到達正確的後端端點
   - 檢查響應狀態碼和內容

## 向後兼容性

此修復保持了與現有後端API的完全兼容性，不需要修改後端代碼。

## 未來改進

當後端API遷移到標準化端點時（如 `/api/admin/v1/auth/login`），只需要更新 `API_ENDPOINTS` 配置即可，前端代碼無需修改。

## 常見問題

### Q: 為什麼不直接修改後端API？
A: 為了保持向後兼容性，避免影響現有功能，我們選擇修復前端配置來匹配現有後端。

### Q: 如何確認修復是否成功？
A: 檢查瀏覽器開發者工具中的Network請求，確認請求URL正確且返回200狀態碼。

### Q: 如果還有其他API端點出現類似問題怎麼辦？
A: 按照相同的模式修復 `API_ENDPOINTS` 配置，確保前端請求路徑與後端實際端點匹配。

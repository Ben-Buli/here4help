# 環境變數配置

## 環境檔案

### `.env` (開發環境)
```bash
VITE_API_BASE_URL=http://localhost:8000
VITE_API_TIMEOUT=10000
VITE_APP_TITLE=Admin Panel
```

### `.env.local` (本地測試)
```bash
VITE_API_BASE_URL=http://localhost:8000
VITE_API_TIMEOUT=10000
VITE_APP_TITLE=Admin Panel (Local)
```

### `.env.production` (生產環境)
```bash
VITE_API_BASE_URL=https://api.yourdomain.com
VITE_API_TIMEOUT=15000
VITE_APP_TITLE=Admin Panel
```

## 環境變數說明

- `VITE_API_BASE_URL`: API 伺服器基礎 URL
- `VITE_API_TIMEOUT`: API 請求超時時間（毫秒）
- `VITE_APP_TITLE`: 應用程式標題

## 使用方式

### 在 Vite 配置中使用
```typescript
// vite.config.ts
import { loadEnv } from 'vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  
  return {
    server: {
      proxy: {
        '/api': {
          target: env.VITE_API_BASE_URL,
          changeOrigin: true,
        }
      }
    }
  }
})
```

### 在 Vue 組件中使用
```typescript
// 使用配置函數
import { getImageUrl, getApiUrl } from '@/config/env'

// 圖片 URL
const imageUrl = getImageUrl('student_id_1.jpg')

// API URL
const apiUrl = getApiUrl('/api/users')
```

### 直接使用環境變數
```typescript
// 直接存取
const apiUrl = import.meta.env.VITE_API_BASE_URL
const timeout = import.meta.env.VITE_API_TIMEOUT
```

## 環境檢測

```typescript
import { isLocal, isProduction, isStaging } from '@/config/env'

if (isLocal) {
  // 本地開發邏輯
} else if (isProduction) {
  // 生產環境邏輯
}
```

## 部署注意事項

1. **開發環境**: 使用 `.env` 或 `.env.local`
2. **生產環境**: 使用 `.env.production`
3. **CI/CD**: 在部署腳本中設定環境變數
4. **安全性**: 不要將敏感資訊放在前端環境變數中

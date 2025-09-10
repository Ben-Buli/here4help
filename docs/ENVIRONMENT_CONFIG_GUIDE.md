# Here4Help 環境配置指南

## 📁 **專案環境配置結構**

Here4Help 專案包含三個不同的應用程式，每個都有自己的環境配置：

```
here4help/
├── .env                           # 🔵 Flutter App 根目錄環境配置
├── backend/.env                   # 🟡 後端PHP環境配置  
├── admin/frontend/.env            # 🔴 管理員後台環境配置 (Vue.js)
└── assets/app_env/                # 📱 Flutter 多環境配置
    ├── development.json
    ├── production.json
    ├── android_emulator.json
    ├── ios_simulator.json
    └── web.json
```

## 🔵 **Flutter App 環境配置**

### **位置**: `/here4help/.env`
```bash
# Flutter App 的環境變數
ENVIRONMENT=development
API_BASE_URL=http://127.0.0.1:8888/here4help/backend
SOCKET_URL=http://127.0.0.1:3001
```

### **多環境配置**: `/here4help/assets/app_env/`
Flutter App 使用JSON檔案進行多環境配置：

#### **development.json**
```json
{
  "environment": "development",
  "public": {
    "api_origin": "http://127.0.0.1:8888",
    "api_prefix": "/here4help/backend/api",
    "api_base_url": "http://127.0.0.1:8888/here4help/backend",
    "socket_url": "http://127.0.0.1:3001"
  }
}
```

#### **production.json**
```json
{
  "environment": "production",
  "public": {
    "api_origin": "https://hero4help.demofhs.com",
    "api_prefix": "/here4help/backend/api",
    "api_base_url": "https://hero4help.demofhs.com",
    "socket_url": "https://hero4help.demofhs.com:3001"
  }
}
```

## 🟡 **後端PHP環境配置**

### **位置**: `/here4help/backend/.env`
```bash
# 資料庫配置
DB_HOST=localhost
DB_NAME=here4help
DB_USER=root
DB_PASS=password

# JWT 配置
JWT_SECRET=your_jwt_secret_key_here
JWT_EXPIRY=3600

# 第三方服務配置
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret

# 檔案上傳配置
UPLOAD_MAX_SIZE=10485760
ALLOWED_EXTENSIONS=jpg,jpeg,png,gif,pdf,doc,docx

# 郵件配置
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password

# 系統配置
DEBUG_MODE=true
LOG_LEVEL=debug
TIMEZONE=Asia/Taipei
```

## 🔴 **管理員後台環境配置**

### **位置**: `/here4help/admin/frontend/.env`
```bash
# API 基礎 URL
VITE_API_BASE_URL=http://localhost:8888/here4help/backend

# API 請求超時時間 (毫秒)
VITE_API_TIMEOUT=10000

# 應用程式標題
VITE_APP_TITLE=Here4Help Admin Panel

# 應用程式版本
VITE_APP_VERSION=1.0.0

# 是否啟用調試模式
VITE_DEBUG_MODE=true

# Socket 伺服器 URL (用於即時通知)
VITE_SOCKET_URL=http://localhost:3001

# 圖片基礎 URL
VITE_IMAGE_BASE_URL=http://localhost:8888/here4help

# 功能開關
VITE_ENABLE_CHAT=true
VITE_ENABLE_DISPUTES=true
VITE_ENABLE_SUPPORT=true
VITE_ENABLE_ANALYTICS=true
```

## 🌍 **不同環境的配置**

### **開發環境 (Development)**
- **Flutter**: 使用 `development.json`
- **後端**: 使用本地資料庫和調試模式
- **管理員後台**: 使用 `localhost:8888` API

### **生產環境 (Production)**
- **Flutter**: 使用 `production.json`
- **後端**: 使用生產資料庫和安全配置
- **管理員後台**: 使用生產API URL

### **測試環境 (Staging)**
- **Flutter**: 使用 `staging.json`
- **後端**: 使用測試資料庫
- **管理員後台**: 使用測試API URL

## 🔧 **環境配置管理**

### **1. 建立環境配置檔案**
```bash
# Flutter App (如果不存在)
touch .env

# 後端PHP (如果不存在)
touch backend/.env

# 管理員後台 (已建立)
# admin/frontend/.env 已存在
```

### **2. 環境變數優先級**
1. **系統環境變數** (最高優先級)
2. **`.env` 檔案**
3. **預設值** (最低優先級)

### **3. 安全注意事項**
- ❌ **不要提交敏感資訊到Git**
- ✅ **使用 `.env.example` 作為範本**
- ✅ **在 `.gitignore` 中排除 `.env` 檔案**
- ✅ **定期更新密鑰和憑證**

## 📋 **環境配置檢查清單**

### **開發環境設定**
- [ ] Flutter App `.env` 檔案存在
- [ ] 後端 `backend/.env` 檔案存在
- [ ] 管理員後台 `admin/frontend/.env` 檔案存在
- [ ] 資料庫連線正常
- [ ] API端點可訪問
- [ ] Socket連線正常

### **生產環境設定**
- [ ] 所有敏感資訊使用環境變數
- [ ] HTTPS配置正確
- [ ] 資料庫安全設定
- [ ] 檔案權限正確
- [ ] 日誌配置適當

## 🚀 **快速設定指令**

### **開發環境快速設定**
```bash
# 1. 設定Flutter環境
cd /path/to/here4help
echo "ENVIRONMENT=development" > .env

# 2. 設定後端環境
cd backend
cp .env.example .env
# 編輯 .env 檔案設定資料庫連線

# 3. 設定管理員後台環境 (已完成)
cd admin/frontend
# .env 檔案已存在

# 4. 啟動所有服務
# 後端 (在 backend 目錄)
php -S localhost:8888

# 管理員後台 (在 admin/frontend 目錄)
npm run dev

# Flutter App
flutter run
```

## 🔍 **故障排除**

### **常見問題**
1. **API連線失敗**: 檢查 `VITE_API_BASE_URL` 設定
2. **CORS錯誤**: 檢查後端CORS設定
3. **資料庫連線失敗**: 檢查 `backend/.env` 資料庫設定
4. **環境變數未載入**: 重啟開發伺服器

### **調試工具**
- 瀏覽器開發者工具
- 後端錯誤日誌
- Flutter調試輸出
- 網路請求監控

## 📚 **相關文檔**
- `API_ROUTING_FIX_PLAN.md` - API路由修復計劃
- `API_ARCHITECTURE_RECOMMENDATION.md` - API架構建議
- `LOGIN_API_FIX.md` - 登入API修復說明

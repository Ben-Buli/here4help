# Here4Help CPanel 完整部署指南

## 🎯 部署目標

將以下三個組件部署到 CPanel：
- **Backend** (PHP API) → `public_html/backend/`
- **Admin** (Laravel + Vue.js) → `public_html/admin/`
- **Flutter Web** → `public_html/frontend/`

## 📁 目標 CPanel 結構

```
public_html/
├── backend/                    # PHP 後端 API
│   ├── api/                   # API 端點
│   ├── config/                # 配置文件
│   ├── utils/                 # 工具類
│   ├── uploads/               # 上傳文件目錄
│   ├── .env                   # 後端環境配置
│   └── .htaccess              # API 路由規則
├── admin/                     # Laravel 管理後台
│   ├── app/                   # Laravel 應用
│   ├── public/                # Laravel 公開目錄
│   ├── storage/               # Laravel 存儲目錄
│   ├── .env                   # Laravel 環境配置
│   └── .htaccess              # Laravel 路由規則
├── frontend/                  # Flutter Web 應用
│   ├── index.html             # Flutter Web 主頁
│   ├── main.dart.js           # Flutter 主程式
│   ├── flutter_bootstrap.js   # Flutter 啟動程式
│   ├── assets/                # 靜態資源
│   │   └── env.json           # 公開環境配置
│   ├── icons/                 # 應用圖標
│   └── manifest.json          # Web 應用清單
└── .htaccess                  # 主域名路由規則
```

---

## 🚀 部署步驟

### **步驟 1: 登入 CPanel**

1. 訪問：`https://hero4help.demofhs.com:2083`
2. 使用您的 CPanel 帳號登入
3. 打開 "文件管理器"

### **步驟 2: 部署 Backend (PHP API)**

#### 2.1 上傳 Backend 檔案
1. 導航到 `public_html/`
2. 上傳 `backend_cpanel_deploy.tar.gz`
3. 解壓縮檔案
4. 將解壓縮的內容移動到 `public_html/backend/`

#### 2.2 設定 Backend 環境配置
1. 在 `public_html/backend/` 中創建 `.env` 檔案
2. 複製 `backend_cpanel.env` 的內容到 `.env`
3. 設定檔案權限為 600

#### 2.3 設定 Backend .htaccess
在 `public_html/backend/` 中創建 `.htaccess` 檔案：

```apache
RewriteEngine On

# 啟用 CORS
Header always set Access-Control-Allow-Origin "*"
Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
Header always set Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"

# 處理 OPTIONS 請求
RewriteCond %{REQUEST_METHOD} OPTIONS
RewriteRule ^(.*)$ $1 [R=200,L]

# API 路由重寫
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^api/(.*)$ api/$1 [QSA,L]

# 保護敏感文件
<Files ".env">
    Order allow,deny
    Deny from all
</Files>

<Files "*.log">
    Order allow,deny
    Deny from all
</Files>

# 設定上傳文件類型
<FilesMatch "\.(jpg|jpeg|png|gif|pdf|doc|docx)$">
    Header set Cache-Control "max-age=2592000, public"
</FilesMatch>
```

#### 2.4 設定檔案權限
- `backend/` 目錄：755
- `backend/.env` 檔案：600
- `backend/uploads/` 目錄：755

### **步驟 3: 部署 Admin (Laravel 管理後台)**

#### 3.1 上傳 Admin 檔案
1. 在 `public_html/` 中上傳 `admin_cpanel_deploy.tar.gz`
2. 解壓縮檔案
3. 將解壓縮的內容移動到 `public_html/admin/`

#### 3.2 設定 Admin 環境配置
1. 在 `public_html/admin/` 中創建 `.env` 檔案
2. 複製 `admin_cpanel.env` 的內容到 `.env`
3. 設定檔案權限為 600

#### 3.3 執行 Laravel 初始化
如果 cPanel 支援 SSH，執行以下指令：

```bash
cd public_html/admin

# 安裝 Composer 依賴 (生產環境)
composer install --no-dev --optimize-autoloader

# Laravel 初始化
php artisan migrate
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

#### 3.4 建置 Admin Frontend
在本地執行前端建置：

```bash
cd admin/frontend
npm install
npm run build
```

然後將 `admin/frontend/dist/` 目錄的內容上傳到 `public_html/admin/public/`

#### 3.5 設定 Admin .htaccess
創建 `public_html/admin/.htaccess` 檔案：

```apache
RewriteEngine On

# 重定向到 public 目錄
RewriteCond %{REQUEST_URI} !^/admin/public/
RewriteRule ^(.*)$ /admin/public/$1 [L]
```

創建 `public_html/admin/public/.htaccess` 檔案：

```apache
<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>

    RewriteEngine On

    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    # Redirect Trailing Slashes If Not A Folder...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_URI} (.+)/$
    RewriteRule ^ %1 [L,R=301]

    # Send Requests To Front Controller...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>
```

### **步驟 4: 部署 Flutter Web**

#### 4.1 上傳 Flutter Web 檔案
1. 在 `public_html/` 中上傳 `flutter_web_cpanel_deploy.tar.gz`
2. 解壓縮檔案
3. 將解壓縮的內容移動到 `public_html/frontend/`

#### 4.2 驗證 Flutter Web 配置
確認 `public_html/frontend/assets/env.json` 包含正確的配置：

```json
{
  "API_BASE_URL": "https://hero4help.demofhs.com/backend",
  "SOCKET_URL": "https://hero4help.demofhs.com:3001",
  "APP_ENV": "production",
  "IMAGE_BASE_URL": "https://hero4help.demofhs.com",
  "API_ORIGIN": "https://hero4help.demofhs.com",
  "API_PREFIX": "/backend/api",
  "FEATURE_THIRD_PARTY_AUTH": true,
  "FEATURE_CHAT": true,
  "FEATURE_TASKS": true,
  "FEATURE_PAYMENTS": false,
  "GOOGLE_CLIENT_ID": "102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com",
  "FACEBOOK_APP_ID": "1037019294991326",
  "APPLE_SERVICE_ID": "com.nccu.here4help.login"
}
```

### **步驟 5: 設定主域名路由**

創建 `public_html/.htaccess` 檔案：

```apache
RewriteEngine On

# 強制 HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Backend API 路由
RewriteRule ^backend/(.*)$ backend/$1 [L]

# Admin 路由
RewriteRule ^admin/(.*)$ admin/public/$1 [L]

# Flutter Web 路由
RewriteRule ^frontend/(.*)$ frontend/$1 [L]

# 根路徑重定向到 Flutter Web 應用
RewriteCond %{REQUEST_URI} ^/$
RewriteRule ^$ /frontend/ [L,R=301]

# 保護敏感文件
<Files ".env">
    Order allow,deny
    Deny from all
</Files>
```

---

## 🧪 測試部署

### **測試 Backend API**
```bash
# 測試 API 健康檢查
curl https://hero4help.demofhs.com/backend/api/ping.php
# 預期回應: {"pong":true}

# 測試 API 端點
curl https://hero4help.demofhs.com/backend/api/system/health.php
# 預期回應: {"status":"ok","timestamp":"..."}
```

### **測試 Admin 後台**
```bash
# 測試管理後台
curl https://hero4help.demofhs.com/admin
# 預期回應: HTML 頁面內容
```

### **測試 Flutter Web**
```bash
# 測試 Flutter Web 主頁
curl https://hero4help.demofhs.com/frontend/
# 預期回應: HTML 頁面內容

# 測試 JavaScript 檔案
curl https://hero4help.demofhs.com/frontend/flutter_bootstrap.js
# 預期回應: JavaScript 程式碼

# 測試環境配置
curl https://hero4help.demofhs.com/frontend/assets/env.json
# 預期回應: JSON 配置
```

### **測試根路徑重定向**
```bash
# 測試根路徑重定向
curl -I https://hero4help.demofhs.com/
# 預期回應: 301 重定向到 /frontend/
```

---

## 🔧 故障排除

### **常見問題**

#### 1. 500 內部伺服器錯誤
- 檢查 `.htaccess` 語法
- 檢查檔案權限
- 查看 cPanel 錯誤日誌

#### 2. 資料庫連接失敗
- 確認資料庫憑證正確
- 檢查資料庫用戶權限
- 確認資料庫服務正常

#### 3. Laravel 錯誤
- 確認 `APP_KEY` 已設定
- 檢查 `storage/` 目錄權限
- 執行 `php artisan config:clear`

#### 4. Flutter Web MIME 類型錯誤
- 確認 Flutter Web 檔案正確部署
- 檢查 `.htaccess` 路由規則
- 驗證靜態檔案服務

#### 5. CORS 錯誤
- 檢查 `.htaccess` 中的 CORS 設定
- 確認 `ALLOWED_ORIGINS` 配置正確

---

## 📋 部署檢查清單

### **Backend 部署**
- [ ] 檔案上傳完成
- [ ] `.env` 配置正確
- [ ] 資料庫連接正常
- [ ] API 端點可訪問
- [ ] 檔案權限正確

### **Admin 部署**
- [ ] Laravel 檔案上傳完成
- [ ] Composer 依賴安裝
- [ ] 資料庫遷移完成
- [ ] Frontend 建置上傳
- [ ] 管理員登入正常

### **Flutter Web 部署**
- [ ] Flutter Web 檔案上傳完成
- [ ] `env.json` 配置正確
- [ ] JavaScript 檔案可訪問
- [ ] 靜態資源載入正常

### **整體測試**
- [ ] SSL 憑證正常
- [ ] 主域名路由正確
- [ ] 所有功能測試通過
- [ ] 效能測試達標

---

## 🚨 重要注意事項

### **環境配置安全**
- 確保 `.env` 檔案不會被公開訪問
- 敏感資訊只存在伺服器端
- Flutter Web 的 `env.json` 只包含公開資訊

### **檔案權限**
- `.env` 檔案權限設為 600
- 目錄權限設為 755
- 可執行檔案權限設為 755

### **備份策略**
- 部署前備份現有檔案
- 定期備份資料庫
- 保留部署壓縮檔

---

**部署完成後記得：**
- 更新 DNS 記錄 (如需要)
- 設定定期備份
- 監控系統效能
- 準備維護計劃

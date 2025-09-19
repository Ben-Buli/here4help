# Here4Help CPanel 部署修復指南

## 🚨 **問題診斷**

根據您提供的 console 輸出，發現以下問題：

### **問題 1: 環境配置錯誤**
```
Environment: development
API Origin: http://localhost:8888
API Base URL: http://localhost:8888/here4help/backend
```
**原因**: Flutter Web 載入了開發環境配置，而不是生產環境配置

### **問題 2: CPanel 路徑洩露**
```
https://hero4help.demofhs.com/home/hero4helpdemofhs/public_html/frontend/#/login
```
**原因**: `.htaccess` 路由規則錯誤，導致內部路徑被暴露

### **問題 3: 靜態檔案返回 HTML**
所有 Flutter Web 的靜態檔案（manifest.json, env.json, main.dart.js）都返回 HTML 內容
**原因**: Flutter Web 檔案沒有正確部署，所有請求都被重定向到 index.html

---

## 🔧 **修復步驟**

### **步驟 1: 重新部署 Flutter Web**

#### 1.1 登入 CPanel
1. 訪問：`https://hero4help.demofhs.com:2083`
2. 打開 "文件管理器"
3. 導航到 `public_html/`

#### 1.2 清理現有檔案
1. 刪除 `public_html/frontend/` 目錄下的所有檔案
2. 確保目錄結構乾淨

#### 1.3 上傳修復後的檔案
1. 上傳 `flutter_web_cpanel_fixed.tar.gz` 到 `public_html/`
2. 解壓縮檔案
3. 將解壓縮的內容移動到 `public_html/frontend/`

#### 1.4 設定 Flutter Web .htaccess
在 `public_html/frontend/` 中創建 `.htaccess` 檔案，內容如下：

```apache
RewriteEngine On

# Flutter Web SPA 路由支援
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^(.*)$ index.html [L]

# 靜態檔案快取
<FilesMatch "\.(js|css)$">
    Header set Cache-Control "max-age=31536000, public"
    Header set Content-Type "application/javascript"
</FilesMatch>

<FilesMatch "\.json$">
    Header set Content-Type "application/json"
    Header set Cache-Control "no-cache, no-store, must-revalidate"
</FilesMatch>

# 安全設定
<Files ".env">
    Order allow,deny
    Deny from all
</Files>
```

### **步驟 2: 修復主域名 .htaccess**

在 `public_html/` 中創建 `.htaccess` 檔案，內容如下：

```apache
RewriteEngine On

# 強制 HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# 靜態檔案服務 (優先處理)
RewriteCond %{REQUEST_URI} ^/frontend/(.*\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|json))$
RewriteRule ^frontend/(.*)$ /frontend/$1 [L]

RewriteCond %{REQUEST_URI} ^/backend/(.*\.(php|css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot))$
RewriteRule ^backend/(.*)$ /backend/$1 [L]

RewriteCond %{REQUEST_URI} ^/admin/(.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot))$
RewriteRule ^admin/(.*)$ /admin/public/$1 [L]

# API 路由
RewriteCond %{REQUEST_URI} ^/backend/api/
RewriteRule ^backend/(.*)$ /backend/$1 [L]

# 應用路由
RewriteCond %{REQUEST_URI} ^/admin/
RewriteRule ^admin/(.*)$ /admin/public/$1 [L]

RewriteCond %{REQUEST_URI} ^/frontend/
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^frontend/(.*)$ /frontend/index.html [L]

# 根路徑重定向到 Flutter Web
RewriteCond %{REQUEST_URI} ^/$
RewriteRule ^$ /frontend/ [L,R=301]

# 安全設定
<Files ".env">
    Order allow,deny
    Deny from all
</Files>
```

### **步驟 3: 驗證環境配置**

確認 `public_html/frontend/assets/env.json` 包含正確的生產環境配置：

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

---

## 🧪 **測試修復結果**

### **測試 1: 環境配置**
```bash
curl https://hero4help.demofhs.com/frontend/assets/env.json
# 預期回應: JSON 格式的環境配置
```

### **測試 2: manifest.json**
```bash
curl https://hero4help.demofhs.com/frontend/manifest.json
# 預期回應: JSON 格式的 Web 應用清單
```

### **測試 3: JavaScript 檔案**
```bash
curl https://hero4help.demofhs.com/frontend/main.dart.js | head -5
# 預期回應: JavaScript 程式碼
```

### **測試 4: 根路徑重定向**
```bash
curl -I https://hero4help.demofhs.com/
# 預期回應: 301 重定向到 /frontend/
```

### **測試 5: Flutter Web 應用**
訪問：`https://hero4help.demofhs.com/frontend/`
- 應該看到 Flutter Web 應用
- Console 應該顯示生產環境配置
- 不應該有 manifest.json 語法錯誤

---

## 🎯 **路由架構說明**

### **Admin 與 Flutter Web 區分**

根據您的需求，建議使用以下路由架構：

```
https://hero4help.demofhs.com/
├── /                    # 重定向到 Flutter Web
├── /frontend/           # Flutter Web 應用
│   ├── /login           # Flutter Web 登入頁面
│   ├── /tasks           # Flutter Web 任務頁面
│   └── /chat            # Flutter Web 聊天頁面
├── /admin/              # Vue.js 管理後台
│   ├── /dashboard       # 管理員儀表板
│   ├── /users           # 用戶管理
│   └── /settings        # 系統設定
└── /backend/            # PHP API 服務
    └── /api/            # API 端點
```

### **共用 Backend API**

Admin 和 Flutter Web 都可以使用相同的 Backend API：
- **Flutter Web**: `https://hero4help.demofhs.com/backend/api/`
- **Admin**: `https://hero4help.demofhs.com/backend/api/`

但可以透過不同的認證機制區分：
- **Flutter Web**: 使用 JWT Token (用戶認證)
- **Admin**: 使用 Laravel Sanctum (管理員認證)

---

## 🔍 **故障排除**

### **如果仍然出現問題**

#### 1. 檢查檔案權限
```bash
# 在 CPanel 文件管理器中設定
frontend/ 目錄: 755
frontend/.htaccess: 644
frontend/assets/env.json: 644
```

#### 2. 檢查 .htaccess 語法
- 確保沒有語法錯誤
- 檢查 Apache 錯誤日誌

#### 3. 清除瀏覽器快取
- 使用無痕模式測試
- 清除瀏覽器快取和 Cookie

#### 4. 檢查 CPanel 錯誤日誌
- 在 CPanel 中查看 "錯誤日誌"
- 尋找相關的錯誤訊息

---

## ✅ **修復完成檢查清單**

- [ ] Flutter Web 檔案正確部署
- [ ] 環境配置檔案存在且正確
- [ ] manifest.json 可正常訪問
- [ ] JavaScript 檔案可正常載入
- [ ] 根路徑正確重定向
- [ ] Admin 和 Flutter Web 路由分離
- [ ] 無 CPanel 路徑洩露
- [ ] Console 顯示生產環境配置

---

**修復完成後，您應該能夠：**
1. 正常訪問 `https://hero4help.demofhs.com/frontend/`
2. 看到正確的生產環境配置
3. 沒有 manifest.json 語法錯誤
4. 正常使用 Flutter Web 應用功能

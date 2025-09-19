# cPanel 部署路由修改指南

## 📋 概述

本指南將三個功能部署到 cPanel 的統一路由架構：
- **Flutter Web**: `https://hero4help.demofhs.com/web/`
- **Admin 管理員後台**: `https://hero4help.demofhs.com/admin/`
- **Backend API**: `https://hero4help.demofhs.com/backend/`
- **Socket 服務**: `https://hero4help.demofhs.com/backend/socket/`

---

## 🚨 需要確認的問題

### 1. Socket 端口問題
**問題**: cPanel 共享主機不支援自定義端口 3001
**決策**: 
- 方案 A: 使用 Apache 代理到 `/backend/socket/`

**請確認**: 您偏好哪個方案？

### 2. Admin 根路由衝突（已手動移除解決此問題）
**問題**: `admin/routes/web.php` 中的根路由會攔截所有根目錄請求
**決策**: 移除或修改此路由（決策：移除此路由）
**請確認**: 是否同意移除 Admin 的根路由重定向？

### 3. 根目錄重定向
**問題**: 根目錄 `/` 應該重定向到 `/web/` 還是 `/admin/`？
**決策**: 重定向到 `/web/` (Flutter Web 應用)
**請確認**: 是否同意此設定？（同意）

---

## 📝 詳細修改步驟

### 步驟 1: 環境變數更新

#### 1.1 Backend 環境變數 (`backend_cpanel.env`)

```bash
# 應用程式配置
APP_URL=https://hero4help.demofhs.com
FRONTEND_URL=https://hero4help.demofhs.com

# Socket 配置 (需要確認方案)
SOCKET_PORT=8080  # 或保持 3001 如果使用代理
SOCKET_URL=https://hero4help.demofhs.com/backend/socket
SOCKET_SERVER_URL=https://hero4help.demofhs.com/backend/socket

# OAuth 回調 URL
GOOGLE_REDIRECT_URI=https://hero4help.demofhs.com/backend/api/auth/google-callback.php
FACEBOOK_REDIRECT_URI=https://hero4help.demofhs.com/backend/api/auth/facebook-callback.php
APPLE_REDIRECT_URI=https://hero4help.demofhs.com/backend/api/auth/apple-callback.php

# CORS 配置
ALLOWED_ORIGINS=https://hero4help.demofhs.com,https://hero4help.demofhs.com/web,https://hero4help.demofhs.com/admin

# 圖片配置 (確認: 不需要 /backend 前綴)
IMAGE_BASE_URL=https://hero4help.demofhs.com
```

#### 1.2 Admin 環境變數 (`admin_cpanel.env`)

```bash
# 應用程式配置
APP_URL=https://hero4help.demofhs.com
FRONTEND_URL=https://hero4help.demofhs.com

# Backend API 整合
BACKEND_API_URL=https://hero4help.demofhs.com/backend/api

# Socket 配置
SOCKET_SERVER_URL=https://hero4help.demofhs.com/backend/socket
SOCKET_ADMIN_NAMESPACE=/admin

# Vite 配置
VITE_API_BASE_URL=https://hero4help.demofhs.com/backend/api
VITE_SOCKET_URL=https://hero4help.demofhs.com/backend/socket
```

#### 1.3 Flutter Web 環境變數

```bash
# 需要建立 web/.env 或更新建置配置
API_BASE_URL=https://hero4help.demofhs.com/backend/api
SOCKET_URL=https://hero4help.demofhs.com/backend/socket
IMAGE_BASE_URL=https://hero4help.demofhs.com
```

### 步驟 2: 路由配置修改

#### 2.1 移除 Admin 根路由衝突

**檔案**: `admin/routes/web.php`

```php
<?php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\WebController;

// 移除或註解掉這行 (第 46 行)
// Route::get('/', [WebController::class, 'redirectRoot']);

// 保留其他路由
Route::prefix('admin')->group(function () {
    Route::get('/', [WebController::class, 'index']);
    Route::get('/login', [WebController::class, 'index']);
    Route::get('/dashboard', [WebController::class, 'index']);
    Route::get('/{any}', [WebController::class, 'index'])->where('any', '.*');
});
```

#### 2.2 更新 .htaccess 主配置

**檔案**: `public_html/.htaccess`

```apache
# 啟用重寫引擎
RewriteEngine On

# =============================================================================
# 根目錄重定向 (需要確認)
# =============================================================================
# 重定向根目錄到 Flutter Web 應用
RewriteCond %{REQUEST_URI} ^/$
RewriteRule ^$ web/ [L,R=301]

# =============================================================================
# Backend API 路由
# =============================================================================
RewriteCond %{REQUEST_URI} ^/backend/api/
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^backend/api/(.*)$ backend/api/$1.php [L,QSA]

# =============================================================================
# Socket 代理配置 (需要確認方案)
# =============================================================================
# 方案 A: Apache 代理 (推薦)
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule ^backend/socket/(.*)$ "ws://localhost:8080/$1" [P,L]

RewriteRule ^backend/socket/(.*)$ http://localhost:8080/$1 [P,L]

# =============================================================================
# Admin 管理員後台路由
# =============================================================================
RewriteCond %{REQUEST_URI} ^/admin
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^admin/(.*)$ admin/public/$1 [L,QSA]

# =============================================================================
# Flutter Web 應用路由
# =============================================================================
RewriteCond %{REQUEST_URI} ^/web/
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule ^(.*)$ - [L]

RewriteCond %{REQUEST_URI} ^/web/
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^web/(.*)$ web/index.html [L]

# =============================================================================
# 媒體檔案處理
# =============================================================================
RewriteRule ^uploads/(.*)$ backend/uploads/$1 [L]
RewriteRule ^backend/uploads/(.*)$ backend/uploads/$1 [L]

# =============================================================================
# 其他請求重定向到 Flutter Web
# =============================================================================
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteCond %{REQUEST_URI} !^/backend
RewriteCond %{REQUEST_URI} !^/admin
RewriteCond %{REQUEST_URI} !^/web
RewriteCond %{REQUEST_URI} !^/api
RewriteCond %{REQUEST_URI} !^/socket
RewriteRule ^(.*)$ web/index.html [L]
```

### 步驟 3: Socket 伺服器配置

#### 3.1 修改 Socket 伺服器端口

**檔案**: `backend/socket/server.js`

```javascript
// 修改第 26 行
const PORT = process.env.SOCKET_PORT || 8080; // 從 3001 改為 8080
```

#### 3.2 更新 Socket 環境變數

**檔案**: `backend_cpanel.env`

```bash
# Socket 配置
SOCKET_PORT=8080
SOCKET_HOST=localhost
SOCKET_URL=https://hero4help.demofhs.com/backend/socket
SOCKET_SERVER_URL=https://hero4help.demofhs.com/backend/socket
```

### 步驟 4: CORS 配置更新

#### 4.1 更新 Backend CORS 配置

**檔案**: `backend/config/cors.php`

```php
public static function getAllowedOrigins() {
    $env = $_ENV['APP_ENV'] ?? 'development';
    
    switch ($env) {
        case 'production':
            return [
                'https://hero4help.demofhs.com',
                'https://hero4help.demofhs.com/web',
                'https://hero4help.demofhs.com/admin',
                'https://here4help.com',
                'https://www.here4help.com'
            ];
            
        case 'staging':
            return [
                'https://staging.here4help.com',
                'https://test.here4help.com',
                'http://localhost:3000',
                'http://localhost:8080'
            ];
            
        case 'development':
        default:
            return [
                'http://localhost:3000',
                'http://localhost:8080',
                'http://localhost:8081',
                'http://127.0.0.1:3000',
                'http://127.0.0.1:8080',
                'http://127.0.0.1:8081',
                'https://*.ngrok-free.app',
                'https://*.ngrok.io'
            ];
    }
}
```

### 步驟 5: Flutter Web 建置配置

#### 5.1 建置 Flutter Web

```bash
# 設定 base href 並建置
flutter build web --base-href /web/

# 或使用環境變數
export FLUTTER_BASE_HREF=/web/
flutter build web
```

#### 5.2 更新 Flutter 環境配置

**檔案**: `lib/config/env_config.dart`

```dart
// 確保生產環境使用正確的 URL
static String get apiBaseUrl => get('API_BASE_URL',
    defaultValue: 'https://hero4help.demofhs.com/backend');

static String get socketUrl =>
    get('SOCKET_URL', defaultValue: 'https://hero4help.demofhs.com/backend/socket');

static String get imageBaseUrl =>
    get('IMAGE_BASE_URL', defaultValue: 'https://hero4help.demofhs.com');
```

---

## 🔧 部署順序

### 1. 準備階段
- [ ] 確認 Socket 方案選擇
- [ ] 確認 Admin 根路由移除
- [ ] 確認根目錄重定向目標

### 2. 環境變數更新
- [ ] 更新 `backend_cpanel.env`
- [ ] 更新 `admin_cpanel.env`
- [ ] 建立 Flutter Web 環境配置

### 3. 路由配置修改
- [ ] 移除 Admin 根路由衝突
- [ ] 更新主 `.htaccess` 配置
- [ ] 配置 Socket 代理 (如果選擇方案 A)

### 4. 服務配置更新
- [ ] 修改 Socket 伺服器端口
- [ ] 更新 CORS 配置
- [ ] 建置 Flutter Web 應用

### 5. 測試驗證
- [ ] 測試 Flutter Web 路由
- [ ] 測試 Admin 管理員後台
- [ ] 測試 Backend API 端點
- [ ] 測試 Socket 連接
- [ ] 測試圖片上傳功能

---

## ⚠️ 注意事項

### 1. Socket 方案選擇影響
- **方案 A (Apache 代理)**: 需要 cPanel 支援 mod_proxy
- **方案 B (HTTP 輪詢)**: 需要修改 Flutter 客戶端邏輯
- **方案 C (端口 8080)**: 需要確認 cPanel 是否支援

### 2. 權限設定
- 確保 `storage/` 目錄有寫入權限
- 確保 `uploads/` 目錄有寫入權限
- 確保 `bootstrap/cache/` 目錄有寫入權限

### 3. 備份建議
- 部署前備份現有配置
- 保留原始 `.htaccess` 檔案
- 保留原始環境變數檔案

---

## 🚨 需要您確認的問題

1. **Socket 方案選擇**: 您偏好哪個方案？(A/B/C)
2. **Admin 根路由**: 是否同意移除 Admin 的根路由重定向？
3. **根目錄重定向**: 根目錄 `/` 應該重定向到 `/web/` 還是 `/admin/`？
4. **cPanel 限制**: 您的 cPanel 是否支援 mod_proxy 模組？
5. **端口限制**: 您的 cPanel 是否支援自定義端口 (如 8080)？

請確認這些問題後，我將提供最終的修改指令。

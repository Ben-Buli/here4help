# Here4Help cPanel 部署指南

## 🚀 第一次部署到 cPanel public_html

### 📋 部署前準備

1. **確保 cPanel 支援**：
   - PHP 7.4+ 或 PHP 8.0+
   - Composer
   - Node.js 和 npm (用於 Socket 伺服器)
   - MySQL 資料庫

2. **上傳檔案**：
   - 解壓 `admin_deploy_*.tar.gz` 到 `public_html/admin/`
   - 解壓 `backend_deploy_*.tar.gz` 到 `public_html/backend/`
   - 解壓 `flutter_web_deploy_*.tar.gz` 到 `public_html/web/`
   - 複製 `.htaccess` 到 `public_html/.htaccess`

### 🔧 必要的依賴安裝

#### 1. Admin (Laravel) 依賴
```bash
cd public_html/admin
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

#### 2. Backend Socket 依賴
```bash
cd public_html/backend/socket
npm install --production
```

#### 3. 設置目錄權限
```bash
# 基本權限
chmod 755 public_html
chmod 644 public_html/.htaccess

# Admin 權限
chmod -R 755 public_html/admin/
chmod -R 777 public_html/admin/storage/
chmod -R 777 public_html/admin/bootstrap/cache/

# Backend 權限
chmod -R 755 public_html/backend/
chmod -R 777 public_html/backend/storage/
chmod -R 777 public_html/backend/uploads/
chmod -R 777 public_html/backend/cache/
```

### ⚙️ 環境配置

#### 1. Backend 環境配置
```bash
# 複製環境配置檔案
cp public_html/backend/.env.example public_html/backend/.env

# 編輯 backend/.env
nano public_html/backend/.env
```

**重要的環境變數**：
```env
# 資料庫配置
DB_HOST=localhost
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASS=your_database_password

# 應用程式配置
APP_URL=https://yourdomain.com
FRONTEND_URL=https://yourdomain.com/web

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_REDIRECT_URI=https://yourdomain.com/backend/api/auth/google-callback.php

# Apple OAuth
APPLE_SERVICE_ID=your_apple_service_id
APPLE_REDIRECT_URI=https://yourdomain.com/backend/api/auth/apple-callback.php
```

#### 2. Admin 環境配置
```bash
# 複製環境配置檔案
cp public_html/admin/.env.example public_html/admin/.env

# 編輯 admin/.env
nano public_html/admin/.env
```

**重要的環境變數**：
```env
# 資料庫配置
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=your_database_name
DB_USERNAME=your_database_user
DB_PASSWORD=your_database_password

# 應用程式配置
APP_NAME="Here4Help Admin"
APP_ENV=production
APP_KEY=base64:your_generated_key
APP_DEBUG=false
APP_URL=https://yourdomain.com/admin

# 快取配置
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_CONNECTION=sync
```

### 🗄️ 資料庫設置

#### 1. 創建資料庫
在 cPanel 中創建 MySQL 資料庫和用戶

#### 2. 導入資料庫結構
```bash
# 如果有 SQL 檔案
mysql -u your_database_user -p your_database_name < database_structure.sql
```

#### 3. 執行 Laravel 遷移 (如果需要)
```bash
cd public_html/admin
php artisan migrate --force
```

#### 4. 部署後常用指令 (cPanel)
```bash
cd public_html/admin
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
```

> 如需重新產生 APP_KEY：`php artisan key:generate --force`

### 🔗 管理端 (Laravel) API 路由

> 以下路由供 admin 前端使用（均在 `admin/routes/api.php`）  
> 權限由 middleware `admin:*` 控制

- `GET /api/admin/tasks`：任務列表
- `GET /api/admin/tasks/{id}`：任務詳情
- `GET /api/admin/tasks/statuses`：任務狀態列表（支援 `?active=1/0`）
- `PATCH /api/admin/tasks/{id}/status`：更新任務狀態
- `POST /api/admin/tasks/{taskId}/moderate`：管理員直接處理任務

### 🔄 啟動 Socket 伺服器

#### 方法 1: 使用 PM2 (推薦)
```bash
# 安裝 PM2
npm install -g pm2

# 啟動 Socket 伺服器
cd public_html/backend/socket
pm2 start server.js --name "here4help-socket"

# 設置開機自啟
pm2 startup
pm2 save
```

#### 方法 2: 使用 nohup
```bash
cd public_html/backend/socket
nohup node server.js > server.log 2>&1 &
```

### 🧪 測試部署

#### 1. 測試 API
```bash
curl https://yourdomain.com/backend/api/ping.php
```

#### 2. 測試 Admin
訪問：`https://yourdomain.com/admin/`

#### 3. 測試 Flutter Web
訪問：`https://yourdomain.com/web/`

### 🔒 SSL 憑證設置

1. 在 cPanel 中啟用 SSL 憑證
2. 強制 HTTPS 重定向
3. 更新 `.htaccess` 中的 CORS 設定

### 📊 監控和維護

#### 1. 日誌監控
```bash
# 查看 PHP 錯誤日誌
tail -f /tmp/php_errors.log

# 查看 Socket 伺服器日誌
tail -f public_html/backend/socket/server.log

# 查看 Laravel 日誌
tail -f public_html/admin/storage/logs/laravel.log
```

#### 2. 定期維護
```bash
# 清除 Laravel 快取
cd public_html/admin
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# 重新優化
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### 🚨 常見問題

#### 1. 權限問題
```bash
# 重新設置權限
find public_html -type d -exec chmod 755 {} \;
find public_html -type f -exec chmod 644 {} \;
chmod -R 777 public_html/admin/storage/
chmod -R 777 public_html/backend/storage/
chmod -R 777 public_html/backend/uploads/
```

#### 2. Composer 記憶體不足
```bash
# 增加記憶體限制
php -d memory_limit=512M /usr/local/bin/composer install
```

#### 3. Node.js 版本問題
```bash
# 檢查 Node.js 版本
node --version

# 如果版本過舊，聯繫主機提供商升級
```

### 📞 支援

如果遇到問題，請檢查：
1. 錯誤日誌
2. 權限設置
3. 環境變數配置
4. 資料庫連接
5. SSL 憑證狀態

---

**注意**：這個指南假設你已經有基本的 cPanel 和 Linux 命令列知識。如果不確定某個步驟，請聯繫你的主機提供商或系統管理員。

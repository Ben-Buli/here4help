# cPanel 上架指南

## 📋 概述

本指南將幫助您將 Here4Help 專案的後端、資料庫和圖片上傳機制部署到 cPanel 環境。

## 🎯 部署目標

1. **後端 API 部署**：將 PHP 後端程式碼部署到 cPanel
2. **資料庫遷移**：將本地 MySQL 資料庫遷移到 cPanel MySQL
3. **圖片上傳機制**：配置圖片儲存和存取機制
4. **SSL 憑證配置**：設定 HTTPS 安全連線
5. **域名和 DNS 配置**：設定域名指向和 DNS 記錄

## 🏗️ 部署架構

```
cPanel 環境
├── public_html/                    # 網站根目錄
│   ├── api/                       # API 端點
│   ├── uploads/                   # 圖片上傳目錄
│   ├── .htaccess                  # URL 重寫規則
│   └── index.php                  # 入口檔案
├── private/                       # 私有目錄
│   ├── config/                    # 配置檔案
│   ├── database/                  # 資料庫腳本
│   └── logs/                      # 日誌檔案
└── database/                      # MySQL 資料庫
```

## 📁 檔案結構準備

### 1. 後端程式碼結構

```
backend/
├── api/                          # API 端點
│   ├── auth/                     # 認證相關 API
│   ├── tasks/                    # 任務相關 API
│   ├── chat/                     # 聊天相關 API
│   └── wallet/                   # 錢包相關 API
├── config/                       # 配置檔案
│   ├── database.php              # 資料庫配置
│   ├── production.php            # 生產環境配置
│   └── security.php              # 安全配置
├── database/                     # 資料庫腳本
│   ├── migrations/               # 遷移腳本
│   └── seeds/                    # 種子資料
├── uploads/                      # 上傳檔案
│   ├── avatars/                  # 頭像檔案
│   ├── tasks/                    # 任務圖片
│   └── documents/                # 文件檔案
├── utils/                        # 工具類別
├── scripts/                      # 腳本檔案
└── .htaccess                     # URL 重寫規則
```

### 2. 配置檔案範例

#### database.php
```php
<?php
// 生產環境資料庫配置
return [
    'host' => $_ENV['DB_HOST'] ?? 'localhost',
    'database' => $_ENV['DB_NAME'] ?? 'your_database_name',
    'username' => $_ENV['DB_USER'] ?? 'your_username',
    'password' => $_ENV['DB_PASS'] ?? 'your_password',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
];
?>
```

#### production.php
```php
<?php
// 生產環境配置
return [
    'debug' => false,
    'log_errors' => true,
    'error_reporting' => E_ALL,
    'upload_path' => '/home/username/public_html/uploads/',
    'max_upload_size' => 10 * 1024 * 1024, // 10MB
    'allowed_image_types' => ['jpg', 'jpeg', 'png', 'gif'],
];
?>
```

## 🗄️ 資料庫遷移步驟

### 1. 本地資料庫備份

```bash
# 備份本地資料庫
mysqldump -u root -p here4help > here4help_backup.sql

# 備份結構和資料
mysqldump -u root -p --routines --triggers here4help > here4help_full_backup.sql
```

### 2. cPanel 資料庫建立

1. **登入 cPanel**
   - 進入 cPanel 控制台
   - 找到 "MySQL 資料庫" 選項

2. **建立資料庫**
   - 建立新資料庫：`your_username_here4help`
   - 建立資料庫用戶：`your_username_here4help_user`
   - 設定密碼並記住

3. **設定權限**
   - 將用戶添加到資料庫
   - 設定所有權限（ALL PRIVILEGES）

### 3. 資料庫遷移

```bash
# 方法1：使用 phpMyAdmin
# 1. 登入 cPanel phpMyAdmin
# 2. 選擇目標資料庫
# 3. 點擊 "匯入"
# 4. 選擇本地備份檔案
# 5. 點擊 "執行"

# 方法2：使用命令行（如果有 SSH 存取）
mysql -u your_username_here4help_user -p your_username_here4help < here4help_backup.sql
```

## 📤 檔案上傳步驟

### 1. 準備上傳檔案

```bash
# 建立部署包
tar -czf here4help_backend.tar.gz backend/

# 或使用 ZIP
zip -r here4help_backend.zip backend/
```

### 2. 上傳到 cPanel

#### 方法1：使用 File Manager
1. 登入 cPanel
2. 開啟 File Manager
3. 導航到 `public_html` 目錄
4. 上傳並解壓縮檔案

#### 方法2：使用 FTP
```bash
# 使用 FTP 客戶端
ftp your-domain.com
# 輸入用戶名和密碼
# 上傳檔案到 public_html 目錄
```

### 3. 設定檔案權限

```bash
# 設定目錄權限
chmod 755 public_html/
chmod 755 public_html/uploads/
chmod 755 public_html/uploads/avatars/
chmod 755 public_html/uploads/tasks/

# 設定檔案權限
chmod 644 public_html/.htaccess
chmod 644 public_html/config/*.php
```

## 🔧 配置檔案設定

### 1. .htaccess 配置

```apache
# 啟用 URL 重寫
RewriteEngine On

# 強制 HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# API 路由重寫
RewriteRule ^api/(.*)$ api/$1 [QSA,L]

# 圖片快取
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 month"
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
</IfModule>

# 安全性標頭
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
</IfModule>
```

### 2. 環境變數設定

在 cPanel 的 "環境變數" 中設定：

```bash
DB_HOST=localhost
DB_NAME=your_username_here4help
DB_USER=your_username_here4help_user
DB_PASS=your_database_password
APP_ENV=production
APP_DEBUG=false
```

## 🔒 SSL 憑證配置

### 1. 自動 SSL 憑證

1. 在 cPanel 中找到 "SSL/TLS 狀態"
2. 選擇您的域名
3. 點擊 "安裝" 或 "管理"
4. 選擇 "自動 SSL 憑證"
5. 點擊 "安裝憑證"

### 2. 強制 HTTPS

在 `.htaccess` 中添加：

```apache
# 強制 HTTPS
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

## 📊 資料庫遷移腳本

### 1. 遷移腳本範例

```php
<?php
// migrate.php
require_once 'config/database.php';

class DatabaseMigration {
    private $pdo;
    
    public function __construct() {
        $this->pdo = new PDO(
            "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME,
            DB_USER,
            DB_PASS
        );
    }
    
    public function runMigrations() {
        $migrations = [
            '001_create_users_table.sql',
            '002_create_tasks_table.sql',
            '003_create_chat_rooms_table.sql',
            // 添加更多遷移檔案
        ];
        
        foreach ($migrations as $migration) {
            $this->executeMigration($migration);
        }
    }
    
    private function executeMigration($filename) {
        $sql = file_get_contents("database/migrations/$filename");
        $this->pdo->exec($sql);
        echo "執行遷移: $filename\n";
    }
}

// 執行遷移
$migration = new DatabaseMigration();
$migration->runMigrations();
?>
```

### 2. 備份腳本

```php
<?php
// backup.php
$backup_dir = 'backups/';
$filename = 'backup_' . date('Y-m-d_H-i-s') . '.sql';

// 建立備份目錄
if (!is_dir($backup_dir)) {
    mkdir($backup_dir, 0755, true);
}

// 執行備份
$command = "mysqldump -u " . DB_USER . " -p" . DB_PASS . " " . DB_NAME . " > " . $backup_dir . $filename;
exec($command);

echo "備份完成: $filename\n";
?>
```

## 🚀 部署檢查清單

### 部署前檢查
- [ ] 本地測試通過
- [ ] 資料庫備份完成
- [ ] 配置檔案準備完成
- [ ] SSL 憑證申請完成
- [ ] 域名 DNS 設定完成

### 部署後檢查
- [ ] API 端點可正常存取
- [ ] 資料庫連線正常
- [ ] 圖片上傳功能正常
- [ ] SSL 憑證生效
- [ ] 錯誤日誌正常記錄
- [ ] 效能測試通過

## 🔍 故障排除

### 常見問題

1. **資料庫連線失敗**
   - 檢查資料庫配置
   - 確認用戶權限
   - 檢查防火牆設定

2. **圖片上傳失敗**
   - 檢查目錄權限
   - 確認上傳路徑
   - 檢查檔案大小限制

3. **SSL 憑證問題**
   - 確認域名設定
   - 檢查 DNS 記錄
   - 等待憑證生效

4. **API 路由問題**
   - 檢查 .htaccess 配置
   - 確認 URL 重寫啟用
   - 檢查檔案路徑

## 📞 支援聯絡

如果在部署過程中遇到問題，請：

1. 檢查錯誤日誌
2. 確認配置設定
3. 聯絡技術支援
4. 參考 cPanel 官方文檔

## 📝 更新記錄

- **2025-08-08**: 初始版本建立
- **2025-08-08**: 添加 SSL 配置說明
- **2025-08-08**: 完善故障排除指南 
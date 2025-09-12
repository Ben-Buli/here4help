# 環境配置設定指南

## 📋 **概述**

本指南說明如何設定 Here4Help 專案的環境配置，確保敏感資訊不會被提交到 Git 倉庫。

## 🔒 **安全原則**

1. **永遠不要將包含實際憑證的檔案提交到 Git**
2. **使用 .env 檔案來儲存敏感資訊**
3. **定期更新 OAuth 憑證和密鑰**
4. **在團隊中安全地分享憑證資訊**

## 📁 **檔案結構**

```
backend/config/
├── env.example          # 環境配置範例檔案（可提交到 Git）
├── env.local           # 本地開發環境配置（不提交到 Git）
├── env.development     # 開發環境配置（不提交到 Git）
├── env.production      # 生產環境配置（不提交到 Git）
└── env_loader.php      # 環境配置載入器
```

## 🚀 **設定步驟**

### **步驟 1：複製範例檔案**

```bash
# 複製範例檔案
cp backend/config/env.example backend/config/env.local

# 或者根據環境複製
cp backend/config/env.example backend/config/env.development
cp backend/config/env.example backend/config/env.production
```

### **步驟 2：填入實際配置值**

編輯對應的環境檔案，填入實際的配置值：

```bash
# 編輯本地開發環境配置
nano backend/config/env.local

# 或者使用其他編輯器
code backend/config/env.local
```

### **步驟 3：填入必要的配置值**

#### **基本配置**
```bash
APP_ENV=development
APP_DEBUG=true
APP_URL=http://localhost:8888
```

#### **資料庫配置**
```bash
DB_HOST=localhost
DB_PORT=3306
DB_NAME=here4help
DB_USERNAME=your_actual_username
DB_PASSWORD=your_actual_password
```

#### **JWT 配置**
```bash
JWT_SECRET=your_actual_jwt_secret_key_minimum_32_characters
JWT_EXPIRE_HOURS=168
```

#### **Google OAuth 配置**
```bash
GOOGLE_CLIENT_ID_WEB=your_google_client_id_web.apps.googleusercontent.com
GOOGLE_CLIENT_ID_ANDROID=your_google_client_id_android.apps.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=your_google_client_id_ios.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

#### **Facebook OAuth 配置**
```bash
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_CLIENT_TOKEN=your_facebook_client_token
```

#### **Apple Sign-In 配置**
```bash
APPLE_TEAM_ID=your_apple_team_id
APPLE_KEY_ID=your_apple_key_id
APPLE_SERVICE_ID=your_apple_service_id_here
APPLE_BUNDLE_ID=com.example.here4help
```

## 🔧 **環境配置載入器**

專案使用 `env_loader.php` 來自動載入環境配置：

```php
<?php
require_once 'config/env_loader.php';

// 環境變數會自動載入
$appEnv = $_ENV['APP_ENV'] ?? 'development';
$dbHost = $_ENV['DB_HOST'] ?? 'localhost';
?>
```

## 🧪 **測試環境配置**

### **方法 1：使用測試腳本**
```bash
# 訪問測試頁面
http://localhost:8888/here4help/backend/config/test_env_loader.php
```

### **方法 2：檢查 PHP 資訊**
```php
<?php
// 在任意 PHP 檔案中
var_dump($_ENV);
?>
```

## ⚠️ **常見問題**

### **問題 1：環境變數無法載入**
- 檢查檔案路徑是否正確
- 確認檔案權限
- 檢查 PHP 是否啟用 `getenv` 函數

### **問題 2：OAuth 登入失敗**
- 檢查 OAuth 憑證是否正確
- 確認回調 URL 設定
- 檢查 ngrok URL 是否有效

### **問題 3：資料庫連線失敗**
- 檢查資料庫服務是否運行
- 確認資料庫憑證
- 檢查防火牆設定

## 🔄 **更新憑證**

### **Google OAuth**
1. 訪問 [Google Cloud Console](https://console.cloud.google.com/)
2. 更新 OAuth 2.0 憑證
3. 更新環境檔案中的對應值

### **Facebook OAuth**
1. 訪問 [Facebook Developers](https://developers.facebook.com/)
2. 更新應用程式設定
3. 更新環境檔案中的對應值

### **Apple Sign-In**
1. 訪問 [Apple Developer](https://developer.apple.com/)
2. 更新 Sign-In 憑證
3. 更新環境檔案中的對應值

## 📞 **支援**

如有問題，請聯繫開發團隊或查看專案文檔。

---

**重要提醒**：定期檢查和更新憑證，確保系統安全性！

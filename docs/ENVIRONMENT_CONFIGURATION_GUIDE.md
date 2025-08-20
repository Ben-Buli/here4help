# 🌍 Here4Help 環境配置指南

## 📋 概述

本文檔說明 Here4Help 專案中前端和後端的環境配置分離策略，確保敏感資訊的安全性。

## 🔐 配置分離原則

### **前端配置（Flutter）**
- **位置**：`assets/app_env/`
- **內容**：公開配置，可提交到版本控制
- **用途**：API 端點、功能開關、公開憑證 ID

### **後端配置（PHP/Node.js）**
- **位置**：`backend/.env`
- **內容**：敏感資訊，不提交到版本控制
- **用途**：資料庫密碼、JWT 密鑰、第三方登入密鑰

## 📁 檔案結構

```
here4help/
├── assets/app_env/                    # 前端配置
│   ├── development.json               # 開發環境（公開）
│   ├── production.json                # 生產環境（公開）
│   ├── development.example.json       # 開發環境範例
│   └── production.example.json        # 生產環境範例
├── backend/                           # 後端配置
│   ├── .env                          # 環境變數（敏感）
│   ├── config/env.example            # 環境變數範例
│   └── setup_env.php                 # 環境配置設定腳本
└── .gitignore                        # 版本控制忽略規則
```

## 🔧 前端配置（Flutter）

### **配置檔案格式**
```json
{
  "environment": "development",
  "public": {
    "api_base_url": "http://localhost:8888/here4help",
    "socket_url": "http://localhost:3001",
    "image_base_url": "http://localhost:8888/here4help",
    "google_client_id": "YOUR_GOOGLE_CLIENT_ID",
    "facebook_app_id": "YOUR_FACEBOOK_APP_ID",
    "apple_service_id": "com.example.here4help.login"
  },
  "app": {
    "debug_mode": true,
    "log_level": "debug",
    "features": {
      "third_party_auth": true,
      "chat": true,
      "tasks": true,
      "payments": false
    }
  }
}
```

### **載入方式**
```dart
// 初始化配置
await EnvironmentConfig.initialize();

// 獲取配置值
final apiUrl = EnvironmentConfig.apiBaseUrl;
final googleClientId = EnvironmentConfig.googleClientId;
```

## 🔒 後端配置（PHP/Node.js）

### **環境變數檔案 (.env)**
```bash
# JWT 配置
JWT_SECRET=your_secure_jwt_secret_here
JWT_EXPIRY=604800

# 資料庫配置
DB_HOST=localhost
DB_PORT=8889
DB_NAME=your_database_name
DB_USERNAME=your_username
DB_PASSWORD=your_password

# Google OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_ANDROID_CLIENT_ID=your_android_client_id
GOOGLE_IOS_CLIENT_ID=your_ios_client_id

# Facebook OAuth
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_CLIENT_TOKEN=your_facebook_client_token

# Apple OAuth
APPLE_SERVICE_ID=your_apple_service_id
APPLE_TEAM_ID=your_apple_team_id
APPLE_KEY_ID=your_apple_key_id
APPLE_PRIVATE_KEY=your_apple_private_key
```

### **載入方式**
```php
// PHP 環境變數載入器
require_once 'config/env_loader.php';
EnvLoader::load();

// 獲取環境變數
$jwtSecret = EnvLoader::get('JWT_SECRET');
$dbHost = EnvLoader::get('DB_HOST');
```

```javascript
// Node.js 環境變數載入
require('dotenv').config({ path: '../../.env' });

const jwtSecret = process.env.JWT_SECRET;
const dbHost = process.env.DB_HOST;
```

## 🚀 快速設定

### **1. 設定後端環境**
```bash
cd backend
php setup_env.php
```

### **2. 檢查配置**
```bash
php check_environment.php
php test_jwt_fix.php
```

### **3. 重新啟動服務**
```bash
# 重新啟動 Socket 伺服器
cd socket
node server.js
```

## 🔍 配置檢查清單

### **前端配置檢查**
- [ ] `assets/app_env/development.json` 存在且無敏感資訊
- [ ] `assets/app_env/production.json` 存在且無敏感資訊
- [ ] 範例檔案已更新
- [ ] Flutter 應用能正常載入配置

### **後端配置檢查**
- [ ] `backend/.env` 檔案存在
- [ ] JWT_SECRET 已設定
- [ ] 資料庫連線正常
- [ ] 第三方登入憑證已設定
- [ ] Socket 伺服器 JWT 驗證正常

## 🛡️ 安全性考量

### **版本控制**
- ✅ 前端配置檔案可提交（已清理敏感資訊）
- ❌ 後端 .env 檔案不提交
- ✅ 範例檔案提供配置模板

### **敏感資訊保護**
- 所有密鑰、密碼、私鑰移至後端 .env
- 前端只保留公開的 Client ID
- JWT 密鑰只在後端使用

### **環境分離**
- 開發環境：localhost 配置
- 生產環境：實際網域配置
- 測試環境：獨立配置

## 🔧 故障排除

### **常見問題**

#### **1. JWT Token 驗證失敗**
```bash
# 檢查 JWT_SECRET 是否設定
php check_environment.php

# 測試 JWT 功能
php test_jwt_fix.php
```

#### **2. 環境變數未載入**
```bash
# 重新設定環境
php setup_env.php

# 檢查 .env 檔案
cat .env | grep JWT_SECRET
```

#### **3. 前端配置載入失敗**
```bash
# 檢查 Flutter 資產配置
flutter clean
flutter pub get

# 檢查配置檔案格式
cat assets/app_env/development.json | jq .
```

## 📝 更新記錄

- **2025-01-19**: 初始版本，環境配置分離完成
- **2025-01-19**: 前端敏感資訊清理完成
- **2025-01-19**: 後端 .env 配置完成
- **2025-01-19**: JWT 功能測試通過

## 📞 支援

如有配置問題，請聯繫開發團隊或參考故障排除章節。


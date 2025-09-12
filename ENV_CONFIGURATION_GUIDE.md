# Here4Help 環境配置指南

本指南說明如何使用 `.env` 文件來管理 Here4Help 專案的環境配置，包括 Flutter App、Backend PHP 和 Admin Laravel Web。

## 專案架構概述

```
here4help/
├── 📱 Flutter App (主應用程式)
├── 🔧 backend/ (PHP API 後端)
└── 🖥️ admin/ (Laravel Admin 面板)
```

## 🔐 敏感資訊管理原則

根據專案慣例 [[memory:8572754]]，敏感憑證應該通過環境變數 (.env) 注入，而非硬編碼在源碼文件中。

### 敏感資訊分類
- **🔒 僅後端**: 資料庫密碼、JWT Secret、OAuth Client Secret
- **🔓 前端可用**: OAuth Client ID、API URL、功能開關

## 📱 Flutter App 環境配置

### 新的 .env 配置系統

Flutter App 現在使用 `flutter_dotenv` 套件來管理環境變數，替代原有的 JSON 配置文件。

#### 1. 配置文件結構

```
根目錄/
├── env.example        # 範本文件
├── env.development    # 開發環境
├── env.staging       # 測試環境
└── env.production    # 正式環境
```

#### 2. 使用方式

```dart
// 在 main.dart 中載入
import 'package:here4help/config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 載入環境配置
  await EnvConfig.load();
  
  runApp(MyApp());
}

// 在程式中使用
String apiUrl = EnvConfig.apiBaseUrl;
String socketUrl = EnvConfig.socketUrl;
bool enableChat = EnvConfig.enableChat;
```

#### 3. 環境變數範例

```bash
# App Environment
APP_ENVIRONMENT=development
APP_DEBUG=true

# API Configuration
API_ORIGIN=http://localhost:8888
API_BASE_URL=http://localhost:8888/here4help/backend
SOCKET_URL=http://127.0.0.1:3001

# OAuth (僅 Client ID，Secret 存放在後端)
GOOGLE_CLIENT_ID=your_client_id_here
FACEBOOK_APP_ID=your_app_id_here

# Feature Flags
FEATURE_THIRD_PARTY_AUTH=true
FEATURE_CHAT=true
FEATURE_TASKS=true
FEATURE_PAYMENTS=false
```

### 建置不同環境

```bash
# 開發環境（一般）
flutter run --dart-define=ENVIRONMENT=development

# iOS 模擬器
flutter run -d iphone --dart-define=ENVIRONMENT=ios_simulator

# Android 模擬器
flutter run -d android --dart-define=ENVIRONMENT=android_emulator

# Web 開發
flutter run -d chrome --dart-define=ENVIRONMENT=development

# 測試環境  
flutter run --dart-define=ENVIRONMENT=staging

# TestFlight 建置
flutter build ios --dart-define=ENVIRONMENT=testflight

# 正式環境
flutter build apk --release --dart-define=ENVIRONMENT=production
```

## 🔧 Backend PHP 環境配置

Backend 使用自建的 `EnvLoader` 類別來管理環境變數。

### 配置文件位置

```
backend/
├── config/
│   ├── env.example     # 範本文件
│   ├── env_loader.php  # 環境載入器
│   └── database.php    # 資料庫配置
└── .env               # 實際配置（不提交到版控）
```

### 重要環境變數

```bash
# 應用環境
APP_ENV=development
APP_DEBUG=true

# 資料庫配置（敏感資訊）
DB_HOST=localhost
DB_PORT=8889
DB_NAME=hero4helpdemofhs_hero4help
DB_USERNAME=root
DB_PASSWORD=root

# JWT 配置（高度敏感）
JWT_SECRET=your_very_secure_secret_key_here
JWT_EXPIRY=604800

# OAuth 配置（包含 Secret）
GOOGLE_CLIENT_ID=your_client_id
GOOGLE_CLIENT_SECRET=your_client_secret
FACEBOOK_APP_ID=your_app_id
FACEBOOK_APP_SECRET=your_app_secret
```

### 使用方式

```php
<?php
require_once 'config/env_loader.php';

// 載入環境變數
EnvLoader::load();

// 使用環境變數
$apiUrl = EnvLoader::get('APP_URL');
$dbConfig = EnvLoader::getDatabaseConfig();
$isProduction = EnvLoader::isProduction();
```

## 🖥️ Admin Laravel 環境配置

Admin 使用標準的 Laravel .env 配置。

### 配置文件位置

```
admin/
├── env.example        # Laravel 範本
├── .env              # 實際配置（不提交到版控）
└── frontend/
    └── ENV_README.md  # 前端環境說明
```

### Laravel Backend 環境變數

```bash
# Laravel 應用設定
APP_NAME="Here4Help Admin"
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8000

# 資料庫（與 Backend 共用）
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=8889
DB_DATABASE=hero4helpdemofhs_hero4help

# Admin 特定配置
ADMIN_SESSION_TIMEOUT=3600
BACKEND_API_URL=http://localhost:8888/here4help/backend/api
SOCKET_SERVER_URL=http://localhost:3001
```

### Vue Frontend 環境變數

```bash
# Vite 環境變數
VITE_APP_TITLE="Here4Help Admin Dashboard"
VITE_API_BASE_URL=http://localhost:8888/here4help/backend/api
VITE_SOCKET_URL=http://localhost:3001
VITE_DEBUG_MODE=true

# 功能開關
VITE_ENABLE_CHAT=true
VITE_ENABLE_DISPUTES=true
VITE_ENABLE_SUPPORT=true
```

## 🚀 環境部署指南

### 1. 開發環境設置

```bash
# 1. 複製範本文件
cp env.example env.development
cp backend/config/env.example backend/.env
cp admin/env.example admin/.env

# 2. 設定開發環境變數
# 編輯各個 .env 文件，填入開發環境資訊

# 3. Flutter 依賴安裝
flutter pub get

# 4. 執行開發環境
flutter run --dart-define=ENVIRONMENT=development
```

### 2. 測試環境部署

```bash
# 設定測試環境變數
cp env.example env.staging

# 編輯 env.staging，設定測試伺服器資訊
# API_BASE_URL=https://staging.yourdomain.com/backend
# SOCKET_URL=https://staging.yourdomain.com:3001

# 建置測試版本
flutter build apk --dart-define=ENVIRONMENT=staging
```

### 3. 正式環境部署

```bash
# 設定正式環境變數
cp env.example env.production

# 編輯 env.production，設定正式伺服器資訊
# APP_ENVIRONMENT=production
# APP_DEBUG=false
# API_BASE_URL=https://yourdomain.com/backend

# 建置正式版本
flutter build apk --dart-define=ENVIRONMENT=production --release
```

## 🔒 安全性最佳實踐

### 1. 敏感資訊隔離
- ✅ 資料庫密碼、JWT Secret：僅存放在後端 .env
- ✅ OAuth Client Secret：僅存放在後端 .env
- ✅ API URL、Client ID：可存放在前端環境變數

### 2. 版本控制
```gitignore
# 加入 .gitignore
.env
.env.local
.env.development.local
.env.staging.local
.env.production.local
backend/.env
admin/.env
admin/frontend/.env.local
```

### 3. 環境變數驗證

```dart
// Flutter 環境驗證
if (EnvConfig.googleClientId.isEmpty) {
  throw Exception('Google Client ID not configured');
}
```

```php
// PHP 環境驗證
if (empty(EnvLoader::get('JWT_SECRET'))) {
    throw new Exception('JWT Secret not configured');
}
```

## 🛠️ 從 JSON 配置遷移

### 舊的配置方式（即將淘汰）
```json
// assets/app_env/web.json
{
  "public": {
    "google_client_id": "硬編碼的Client ID",
    "api_base_url": "http://localhost:8888/here4help/backend"
  }
}
```

### 新的配置方式
```bash
# env.development
GOOGLE_CLIENT_ID=your_client_id_here
API_BASE_URL=http://localhost:8888/here4help/backend
```

### 遷移步驟
1. ✅ 將 JSON 配置中的值移到對應的 .env 文件
2. ✅ 更新程式碼使用 `EnvConfig` 類別
3. ⚠️ 移除敏感資訊從 JSON 文件
4. ⚠️ 更新 CI/CD 流程使用環境變數

## 📋 環境配置檢查清單

### Flutter App
- [ ] `env.development` 配置完整
- [ ] `env.production` 配置完整
- [ ] 移除 JSON 配置中的敏感資訊
- [ ] 更新程式碼使用 `EnvConfig`

### Backend PHP
- [ ] `.env` 檔案配置完整
- [ ] JWT Secret 設定（至少32字元）
- [ ] 資料庫連接正常
- [ ] OAuth 配置完整

### Admin Laravel
- [ ] Laravel `.env` 配置完整
- [ ] 前端 Vite 環境變數設定
- [ ] API 連接正常
- [ ] Socket 連接正常

## 🆘 常見問題

### Q: Flutter 無法載入環境配置？
**A**: 檢查 `pubspec.yaml` 是否包含環境配置文件：
```yaml
flutter:
  assets:
    - env.development
    - env.staging
    - env.production
```

### Q: Backend 無法連接資料庫？
**A**: 檢查 `.env` 文件中的資料庫配置，確保與 MAMP/XAMPP 設定一致。

### Q: Admin 前端 API 請求失敗？
**A**: 檢查 CORS 設定和 `VITE_API_BASE_URL` 是否正確。

### Q: OAuth 登入失敗？
**A**: 確認：
1. Client ID 在前端正確設定
2. Client Secret 在後端正確設定
3. Redirect URI 與 OAuth 提供商設定一致

---

🔄 **定期更新提醒**: 當加入新功能或更改服務 URL 時，記得更新對應的環境配置文件和本文檔。

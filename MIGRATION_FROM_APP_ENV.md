# 從 app_env/*.json 遷移到 .env 系統指南

## 📋 遷移概述

我們正在將 `assets/app_env/*.json` 配置文件遷移到統一的 `.env` 環境管理系統，以提供更好的安全性和開發體驗。

## 🔍 現有 app_env 文件分析

### 已遷移的配置：

| JSON 文件 | 新的 .env 文件 | 狀態 |
|-----------|----------------|------|
| `development.json` | `env.development` | ✅ 已遷移 |
| `production.json` | `env.production` | ✅ 已遷移 |
| `testflight.json` | `env.testflight` | ✅ 已遷移 |
| `android_emulator.json` | `env.android_emulator` | ✅ 已遷移 |
| `ios_simulator.json` | `env.ios_simulator` | ✅ 已遷移 |
| `web.json` | `env.development` | ✅ 已整合 |

### 配置內容對應：

```json
// 舊的 app_env/production.json
{
  "environment": "production",
  "public": {
    "api_origin": "https://hero4help.demofhs.com",
    "api_base_url": "https://hero4help.demofhs.com",
    "socket_url": "https://hero4help.demofhs.com:3001",
    "google_client_id": "102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com"
  }
}
```

⬇️ 遷移到

```bash
# 新的 env.production
APP_ENVIRONMENT=production
API_ORIGIN=https://hero4help.demofhs.com
API_BASE_URL=https://hero4help.demofhs.com/here4help/backend
SOCKET_URL=https://hero4help.demofhs.com:3001
GOOGLE_CLIENT_ID=102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com
```

## 🛠️ 程式碼更新

### Flutter 程式碼變更：

#### 舊的方式（environment_config.dart）：
```dart
// 舊的方式 - 讀取 JSON 文件
final config = await loadJsonConfig();
String apiUrl = config['public']['api_base_url'];
```

#### 新的方式（env_config.dart）：
```dart
// 新的方式 - 使用 EnvConfig
await EnvConfig.load();
String apiUrl = EnvConfig.apiBaseUrl;
bool enableChat = EnvConfig.enableChat;
```

## 🚀 建置命令更新

### 開發環境：
```bash
# 原本
flutter run

# 現在
flutter run --dart-define=ENVIRONMENT=development
```

### 不同環境建置：
```bash
# iOS 模擬器
flutter run --dart-define=ENVIRONMENT=ios_simulator

# Android 模擬器  
flutter run --dart-define=ENVIRONMENT=android_emulator

# TestFlight
flutter build ios --dart-define=ENVIRONMENT=testflight

# 正式發布
flutter build apk --release --dart-define=ENVIRONMENT=production
```

## 🔒 安全性改善

### 敏感資訊處理：

1. **已移除的敏感資訊**：
   - ❌ Google Client ID 不再硬編碼在 JSON 中
   - ❌ Facebook App ID 不再暴露在 assets 中
   - ❌ API URL 不再包含在應用程式包中

2. **新的安全措施**：
   - ✅ 所有敏感資訊通過 .env 文件管理
   - ✅ 不同環境完全隔離配置
   - ✅ 開發和正式環境憑證分離

## 📂 文件清理

### 可以安全移除的文件：

準備移除（但暫時保留作為參考）：
- `assets/app_env/development.json` 
- `assets/app_env/production.json`
- `assets/app_env/testflight.json`
- `assets/app_env/android_emulator.json`
- `assets/app_env/ios_simulator.json`
- `assets/app_env/web.json`

### 暫時保留的文件：

- `lib/config/environment_config.dart` - 舊的配置讀取器（向後相容）
- `assets/app_env/facebook_config.json` - 特殊用途（需要進一步分析）

## ⚠️ 遷移注意事項

### 1. 網路 IP 配置（Android Emulator）
```bash
# Android Emulator 需要使用實際的網路 IP
# 需要將 192.168.1.103 替換為您的實際 IP 地址

# 查找您的 IP 地址：
# macOS/Linux: ifconfig | grep inet
# Windows: ipconfig
```

### 2. OAuth 重定向 URI
確保 OAuth 提供商（Google、Facebook）的重定向 URI 配置與新的環境 URL 一致。

### 3. 後端配置同步
確保後端 `.env` 配置與前端環境配置保持一致，特別是：
- `SOCKET_SERVER_URL`
- `ALLOWED_ORIGINS`
- OAuth redirect URIs

## 📱 平台特定配置

### iOS 配置：
```bash
# iOS 可以使用 localhost/127.0.0.1
ENVIRONMENT=ios_simulator flutter run -d iphone
```

### Android 配置：
```bash
# Android 需要實際網路 IP
ENVIRONMENT=android_emulator flutter run -d android
```

### Web 配置：
```bash
# Web 使用開發環境配置
ENVIRONMENT=development flutter run -d chrome
```

## 🧪 測試遷移

### 測試步驟：

1. **載入環境配置**：
   ```dart
   await EnvConfig.load();
   EnvConfig.printConfig(); // 只在 debug 模式顯示
   ```

2. **驗證 API 連接**：
   ```dart
   String apiUrl = EnvConfig.getApiUrl('/test');
   // 確保可以正常連接 API
   ```

3. **測試 Socket 連接**：
   ```dart
   String socketUrl = EnvConfig.socketUrl;
   // 確保 WebSocket 連接正常
   ```

4. **驗證 OAuth 流程**：
   - 測試 Google 登入
   - 測試 Facebook 登入
   - 確保重定向正常

## 📋 遷移檢查清單

### Flutter App:
- [ ] 更新程式碼使用 `EnvConfig`
- [ ] 測試所有環境配置載入正常
- [ ] 確認 API 連接在所有環境正常
- [ ] 測試 Socket 連接功能
- [ ] 驗證 OAuth 登入流程

### 後端配置:
- [ ] 更新 PHP 代碼移除硬編碼 URL
- [ ] 確認 Socket 服務器配置正確
- [ ] 測試跨域（CORS）設定
- [ ] 驗證資料庫連接配置

### 部署配置:
- [ ] 更新 CI/CD 腳本使用新的環境變數
- [ ] 設定正式環境的 .env 文件
- [ ] 測試不同環境建置流程
- [ ] 確認 OAuth 重定向 URI 設定

## 🔄 回滾計畫

如果遇到問題，可以暫時回滾到舊的 JSON 配置系統：

1. 恢復使用 `environment_config.dart`
2. 在 `main.dart` 中載入舊的配置系統
3. 確保 JSON 文件完整性
4. 測試功能正常後再重新嘗試遷移

---

**遷移完成後的好處**：
- 🔒 更好的安全性（敏感資訊隔離）
- 🛠️ 統一的環境管理方式
- 🚀 更靈活的部署配置
- 📊 更好的開發體驗

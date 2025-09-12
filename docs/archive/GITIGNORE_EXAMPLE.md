# 🔒 .gitignore 範例檔案 - 保護敏感資訊

## 📋 說明
此檔案列出應該加入 `.gitignore` 的敏感配置檔案，以防止敏感資訊被意外提交到版本控制系統。

## 🚨 必須保護的檔案

### Google 服務配置檔案
```
# Android Google Services
android/app/google-services.json

# iOS Google Services
ios/Runner/GoogleService-Info.plist
```

### 環境配置檔案（包含真實憑證）
```
# 包含真實憑證的環境配置
assets/app_env/development.json
assets/app_env/staging.json
assets/app_env/production.json

# 環境配置範例檔案（可以提交）
assets/app_env/*.example.json
```

### 其他敏感檔案
```
# API 金鑰和憑證
*.p12
*.p8
*.pem
*.key

# 資料庫配置
backend/config/database.php
backend/config/env.php

# 日誌檔案
*.log
logs/

# 快取檔案
.cache/
build/
```

## 🔧 建議的 .gitignore 結構

```gitignore
# Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/

# Android
android/app/google-services.json
android/app/src/main/res/values/google-services.xml
android/key.properties
android/app/debug.keystore
android/app/release.keystore

# iOS
ios/Runner/GoogleService-Info.plist
ios/Runner/GoogleService-Info-*.plist
ios/Runner/AppStoreConnect*.plist
ios/Runner/ExportOptions*.plist

# 環境配置（包含真實憑證）
assets/app_env/development.json
assets/app_env/staging.json
assets/app_env/production.json

# 後端敏感配置
backend/config/database.php
backend/config/env.php
backend/config/*.local.php

# 其他
*.log
.env
.env.local
.env.*.local
```

## 📝 環境配置管理策略

### 1. 範例檔案
創建不包含真實憑證的範例檔案：
```
assets/app_env/development.example.json
assets/app_env/staging.example.json
assets/app_env/production.example.json
```

### 2. 本地配置
開發者根據範例檔案創建本地配置：
```bash
cp assets/app_env/development.example.json assets/app_env/development.json
# 然後編輯 development.json 添加真實憑證
```

### 3. 團隊協作
- 範例檔案提交到版本控制
- 真實配置檔案保持本地
- 使用環境變數或密鑰管理服務

## 🔐 生產環境安全

### 1. 密鑰管理服務
- 使用 AWS KMS、Azure Key Vault 等服務
- 避免在程式碼中硬編碼憑證
- 實作密鑰輪換機制

### 2. CI/CD 安全
- 使用環境變數傳遞敏感資訊
- 限制部署權限
- 監控部署日誌

### 3. 監控與警報
- 監控憑證使用情況
- 設定憑證過期警報
- 追蹤異常存取

## 📚 相關資源

- [Git 官方文檔 - gitignore](https://git-scm.com/docs/gitignore)
- [Flutter 官方文檔 - 部署](https://flutter.dev/docs/deployment)
- [Google Cloud 安全最佳實踐](https://cloud.google.com/security/best-practices)
- [OWASP 安全檢查清單](https://owasp.org/www-project-mobile-security-testing-guide/)

## ⚠️ 重要提醒

1. **永遠不要提交包含真實憑證的檔案**
2. **定期檢查 .gitignore 是否正確配置**
3. **使用密鑰管理服務管理生產環境憑證**
4. **定期輪換敏感憑證**
5. **監控版本控制系統的敏感資訊洩露**

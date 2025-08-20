# 🔐 第三方登入完整配置指南

## 📋 概述
本文檔說明 Here4Help 專案中所有第三方登入功能的完整配置，包括 Google、Facebook 和 Apple Sign-In。

## 🚨 重要提醒
**⚠️ 以下配置包含真實憑證，請確保這些檔案已加入 .gitignore 並不會被提交到版本控制系統**

## 🔑 憑證配置

### 1. Google 登入配置

#### 1.1 平台特定 Client ID
- **Web**: `102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com`
- **Android**: `102744926949-u37cmuubvuvv8a1phetrih25qisk8fjo.apps.googleusercontent.com`
- **iOS**: `102744926949-951r2epiq93abijklu5te2qocpc9kqqv.apps.googleusercontent.com`

#### 1.2 Android 配置
**檔案**: `android/app/google-services.json`
```json
{
  "project_info": {
    "project_number": "102744926949",
    "project_id": "here4help-flutter-app"
  },
  "client": [
    {
      "oauth_client": [
        {
          "client_id": "102744926949-u37cmuubvuvv8a1phetrih25qisk8fjo.apps.googleusercontent.com",
          "client_type": 3
        }
      ]
    }
  ]
}
```

#### 1.3 iOS 配置
**檔案**: `ios/Runner/GoogleService-Info.plist`
```xml
<key>CLIENT_ID</key>
<string>102744926949-951r2epiq93abijklu5te2qocpc9kqqv.apps.googleusercontent.com</string>
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.102744926949-951r2epiq93abijklu5te2qocpc9kqqv</string>
```

#### 1.4 SHA1 憑證指紋
```
Debug SHA1: 83:69:3A:D1:F8:08:11:E3:5B:32:45:69:23:93:B2:00:D6:EA:3B:6F
```

### 2. Facebook 登入配置

#### 2.1 基本資訊
- **App ID**: `1037019294991326`
- **App Secret**: `5ecadfb58ab349ad150ae2cdef906489`
- **Client Token**: `0b81d2c8f405ca37d21f12b828c571cf`
- **Redirect URI**: `http://localhost:8888/auth/facebook/callback`

#### 2.2 配置檔案
**檔案**: `assets/app_env/facebook_config.json`
```json
{
  "facebook": {
    "app_id": "1037019294991326",
    "app_secret": "5ecadfb58ab349ad150ae2cdef906489",
    "client_token": "0b81d2c8f405ca37d21f12b828c571cf",
    "redirect_uri": "http://localhost:8888/auth/facebook/callback"
  }
}
```

### 3. Apple Sign-In 配置

#### 3.1 基本資訊
- **Key Name**: `Here4Help Sign in with Apple Key`
- **Key ID**: `2F963AR7G6`
- **Services**: `Sign in with Apple`
- **Services ID**: `com.example.here4help.login`

#### 3.2 配置檔案
**檔案**: `ios/Runner/AppleSignIn.plist`
```xml
<key>KEY_ID</key>
<string>2F963AR7G6</string>
<key>SERVICES_ID</key>
<string>com.example.here4help.login</string>
```

## 🌍 環境配置

### 1. 開發環境 (`development.json`)
```json
{
  "google_client_id": "102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com",
  "facebook_app_id": "1037019294991326",
  "apple_service_id": "com.example.here4help.login"
}
```

### 2. 測試環境 (`staging.json`)
```json
{
  "google_client_id": "102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com",
  "facebook_app_id": "1037019294991326",
  "apple_service_id": "com.example.here4help.login"
}
```

### 3. 生產環境 (`production.json`)
```json
{
  "google_client_id": "102744926949-bhrnm2970bgt3dfm2nmdbqt03mrvdh3i.apps.googleusercontent.com",
  "facebook_app_id": "1037019294991326",
  "apple_service_id": "com.example.here4help.login"
}
```

## 🔧 平台特定配置

### 1. Android 配置

#### 1.1 build.gradle.kts
```kotlin
plugins {
    id("com.google.gms.google-services")
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}
```

#### 1.2 專案級 build.gradle.kts
```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

### 2. iOS 配置

#### 2.1 Info.plist URL Scheme
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>Google Sign-In</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.102744926949-951r2epiq93abijklu5te2qocpc9kqqv</string>
        </array>
    </dict>
</array>
```

## 🔒 安全性配置

### 1. .gitignore 保護
```gitignore
# Google Services
android/app/google-services.json
ios/Runner/GoogleService-Info.plist

# Apple Sign-In
ios/Runner/AppleSignIn.plist

# Facebook Config
assets/app_env/facebook_config.json

# 環境配置（包含真實憑證）
assets/app_env/development.json
assets/app_env/staging.json
assets/app_env/production.json
```

### 2. 環境變數管理
- 使用環境配置檔案管理敏感資訊
- 不同環境使用相同的 Client ID（Web 版本）
- 平台特定配置檔案保持本地

## 🧪 測試配置

### 1. 開發環境測試
```bash
flutter run --dart-define=ENVIRONMENT=development
```

### 2. 測試環境測試
```bash
flutter run --dart-define=ENVIRONMENT=staging
```

### 3. 生產環境測試
```bash
flutter run --dart-define=ENVIRONMENT=production
```

## 📱 功能驗證

### 1. Google 登入測試
1. 點擊 Google 登入按鈕
2. 選擇 Google 帳號
3. 授權應用程式存取
4. 驗證後端回應

### 2. Facebook 登入測試
1. 點擊 Facebook 登入按鈕
2. 選擇 Facebook 帳號
3. 授權應用程式存取
4. 驗證後端回應

### 3. Apple Sign-In 測試
1. 點擊 Apple 登入按鈕
2. 使用 Apple ID 登入
3. 授權應用程式存取
4. 驗證後端回應

## 🚀 部署注意事項

### 1. 憑證管理
- 確保所有平台憑證都已正確配置
- 檢查 SHA1 憑證指紋是否匹配
- 驗證 OAuth 重新導向 URI

### 2. 環境配置
- 生產環境使用正確的 API 端點
- 檢查 HTTPS 憑證
- 驗證防火牆設定

### 3. 監控與日誌
- 監控登入成功率
- 記錄錯誤日誌
- 追蹤用戶行為

## 📞 支援與聯絡

如有問題，請聯絡開發團隊或參考以下資源：
- [Google Sign-In 官方文檔](https://developers.google.com/identity/sign-in)
- [Facebook Login 官方文檔](https://developers.facebook.com/docs/facebook-login)
- [Apple Sign-In 官方文檔](https://developer.apple.com/sign-in-with-apple/)

## 🔄 更新記錄

- **2025-01-19**: 初始配置文檔
- **2025-01-19**: 添加所有第三方登入配置
- **2025-01-19**: 完善平台特定配置說明
- **2025-01-19**: 添加安全性配置和部署說明

# 🔐 Google 第三方登入配置指南

## 📋 概述
本文檔說明如何在 Here4Help 專案中配置 Google 第三方登入功能。

## 🚨 重要提醒
**⚠️ 請注意：以下配置中的 Client ID 僅為範例，實際部署時請替換為真實的 Google OAuth 2.0 Client ID**

## 🔧 配置步驟

### 1. Google Cloud Console 設定
1. 前往 [Google Cloud Console](https://console.cloud.google.com/)
2. 建立新專案或選擇現有專案
3. 啟用 Google+ API 和 Google Sign-In API
4. 在「憑證」頁面建立 OAuth 2.0 用戶端 ID
5. 設定授權的重新導向 URI

### 2. 環境配置檔案

#### 開發環境 (`assets/app_env/development.json`)
```json
{
  "google_client_id": "123456789-abcdefghijklmnop.apps.googleusercontent.com"
}
```

#### 測試環境 (`assets/app_env/staging.json`)
```json
{
  "google_client_id": "555666777-abcdefghijklmnop.apps.googleusercontent.com"
}
```

#### 生產環境 (`assets/app_env/production.json`)
```json
{
  "google_client_id": "987654321-zyxwvutsrqponml.apps.googleusercontent.com"
}
```

### 3. Android 配置

#### 3.1 添加 google-services.json
- 從 Google Cloud Console 下載 `google-services.json`
- 放置在 `android/app/` 目錄下
- 確保檔案已加入 `.gitignore`

#### 3.2 build.gradle.kts 配置
```kotlin
plugins {
    id("com.google.gms.google-services")
}

dependencies {
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}
```

### 4. iOS 配置

#### 4.1 添加 GoogleService-Info.plist
- 從 Google Cloud Console 下載 `GoogleService-Info.plist`
- 放置在 `ios/Runner/` 目錄下
- 確保檔案已加入 `.gitignore`

#### 4.2 Info.plist 配置
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>Google Sign-In</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 🔒 安全性考量

### 1. 敏感資訊保護
- ✅ 使用環境配置檔案管理敏感資訊
- ✅ 不同環境使用不同的 Client ID
- ✅ 敏感檔案加入 `.gitignore`

### 2. 後端驗證
- ✅ 後端驗證 Google ID Token
- ✅ 使用 HTTPS 通訊
- ✅ 實作 JWT Token 驗證

### 3. 用戶資料保護
- ✅ 最小權限原則
- ✅ 用戶同意機制
- ✅ 資料加密傳輸

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

### 1. 登入流程
1. 點擊 Google 登入按鈕
2. 選擇 Google 帳號
3. 授權應用程式存取
4. 成功登入並獲取用戶資訊

### 2. 錯誤處理
- 網路連線錯誤
- 用戶取消登入
- 授權失敗
- 後端驗證失敗

## 🚀 部署注意事項

### 1. 環境變數
- 確保生產環境使用正確的 Client ID
- 檢查 API 端點是否正確
- 驗證 HTTPS 憑證

### 2. 監控與日誌
- 監控登入成功率
- 記錄錯誤日誌
- 追蹤用戶行為

### 3. 備份與恢復
- 定期備份配置檔案
- 準備回滾方案
- 測試恢復流程

## 📞 支援與聯絡

如有問題，請聯絡開發團隊或參考以下資源：
- [Google Sign-In 官方文檔](https://developers.google.com/identity/sign-in/android)
- [Flutter Google Sign-In 插件](https://pub.dev/packages/google_sign_in)
- [Google Cloud Console 說明](https://console.cloud.google.com/apis/credentials)

## 🔄 更新記錄

- **2025-01-19**: 初始配置文檔
- **2025-01-19**: 添加安全性考量
- **2025-01-19**: 完善部署說明

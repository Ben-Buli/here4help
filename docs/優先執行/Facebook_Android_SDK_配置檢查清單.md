# Facebook Android SDK 配置檢查清單

> 本文件提供 Facebook Android SDK 配置的完整檢查清單，確保 Facebook 登入功能在 Android 平台正常運作。

---

## 📱 **Android 配置檢查清單**

### **1. 套件依賴檢查**
- [ ] `flutter_facebook_auth: ^6.0.4` 已在 `pubspec.yaml` 中配置
- [ ] `android/app/build.gradle.kts` 已新增 Facebook SDK 依賴
- [ ] `android/build.gradle.kts` 已新增 Facebook Maven 倉庫

### **2. 應用程式配置檢查**
- [ ] `android/app/src/main/res/values/strings.xml` 已建立並配置：
  - [ ] `facebook_app_id`：Facebook 應用程式 ID
  - [ ] `fb_login_protocol_scheme`：Facebook 登入協議方案
  - [ ] `facebook_client_token`：Facebook 客戶端權杖
  - [ ] `facebook_display_name`：Facebook 顯示名稱

### **3. AndroidManifest.xml 檢查**
- [ ] 已新增 Facebook SDK 權限：
  - [ ] `INTERNET` 權限
  - [ ] `ACCESS_NETWORK_STATE` 權限
- [ ] 已新增 Facebook SDK meta-data：
  - [ ] `ApplicationId`
  - [ ] `ClientToken`
  - [ ] `DisplayName`
  - [ ] `FacebookContentProvider`
- [ ] 已新增 Facebook Activity：
  - [ ] `FacebookActivity`
  - [ ] `CustomTabActivity`
- [ ] 已配置 Facebook 登入回調 intent-filter

### **4. MainActivity.kt 檢查**
- [ ] 已導入 Facebook SDK 類別：
  - [ ] `import com.facebook.FacebookSdk`
  - [ ] `import com.facebook.appevents.AppEventsLogger`
- [ ] 已在 `configureFlutterEngine` 中初始化 Facebook SDK
- [ ] 已啟用 App Events Logger

### **5. 環境配置檢查**
- [ ] `backend/config/env.local` 已配置 Facebook 憑證
- [ ] `backend/config/env.production` 已配置 Facebook 憑證
- [ ] Facebook 回調 URL 已正確設定

---

## 🔧 **配置檔案內容檢查**

### **strings.xml 配置**
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Facebook 配置 -->
    <string name="facebook_app_id">your_facebook_app_id</string>
    <string name="fb_login_protocol_scheme">fbYourAppId</string>
    <string name="facebook_client_token">your_facebook_client_token</string>
    <string name="facebook_display_name">Here4Help</string>
    
    <!-- 應用程式名稱 -->
    <string name="app_name">Here4Help</string>
</resources>
```

### **AndroidManifest.xml 配置**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Facebook 登入權限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <application>
        <!-- Facebook SDK 配置 -->
        <meta-data
            android:name="com.facebook.sdk.ApplicationId"
            android:value="@string/facebook_app_id" />
        <meta-data
            android:name="com.facebook.sdk.ClientToken"
            android:value="@string/facebook_client_token" />
        <meta-data
            android:name="com.facebook.sdk.DisplayName"
            android:value="@string/facebook_display_name" />
        <meta-data
            android:name="com.facebook.sdk.FacebookContentProvider"
            android:value="@string/facebook_app_id" />
        
        <!-- Facebook 登入回調 Activity -->
        <activity
            android:name="com.facebook.FacebookActivity"
            android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
            android:label="@string/facebook_display_name" />
        <activity
            android:name="com.facebook.CustomTabActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="@string/fb_login_protocol_scheme" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### **MainActivity.kt 配置**
```kotlin
package com.example.here4help

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // 初始化 Facebook SDK
        FacebookSdk.sdkInitialize(applicationContext)
        AppEventsLogger.activateApp(application)
    }
}
```

---

## 🧪 **測試檢查清單**

### **1. 編譯測試**
- [ ] 專案可以正常編譯
- [ ] 沒有 Facebook SDK 相關的編譯錯誤
- [ ] APK 可以正常生成

### **2. 功能測試**
- [ ] Facebook 登入按鈕正常顯示
- [ ] 點擊 Facebook 登入按鈕後彈出登入視窗
- [ ] 可以正常完成 Facebook 登入流程
- [ ] 登入成功後可以獲取用戶資料
- [ ] 登出功能正常運作

### **3. 錯誤處理測試**
- [ ] 網路錯誤時的處理
- [ ] 用戶取消登入的處理
- [ ] Facebook 服務不可用時的處理
- [ ] 權限被拒絕時的處理

---

## 🚨 **常見問題排除**

### **1. 編譯錯誤**
- **問題**：找不到 Facebook SDK 類別
- **解決**：檢查 `build.gradle.kts` 中的依賴配置

- **問題**：找不到 Facebook 相關資源
- **解決**：檢查 `strings.xml` 中的配置

### **2. 運行時錯誤**
- **問題**：Facebook 登入按鈕無反應
- **解決**：檢查 `AndroidManifest.xml` 中的配置

- **問題**：登入後無法獲取用戶資料
- **解決**：檢查 Facebook 應用程式設定和權限

### **3. 配置錯誤**
- **問題**：Facebook 應用程式 ID 無效
- **解決**：檢查 Facebook 開發者控制台中的設定

- **問題**：回調 URL 錯誤
- **解決**：檢查 Facebook 應用程式設定中的 OAuth 重新導向 URI

---

## 📋 **配置完成確認**

### **配置狀態**
- [ ] 所有配置檔案已更新
- [ ] Facebook SDK 依賴已添加
- [ ] 權限和 meta-data 已配置
- [ ] MainActivity 已更新
- [ ] 測試已通過

### **配置資訊**
**Facebook 應用程式 ID**：_________________  
**Facebook 客戶端權杖**：_________________  
**配置完成日期**：_________________  
**配置負責人**：_________________  
**測試狀態**：_________________

---

## 📞 **支援與聯絡**

如有問題或需要協助，請聯繫開發團隊或參考：
- [Facebook 開發者文檔](https://developers.facebook.com/docs/)
- [Facebook Android SDK 文檔](https://developers.facebook.com/docs/android/)
- [Flutter Facebook Auth 套件文檔](https://pub.dev/packages/flutter_facebook_auth)

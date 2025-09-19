# Facebook 登入配置指南

> 本指南提供 Facebook 登入功能的完整配置步驟，包括開發環境和正式環境的設定。

---

## 📋 **前置準備**

### **1. Facebook 開發者帳號**
- [ ] 擁有 Facebook 帳號
- [ ] 已啟用 Facebook 開發者模式
- [ ] 已通過 Facebook 開發者驗證

### **2. 應用程式資訊**
- [ ] 應用程式名稱：`Here4Help`
- [ ] 應用程式描述：`NCCU Social Task Posting APP`
- [ ] 隱私政策 URL：`https://yourdomain.com/privacy`
- 服務條款 URL：`https://yourdomain.com/terms`

---

## 🚀 **Facebook 開發者設定步驟**

### **步驟 1：建立 Facebook 應用程式**

1. 訪問 [Facebook 開發者](https://developers.facebook.com/)
2. 點擊「建立應用程式」
3. 選擇「消費者」類型
4. 填寫應用程式資訊：
   - 應用程式名稱：`Here4Help`
   - 聯絡電子郵件：`your-email@domain.com`
   - 應用程式用途：選擇最適合的用途

### **步驟 2：配置 Facebook 登入產品**

1. 在應用程式儀表板中，點擊「新增產品」
2. 選擇「Facebook 登入」
3. 選擇平台：
   - **iOS**：輸入 Bundle ID
   - **Android**：輸入 Package Name
   - **Web**：輸入網站 URL

### **步驟 3：配置應用程式設定**

#### **基本設定**
- 應用程式網域：`yourdomain.com`
- 隱私政策 URL：`https://yourdomain.com/privacy`
- 服務條款 URL：`https://yourdomain.com/terms`
- 用戶資料刪除：`https://yourdomain.com/data-deletion`

#### **Facebook 登入設定**
- 有效的 OAuth 重新導向 URI：
  - 開發環境：`http://localhost:8888/here4help/backend/api/auth/facebook/callback`
  - 正式環境：`https://yourdomain.com/api/auth/facebook/callback`

### **步驟 4：獲取應用程式憑證**

1. 在應用程式儀表板中，記錄以下資訊：
   - **應用程式編號** (App ID)
   - **應用程式密鑰** (App Secret)
   - **客戶端權杖** (Client Token)

2. 將這些資訊填入環境配置檔案

---

## ⚙️ **環境配置**

### **開發環境配置 (`env.local`)**
```env
# Facebook OAuth 2.0
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_CLIENT_TOKEN=your_facebook_client_token

# 回調 URL 配置
FACEBOOK_CALLBACK_URL=http://localhost:8888/here4help/backend/api/auth/facebook/callback
```

### **正式環境配置 (`env.production`)**
```env
# Facebook OAuth 2.0
FACEBOOK_APP_ID=your_production_facebook_app_id
FACEBOOK_APP_SECRET=your_production_facebook_app_secret
FACEBOOK_CLIENT_TOKEN=your_production_facebook_client_token

# 回調 URL 配置
FACEBOOK_CALLBACK_URL=https://yourdomain.com/api/auth/facebook/callback
```

---

## 📱 **Flutter 端配置**

### **1. 套件依賴**
`flutter_facebook_auth: ^6.0.4` 已在 `pubspec.yaml` 中配置

### **2. Android 配置**

#### **`android/app/src/main/res/values/strings.xml`**
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="facebook_app_id">your_facebook_app_id</string>
    <string name="fb_login_protocol_scheme">fbYourAppId</string>
    <string name="facebook_client_token">your_facebook_client_token</string>
</resources>
```

#### **`android/app/src/main/AndroidManifest.xml`**
```xml
<manifest>
    <application>
        <!-- Facebook 配置 -->
        <meta-data
            android:name="com.facebook.sdk.ApplicationId"
            android:value="@string/facebook_app_id" />
        <meta-data
            android:name="com.facebook.sdk.ClientToken"
            android:value="@string/facebook_client_token" />
    </application>
</manifest>
```

### **3. iOS 配置**

#### **`ios/Runner/Info.plist`**
```xml
<key>FacebookAppID</key>
<string>your_facebook_app_id</string>
<key>FacebookClientToken</key>
<string>your_facebook_client_token</string>
<key>FacebookDisplayName</key>
<string>Here4Help</string>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>facebook</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fbYourAppId</string>
        </array>
    </dict>
</array>
```

---

## 🧪 **測試與驗證**

### **1. 開發環境測試**
- [ ] Facebook 登入按鈕正常顯示
- [ ] 點擊後彈出 Facebook 登入視窗
- [ ] 登入成功後獲取用戶資料
- [ ] 資料正確傳遞到後端 API

### **2. 正式環境測試**
- [ ] HTTPS 回調 URL 正常運作
- [ ] 用戶資料正確儲存到資料庫
- [ ] 登入狀態保持正常
- [ ] 登出功能正常

### **3. 錯誤處理測試**
- [ ] 用戶取消登入的處理
- [ ] 網路錯誤的處理
- [ ] Facebook 服務不可用的處理
- [ ] 權限被拒絕的處理

---

## 🔒 **安全性考量**

### **1. 資料保護**
- [ ] 用戶資料加密傳輸
- [ ] 敏感資訊不在日誌中暴露
- [ ] 權杖安全儲存

### **2. 權限管理**
- [ ] 只請求必要的權限
- [ ] 用戶可以撤銷權限
- [ ] 定期檢查權限狀態

### **3. 合規性**
- [ ] 符合 Facebook 平台政策
- [ ] 提供隱私政策
- [ ] 提供服務條款
- [ ] 支援資料刪除請求

---

## 🚨 **常見問題排除**

### **1. 登入失敗**
- 檢查應用程式 ID 和密鑰是否正確
- 確認回調 URL 設定正確
- 檢查 Facebook 應用程式狀態

### **2. 權限問題**
- 確認已請求正確的權限
- 檢查用戶是否已授權
- 驗證應用程式審核狀態

### **3. 回調錯誤**
- 檢查回調 URL 格式
- 確認網域設定正確
- 驗證 HTTPS 憑證

---

## 📞 **支援與聯絡**

### **Facebook 開發者支援**
- [Facebook 開發者文檔](https://developers.facebook.com/docs/)
- [Facebook 開發者社群](https://developers.facebook.com/community/)
- [Facebook 開發者支援](https://developers.facebook.com/support/)

### **專案支援**
如有問題，請聯繫開發團隊或參考專案文檔。

---

## ✅ **配置完成檢查清單**

- [ ] Facebook 開發者帳號已建立
- [ ] 應用程式已建立並配置
- [ ] Facebook 登入產品已啟用
- [ ] 應用程式憑證已獲取
- [ ] 環境配置檔案已更新
- [ ] Flutter 端配置已完成
- [ ] 測試已通過
- [ ] 安全性檢查已完成
- [ ] 合規性要求已滿足

**配置完成日期**：_________________  
**配置負責人**：_________________  
**測試狀態**：_________________

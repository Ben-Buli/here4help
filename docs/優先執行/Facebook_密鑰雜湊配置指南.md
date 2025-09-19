# Facebook 密鑰雜湊配置指南

> 本文件提供 Facebook 登入所需的 Android 密鑰雜湊配置說明，包括開發環境和發行環境的密鑰雜湊產生方法。

---

## 🔑 **密鑰雜湊說明**

### **什麼是密鑰雜湊？**
密鑰雜湊是 Facebook 用來驗證您的 Android 應用程式真實性的重要憑證。每個 Android 應用程式都必須提供對應的密鑰雜湊，Facebook 才能允許該應用程式進行登入操作。

### **為什麼需要密鑰雜湊？**
- **安全性**：防止惡意應用程式冒充您的應用程式
- **驗證**：確保只有您的應用程式能使用 Facebook 登入
- **合規性**：Facebook 平台要求必須提供

---

## 🛠️ **密鑰雜湊產生方法**

### **1. 開發環境密鑰雜湊**

#### **Mac OS 指令**
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
```

#### **Windows 指令**
```cmd
keytool -exportcert -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore | openssl sha1 -binary | openssl base64
```

#### **Linux 指令**
```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore | openssl sha1 -binary | openssl base64
```

#### **預設密碼**
- **開發環境**：`0000` 或 `android`

### **2. 發行環境密鑰雜湊**

#### **Mac OS 指令**
```bash
keytool -exportcert -alias YOUR_RELEASE_KEY_ALIAS -keystore YOUR_RELEASE_KEY_PATH | openssl sha1 -binary | openssl base64
```

#### **Windows 指令**
```cmd
keytool -exportcert -alias YOUR_RELEASE_KEY_ALIAS -keystore YOUR_RELEASE_KEY_PATH | openssl sha1 -binary | openssl base64
```

#### **Linux 指令**
```bash
keytool -exportcert -alias YOUR_RELEASE_KEY_ALIAS -keystore YOUR_RELEASE_KEY_PATH | openssl sha1 -binary | openssl base64
```

---

## 📱 **當前專案密鑰雜湊狀態**

### **開發環境密鑰雜湊**
✅ **已產生**：`Z+kCVUEyrEtIdvyw95dMZn1rtSE=`

### **發行環境密鑰雜湊**
⚠️ **尚未配置**：專案目前使用 debug 簽名配置

---

## 🔧 **發行密鑰配置步驟**

### **1. 建立發行密鑰**

#### **使用 Android Studio**
1. 開啟 Android Studio
2. 選擇 `Build` → `Generate Signed Bundle / APK`
3. 選擇 `APK`
4. 建立新的 KeyStore 或使用現有的
5. 填寫密鑰資訊（別名、密碼、有效期等）

#### **使用指令列**
```bash
keytool -genkey -v -keystore my-release-key.keystore -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
```

### **2. 更新 build.gradle.kts**

在 `android/app/build.gradle.kts` 中新增發行簽名配置：

```kotlin
android {
    // ... 其他配置 ...
    
    signingConfigs {
        create("release") {
            keyAlias = "my-key-alias"
            keyPassword = "your-key-password"
            storeFile = file("my-release-key.keystore")
            storePassword = "your-store-password"
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // ... 其他 release 配置 ...
        }
    }
}
```

### **3. 產生發行密鑰雜湊**

使用您的發行密鑰資訊執行指令：

```bash
keytool -exportcert -alias my-key-alias -keystore my-release-key.keystore | openssl sha1 -binary | openssl base64
```

---

## 📋 **Facebook 開發者控制台配置**

### **1. 登入 Facebook 開發者控制台**
- 前往 [developers.facebook.com](https://developers.facebook.com)
- 選擇您的應用程式

### **2. 配置 Android 平台**
1. 在左側選單中選擇 `設定` → `基本`
2. 點擊 `新增平台` → `Android`
3. 填寫以下資訊：
   - **套件名稱**：`com.example.here4help`
   - **類別名稱**：`com.example.here4help.MainActivity`
   - **密鑰雜湊**：貼上您產生的密鑰雜湊

### **3. 密鑰雜湊管理**
- **開發環境**：添加開發密鑰雜湊
- **發行環境**：添加發行密鑰雜湊
- **測試環境**：可以添加多個密鑰雜湊

---

## 🚨 **常見問題與解決方案**

### **1. 密鑰雜湊錯誤**
- **問題**：Facebook 登入時出現密鑰雜湊錯誤
- **解決**：檢查密鑰雜湊是否正確添加到 Facebook 開發者控制台

### **2. 找不到 KeyStore**
- **問題**：找不到 debug.keystore 檔案
- **解決**：執行 `flutter clean` 後重新建置專案

### **3. 密碼錯誤**
- **問題**：keytool 要求輸入密碼時出錯
- **解決**：開發環境預設密碼通常是 `0000` 或 `android`

### **4. 發行版本登入失敗**
- **問題**：開發版本正常，發行版本 Facebook 登入失敗
- **解決**：檢查是否添加了發行密鑰雜湊

---

## 📝 **配置檢查清單**

### **開發環境**
- [ ] 已產生開發密鑰雜湊
- [ ] 已添加到 Facebook 開發者控制台
- [ ] 開發版本 Facebook 登入正常

### **發行環境**
- [ ] 已建立發行密鑰
- [ ] 已更新 build.gradle.kts
- [ ] 已產生發行密鑰雜湊
- [ ] 已添加到 Facebook 開發者控制台
- [ ] 發行版本 Facebook 登入正常

---

## 🔐 **安全注意事項**

### **1. 密鑰保護**
- 不要將 KeyStore 檔案提交到版本控制系統
- 妥善保管密鑰密碼
- 定期備份 KeyStore 檔案

### **2. 環境分離**
- 開發和發行使用不同的密鑰
- 測試環境使用獨立的密鑰
- 避免在生產環境使用開發密鑰

### **3. 憑證管理**
- 記錄密鑰的有效期
- 在密鑰過期前更新
- 建立密鑰輪換流程

---

## 📞 **支援與聯絡**

如有問題或需要協助，請聯繫開發團隊或參考：
- [Facebook 開發者文檔](https://developers.facebook.com/docs/)
- [Android 應用程式簽名文檔](https://developer.android.com/studio/publish/app-signing)
- [Flutter 應用程式簽名文檔](https://flutter.dev/docs/deployment/android)

---

## 📋 **配置完成確認**

### **配置狀態**
- [ ] 開發密鑰雜湊已產生並配置
- [ ] 發行密鑰已建立並配置
- [ ] Facebook 開發者控制台已更新
- [ ] 測試已通過

### **配置資訊**
**開發密鑰雜湊**：`Z+kCVUEyrEtIdvyw95dMZn1rtSE=`  
**發行密鑰雜湊**：_________________  
**配置完成日期**：_________________  
**配置負責人**：_________________  
**測試狀態**：_________________

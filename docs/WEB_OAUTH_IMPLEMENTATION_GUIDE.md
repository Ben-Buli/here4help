# 🌐 Web OAuth 實作指南

## 📋 概述

本指南說明如何在 Flutter Web 中實作真正的第三方登入 OAuth 流程，解決目前使用模擬資料的問題。

## 🔍 當前問題分析

### **問題描述**
- Google 登入回應顯示 `success: true`
- 但用戶沒有看到 Google 登入頁面
- 原因是目前使用模擬資料，而非真正的 OAuth 流程

### **根本原因**
1. **Web 版 Google 登入**：使用模擬資料，不會跳轉到 Google 登入頁面
2. **移動版 Google 登入**：使用真實的 `google_sign_in` 套件，會跳轉到 Google 登入頁面
3. **Flutter Web 限制**：無法直接處理 OAuth 回調

## 🛠️ 解決方案

### **方案 1：使用 url_launcher 打開 OAuth 頁面**

#### **優點**
- 實作簡單
- 用戶會看到真正的 Google 登入頁面
- 支援所有 OAuth 提供商

#### **缺點**
- 需要處理 OAuth 回調
- 用戶體驗可能不夠流暢
- 需要額外的後端處理

#### **實作步驟**
1. 添加 `url_launcher` 套件
2. 創建 OAuth 授權 URL
3. 使用 `launchUrl` 打開登入頁面
4. 處理 OAuth 回調

### **方案 2：使用 Popup 視窗**

#### **優點**
- 用戶體驗更好
- 不需要離開應用
- 可以實時處理回調

#### **缺點**
- 實作複雜
- 需要處理彈出視窗阻擋
- 跨瀏覽器兼容性問題

### **方案 3：使用 OAuth 2.0 隱式流程**

#### **優點**
- 不需要後端處理
- 實作相對簡單
- 適合單頁應用

#### **缺點**
- 安全性較低
- 不支援 refresh token
- 需要額外的安全措施

## 🚀 推薦實作方案

### **開發階段**
- 使用 **url_launcher** 方案
- 實作基本的 OAuth 流程
- 使用模擬資料進行測試

### **生產階段**
- 使用 **Popup 視窗** 方案
- 實作完整的 OAuth 回調處理
- 提供最佳用戶體驗

## 📝 實作代碼

### **1. 添加依賴**

```yaml
dependencies:
  url_launcher: ^6.2.5
```

### **2. 更新 Google 登入服務**

```dart
import 'package:url_launcher/url_launcher.dart';

// Web 版 Google 登入
Future<Map<String, dynamic>?> _signInWithGoogleWeb() async {
  try {
    // 檢查配置
    if (EnvironmentConfig.googleClientId.isEmpty) {
      throw Exception('Google Client ID 未配置');
    }

    // 創建 OAuth 授權 URL
    final googleAuthUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': EnvironmentConfig.googleClientId,
      'redirect_uri': '${EnvironmentConfig.apiBaseUrl}/backend/api/auth/google-callback.php',
      'response_type': 'code',
      'scope': 'email profile',
      'state': 'web_google_${DateTime.now().millisecondsSinceEpoch}',
      'access_type': 'offline',
      'prompt': 'consent',
    });

    // 打開 Google 登入頁面
    final canLaunch = await canLaunchUrl(googleAuthUrl);
    if (canLaunch) {
      final launched = await launchUrl(
        googleAuthUrl,
        mode: LaunchMode.externalApplication,
      );
      
      if (launched) {
        print('✅ Google 登入頁面已打開');
        // 處理 OAuth 回調...
      }
    }
  } catch (e) {
    print('Web Google 登入錯誤: $e');
    return null;
  }
}
```

### **3. 處理 OAuth 回調**

#### **後端回調處理**
```php
// backend/api/auth/google-callback.php
<?php
// 處理 Google OAuth 回調
$code = $_GET['code'] ?? null;
$state = $_GET['state'] ?? null;

if ($code && $state) {
    // 使用授權碼交換 access token
    $tokenResponse = exchangeCodeForToken($code);
    
    // 獲取用戶資料
    $userProfile = getUserProfile($tokenResponse['access_token']);
    
    // 處理登入邏輯...
}
?>
```

#### **前端回調處理**
```dart
// 監聽 OAuth 回調
void listenForOAuthCallback() {
  // 使用 WebView 或 iframe 來處理回調
  // 或者使用 postMessage 來與父視窗通信
}
```

## 🔧 配置要求

### **Google OAuth 配置**
1. **Client ID**：Web 應用程式的 OAuth 2.0 客戶端 ID
2. **Client Secret**：Web 應用程式的 OAuth 2.0 客戶端密鑰
3. **Redirect URI**：OAuth 回調的 URI
4. **Authorized JavaScript origins**：允許的 JavaScript 來源

### **環境配置**
```json
{
  "public": {
    "google_client_id": "your-google-client-id.apps.googleusercontent.com",
    "google_web_client_secret": "your-google-web-client-secret"
  }
}
```

## 📱 跨平台支援

### **Web 平台**
- 使用 `url_launcher` 打開 OAuth 頁面
- 處理 OAuth 回調
- 支援所有 OAuth 提供商

### **iOS 平台**
- 使用 `google_sign_in` 套件
- 原生 OAuth 流程
- 最佳用戶體驗

### **Android 平台**
- 使用 `google_sign_in` 套件
- 原生 OAuth 流程
- 最佳用戶體驗

## 🚨 注意事項

### **安全性考慮**
1. **State 參數**：防止 CSRF 攻擊
2. **HTTPS**：生產環境必須使用 HTTPS
3. **Token 存儲**：安全存儲 access token 和 refresh token
4. **Scope 限制**：只請求必要的權限

### **用戶體驗**
1. **載入狀態**：顯示登入進度
2. **錯誤處理**：友好的錯誤提示
3. **回調處理**：無縫的登入流程
4. **離線支援**：處理網路問題

## 🔮 未來改進

### **短期目標**
1. 實作基本的 OAuth 流程
2. 處理 OAuth 回調
3. 測試跨平台功能

### **長期目標**
1. 使用 Popup 視窗改善用戶體驗
2. 實作 OAuth 狀態管理
3. 支援更多 OAuth 提供商
4. 實作 OAuth 令牌刷新

## 📚 相關資源

- [Google OAuth 2.0 文檔](https://developers.google.com/identity/protocols/oauth2)
- [Flutter Web OAuth 實作](https://flutter.dev/docs/development/platform-integration/web)
- [url_launcher 套件](https://pub.dev/packages/url_launcher)
- [OAuth 2.0 安全最佳實踐](https://oauth.net/2/oauth-best-practice/)

---

**最後更新**：2025-01-19  
**狀態**：🔄 實作中  
**下一步**：測試 OAuth 流程

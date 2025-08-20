# 🔐 Google OAuth 回調處理實作說明

## 📋 **概述**

本文檔說明 Google OAuth 回調處理的完整實作，包括後端回調處理、前端重定向處理和完整的 OAuth 流程。

## 🏗️ **架構設計**

### **OAuth 流程圖**
```
用戶點擊 Google 登入 → 跳轉到 Google 授權頁面 → 用戶授權 → Google 重定向到回調 URL → 
後端處理授權碼 → 交換 access token → 獲取用戶資料 → 處理用戶登入 → 重定向到前端
```

### **檔案結構**
```
backend/api/auth/
├── google-login.php          # 原有的 Google 登入處理
├── google-callback.php       # 新增：OAuth 回調處理
└── ...

lib/auth/services/
└── third_party_auth_service.dart  # 更新：支援真實 OAuth 流程
```

## 🔧 **後端實作**

### **1. google-callback.php**

#### **主要功能**
- 接收 Google OAuth 回調參數
- 驗證 state 參數防止 CSRF 攻擊
- 使用授權碼交換 access token
- 獲取用戶資料
- 處理用戶登入/註冊
- 生成 JWT token
- 重定向到前端應用

#### **關鍵程式碼片段**
```php
// 驗證 state 參數
if (!preg_match('/^web_google_\d+$/', $state)) {
    throw new Exception('Invalid state parameter');
}

// 使用授權碼交換 access token
$tokenUrl = 'https://oauth2.googleapis.com/token';
$tokenData = [
    'client_id' => $clientId,
    'client_secret' => $clientSecret,
    'code' => $code,
    'grant_type' => 'authorization_code',
    'redirect_uri' => $redirectUri,
];

// 獲取用戶資料
$userInfoUrl = 'https://www.googleapis.com/oauth2/v2/userinfo';
```

#### **環境配置需求**
```bash
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI=http://localhost:8888/here4help/backend/api/auth/google-callback.php
FRONTEND_URL=http://localhost:3000
```

### **2. 資料庫處理**

#### **用戶身份管理**
- 檢查現有的 `user_identities` 記錄
- 處理新用戶註冊
- 處理現有用戶綁定
- 更新 access token

#### **資料表結構**
```sql
-- users 表：基本用戶資訊
-- user_identities 表：第三方登入身份資訊
-- 包含：provider, provider_user_id, access_token, raw_profile
```

## 🌐 **前端實作**

### **1. 第三方登入服務更新**

#### **Web OAuth 流程**
```dart
// 在 _signInWithGoogleWeb() 中
final googleAuthUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
  'client_id': EnvironmentConfig.googleClientId,
  'redirect_uri': '${EnvironmentConfig.apiBaseUrl}/backend/api/auth/google-callback.php',
  'response_type': 'code',
  'scope': 'email profile',
  'state': 'web_google_$timestamp',
  'access_type': 'offline',
  'prompt': 'consent',
});

// 使用 url_launcher 打開 Google 登入頁面
final launched = await launchUrl(
  googleAuthUrl,
  mode: LaunchMode.externalApplication,
);
```

### **2. 回調處理頁面**

#### **需要創建的頁面**
```
lib/auth/pages/
└── auth_callback_page.dart  # 處理 OAuth 回調
```

#### **回調處理邏輯**
```dart
class AuthCallbackPage extends StatefulWidget {
  @override
  _AuthCallbackPageState createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  void _handleCallback() {
    final uri = Uri.parse(window.location.href);
    final success = uri.queryParameters['success'] == 'true';
    
    if (success) {
      final token = uri.queryParameters['token'];
      final userData = jsonDecode(uri.queryParameters['user_data'] ?? '{}');
      final isNewUser = uri.queryParameters['is_new_user'] == 'true';
      
      // 處理登入成功
      _handleLoginSuccess(token, userData, isNewUser);
    } else {
      final error = uri.queryParameters['error'];
      // 處理登入失敗
      _handleLoginError(error);
    }
  }
}
```

## 🚀 **部署步驟**

### **1. 環境配置**
```bash
# 複製環境配置檔案
cp backend/config/env.development backend/config/.env

# 編輯 .env 檔案，填入實際的 Google OAuth 設定
GOOGLE_CLIENT_ID=your_actual_google_client_id
GOOGLE_CLIENT_SECRET=your_actual_google_client_secret
```

### **2. Google Console 設定**
- 在 Google Cloud Console 中添加授權重定向 URI
- 重定向 URI：`http://localhost:8888/here4help/backend/api/auth/google-callback.php`
- 確保 Client ID 和 Client Secret 正確

### **3. 測試流程**
1. 啟動後端服務
2. 測試 Google 登入流程
3. 檢查回調處理是否正常
4. 驗證用戶資料是否正確儲存

## ⚠️ **注意事項**

### **安全性考慮**
- 驗證 state 參數防止 CSRF 攻擊
- 使用 HTTPS 在生產環境
- 保護 Client Secret
- 實作適當的錯誤處理

### **錯誤處理**
- 網路錯誤處理
- 授權碼過期處理
- 用戶拒絕授權處理
- 資料庫錯誤處理

### **效能優化**
- 使用適當的 HTTP 狀態碼
- 實作請求限流
- 優化資料庫查詢
- 實作快取機制

## 🔍 **除錯指南**

### **常見問題**
1. **授權碼交換失敗**
   - 檢查 Client ID 和 Secret
   - 確認重定向 URI 匹配
   - 檢查授權碼是否過期

2. **用戶資料獲取失敗**
   - 檢查 access token 是否有效
   - 確認 scope 權限
   - 檢查網路連線

3. **重定向失敗**
   - 檢查前端 URL 設定
   - 確認 CORS 設定
   - 檢查瀏覽器限制

### **日誌檢查**
```bash
# 檢查 PHP 錯誤日誌
tail -f /var/log/php_errors.log

# 檢查應用日誌
tail -f backend/logs/oauth.log
```

## 📚 **參考資源**

- [Google OAuth 2.0 文檔](https://developers.google.com/identity/protocols/oauth2)
- [PHP cURL 文檔](https://www.php.net/manual/en/book.curl.php)
- [Flutter url_launcher 文檔](https://pub.dev/packages/url_launcher)

## 🎯 **下一步行動**

1. **完成回調處理頁面**
   - 創建 `auth_callback_page.dart`
   - 實作回調處理邏輯
   - 整合到路由系統

2. **實作其他提供商**
   - Facebook OAuth 回調
   - Apple OAuth 回調

3. **完善錯誤處理**
   - 實作用戶友好的錯誤提示
   - 添加重試機制
   - 實作日誌記錄

4. **生產環境部署**
   - 配置 HTTPS
   - 設定生產環境變數
   - 實作監控和警報

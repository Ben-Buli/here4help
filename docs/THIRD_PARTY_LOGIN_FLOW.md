# 🔐 第三方登入流程說明文檔

## 📋 概述
本文檔詳細說明 Here4Help 專案中第三方登入（Google、Facebook、Apple）的完整流程，包括登入、註冊和資料庫整合邏輯。

## 🔄 完整流程圖

```
用戶點擊第三方登入按鈕
         ↓
   前往第三方登入頁面
         ↓
   用戶授權並登入成功
         ↓
   獲取第三方用戶資料
         ↓
   發送到後端 API
         ↓
   檢查用戶是否存在
         ↓
   是 → 直接登入成功
   否 → 檢查 Email 是否已存在
         ↓
   Email 已存在 → 綁定第三方帳號
   Email 不存在 → 建立新用戶
         ↓
   返回登入結果
         ↓
   新用戶 → 導向註冊頁面
   現有用戶 → 直接進入首頁
```

## 🎯 核心邏輯

### 1. **用戶存在性檢查順序**

#### 第一優先：檢查 `user_identities` 表
```sql
SELECT ui.*, u.* FROM user_identities ui 
INNER JOIN users u ON ui.user_id = u.id 
WHERE ui.provider = 'google' AND ui.provider_user_id = ?
```

**結果**：
- ✅ **找到**：現有用戶，直接登入
- ❌ **未找到**：繼續下一步檢查

#### 第二優先：檢查 `users` 表的 Email
```sql
SELECT * FROM users WHERE email = ?
```

**結果**：
- ✅ **找到**：Email 已存在，建立 `user_identities` 綁定
- ❌ **未找到**：完全新用戶，建立完整帳號

### 2. **三種情況處理**

#### **情況 1：現有第三方登入用戶**
```
user_identities 表找到對應記錄
    ↓
更新 access_token 和最後登入時間
    ↓
返回用戶資料和 JWT Token
    ↓
前端直接進入首頁
```

#### **情況 2：Email 已存在的用戶**
```
users 表找到相同 Email
    ↓
建立新的 user_identities 記錄
    ↓
綁定第三方帳號到現有帳號
    ↓
返回用戶資料和 JWT Token
    ↓
前端直接進入首頁
```

#### **情況 3：完全新用戶**
```
users 表沒有相同 Email
    ↓
建立新的 users 記錄
    ↓
建立新的 user_identities 記錄
    ↓
返回用戶資料和 JWT Token
    ↓
前端導向註冊頁面完成資料
```

## 🔧 技術實作

### 1. **前端服務類**

#### **Google 登入服務**
```dart
class GoogleAuthService {
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    // 1. 觸發 Google 登入
    // 2. 獲取用戶資料
    // 3. 發送到後端
    // 4. 處理回應
  }
}
```

#### **統一第三方登入服務**
```dart
class ThirdPartyAuthService {
  Future<Map<String, dynamic>?> signInWithProvider(String provider) async {
    // 根據提供者調用對應服務
  }
}
```

### 2. **後端 API**

#### **Google 登入 API**
```php
// backend/api/auth/google-login.php
// 處理 Google 登入邏輯
```

#### **第三方註冊 API**
```php
// backend/api/auth/oauth-signup.php
// 完成新用戶註冊
```

### 3. **資料庫操作**

#### **檢查現有用戶**
```sql
-- 檢查 user_identities 表
SELECT ui.*, u.* FROM user_identities ui 
INNER JOIN users u ON ui.user_id = u.id 
WHERE ui.provider = ? AND ui.provider_user_id = ?
```

#### **建立新用戶**
```sql
-- 建立 users 記錄
INSERT INTO users (name, email, avatar_url, status, created_at, updated_at)
VALUES (?, ?, ?, 'active', NOW(), NOW())

-- 建立 user_identities 記錄
INSERT INTO user_identities (user_id, provider, provider_user_id, email, name, avatar_url, access_token, raw_profile, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
```

#### **綁定現有帳號**
```sql
-- 建立 user_identities 記錄，綁定到現有用戶
INSERT INTO user_identities (user_id, provider, provider_user_id, email, name, avatar_url, access_token, raw_profile, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
```

## 📱 前端流程控制

### 1. **登入頁面處理**

#### **Google 登入處理**
```dart
Future<void> _handleGoogleLogin() async {
  try {
    final userData = await _platformAuthService.signInWithGoogle();
    
    if (userData != null) {
      if (userData['is_new_user'] == true) {
        // 新用戶：儲存資料並導向註冊頁面
        await _saveGoogleDataForSignup(userData);
        context.go('/signup/oauth');
      } else {
        // 現有用戶：直接登入
        await _handleExistingUserLogin(userData);
        context.go('/home');
      }
    }
  } catch (e) {
    // 錯誤處理
  }
}
```

#### **資料暫存機制**
```dart
Future<void> _saveGoogleDataForSignup(Map<String, dynamic> userData) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('signup_full_name', userData['name'] ?? '');
  await prefs.setString('signup_email', userData['email'] ?? '');
  await prefs.setString('signup_avatar_url', userData['avatar_url'] ?? '');
  await prefs.setString('signup_provider', 'google');
  await prefs.setString('signup_provider_user_id', userData['provider_user_id'] ?? '');
}
```

### 2. **註冊頁面處理**

#### **OAuth 註冊頁面**
```dart
class OAuthSignupPage extends StatefulWidget {
  // 載入暫存的第三方登入資料
  // 預填表單欄位
  // 完成註冊流程
}
```

#### **資料載入**
```dart
Future<void> _loadOAuthData() async {
  final prefs = await SharedPreferences.getInstance();
  
  setState(() {
    fullNameController.text = prefs.getString('signup_full_name') ?? '';
    emailController.text = prefs.getString('signup_email') ?? '';
    avatarUrl = prefs.getString('signup_avatar_url');
    provider = prefs.getString('signup_provider');
    providerUserId = prefs.getString('signup_provider_user_id');
  });
}
```

## 🔒 安全性考量

### 1. **資料驗證**
- 前端輸入驗證
- 後端資料驗證
- SQL 注入防護
- XSS 防護

### 2. **Token 管理**
- JWT Token 生成
- Token 過期時間設定
- 安全的 Token 傳輸

### 3. **錯誤處理**
- 詳細的錯誤日誌
- 用戶友善的錯誤訊息
- 異常情況的優雅處理

## 📊 資料流程

### 1. **登入流程資料流**
```
Google 登入 → 獲取用戶資料 → 發送到後端 → 檢查資料庫 → 返回結果
```

### 2. **註冊流程資料流**
```
暫存資料 → 載入註冊頁面 → 用戶填寫資料 → 發送到後端 → 建立帳號 → 返回結果
```

### 3. **資料綁定流程**
```
檢查 Email → 找到現有帳號 → 建立 user_identity → 綁定完成
```

## 🧪 測試案例

### 1. **新用戶 Google 登入**
1. 點擊 Google 登入按鈕
2. 完成 Google 授權
3. 檢查是否導向註冊頁面
4. 驗證預填資料是否正確
5. 完成註冊流程

### 2. **現有用戶 Google 登入**
1. 點擊 Google 登入按鈕
2. 完成 Google 授權
3. 檢查是否直接進入首頁
4. 驗證用戶資料是否正確

### 3. **Email 衝突處理**
1. 使用已註冊的 Email 進行 Google 登入
2. 檢查是否正確綁定到現有帳號
3. 驗證綁定後的登入流程

## 🚀 部署注意事項

### 1. **環境配置**
- 確保所有第三方登入憑證已正確配置
- 檢查 API 端點是否可達
- 驗證資料庫連線是否正常

### 2. **資料庫準備**
- 確保 `user_identities` 表已建立
- 檢查外鍵約束是否正確
- 驗證索引是否建立

### 3. **監控和日誌**
- 啟用詳細的錯誤日誌
- 監控第三方登入成功率
- 追蹤用戶註冊完成率

## 📞 支援與聯絡

如有問題或需要協助，請聯繫開發團隊。

## 📝 更新記錄

- **2025-01-19**: 初始版本，完整的第三方登入流程說明
- **2025-01-19**: 新增資料庫整合邏輯和安全性考量

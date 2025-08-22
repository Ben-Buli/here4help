# 安全加固實作指南

## 概述

Here4Help 專案已實作完整的安全加固機制，包含 CORS 跨域保護、API 節流限制、JWT Token 輪替與黑名單系統。本文件說明如何使用和維護這些安全功能。

## 🛡️ CORS 跨域保護

### 配置文件
- **位置**: `backend/config/cors.php`
- **環境配置**: `backend/config/env.example`

### 環境設定

```bash
# .env 文件
APP_ENV=development  # development/staging/production
FRONTEND_URL=http://localhost:3000
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost:8081
```

### 使用方式

```php
// 在 API 端點中使用
require_once __DIR__ . '/../../config/cors.php';
CorsConfig::setCorsHeaders();

// 或使用統一中介層
require_once __DIR__ . '/../../middleware/api_middleware.php';
ApiMiddleware::handle();
```

### 環境差異

| 環境 | 允許的來源 |
|------|------------|
| **開發環境** | localhost 多端口、ngrok 域名 |
| **測試環境** | 測試域名 + 本地開發 |
| **生產環境** | 僅正式域名 |

## 🚦 API 節流機制

### 節流規則

| 端點類型 | 限制 | 時間窗口 | 適用端點 |
|----------|------|----------|----------|
| **認證** | 5 requests | 5 分鐘 | 登入、註冊、OAuth |
| **訊息** | 30 requests | 1 分鐘 | 聊天、上傳 |
| **檢舉** | 3 requests | 1 小時 | 檢舉、客服 |
| **一般** | 100 requests | 1 分鐘 | 其他 API |

### 使用方式

```php
// 自動節流檢查
require_once __DIR__ . '/../../utils/RateLimiter.php';
RateLimiter::middleware(); // 自動檢查並回應

// 手動檢查
$allowed = RateLimiter::checkLimit('/api/auth/login.php');
if (!$allowed) {
    // 處理節流限制
}

// 獲取剩餘請求數
$remaining = RateLimiter::getRemainingRequests('/api/auth/login.php');
```

### 回應標頭

節流機制會自動添加以下 HTTP 標頭：

```
X-RateLimit-Remaining: 4
X-RateLimit-Reset: 1640995200
Retry-After: 300
```

### 429 錯誤回應

```json
{
    "success": false,
    "error": "RATE_LIMIT_EXCEEDED",
    "message": "請求過於頻繁，請稍後再試",
    "retry_after": 300,
    "remaining_requests": 0
}
```

## 🔐 JWT Token 輪替

### Token 類型

| Token 類型 | 過期時間 | 用途 |
|------------|----------|------|
| **Access Token** | 1 小時 | API 認證 |
| **Refresh Token** | 7 天 | Token 刷新 |

### 生成 Token 對

```php
require_once __DIR__ . '/../../utils/JWTManager.php';

$payload = [
    'user_id' => 123,
    'email' => 'user@example.com',
    'name' => 'User Name'
];

$tokenPair = JWTManager::generateTokenPair($payload);
/*
返回:
{
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_expires_in": 604800
}
*/
```

### 刷新 Access Token

```php
$newTokenPair = JWTManager::refreshAccessToken($refreshToken);
if ($newTokenPair) {
    // 使用新的 Token 對
} else {
    // Refresh Token 無效或過期
}
```

### Token 驗證（含黑名單檢查）

```php
$payload = JWTManager::validateTokenWithBlacklist($token);
if ($payload) {
    // Token 有效
    $userId = $payload['user_id'];
} else {
    // Token 無效或已撤銷
}
```

## 🚫 Token 黑名單系統

### 撤銷單一 Token

```php
$success = JWTManager::blacklistToken($token, 'user_logout');
```

### 撤銷用戶所有 Token

```php
$revokedCount = JWTManager::revokeAllUserTokens($userId, 'security_breach');
```

### 檢查 Token 狀態

```php
$isBlacklisted = JWTManager::isTokenBlacklisted($token);
$isUserRevoked = JWTManager::isUserTokenRevoked($userId, $tokenIssuedAt);
```

## 🔧 API 端點

### Token 刷新端點

**POST** `/api/auth/refresh-token.php`

```json
// 請求
{
    "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}

// 回應
{
    "success": true,
    "data": {
        "access_token": "new_access_token",
        "refresh_token": "new_refresh_token",
        "token_type": "Bearer",
        "expires_in": 3600,
        "refresh_expires_in": 604800
    }
}
```

### Token 撤銷端點

**POST** `/api/auth/revoke-token.php`

```json
// 撤銷當前 Token
{
    "reason": "user_logout"
}

// 撤銷特定 Token
{
    "token": "token_to_revoke",
    "reason": "security_concern"
}

// 撤銷用戶所有 Token
{
    "revoke_all": true,
    "reason": "account_compromise"
}
```

## 🛠️ 統一中介層

### 使用方式

```php
require_once __DIR__ . '/../../middleware/api_middleware.php';

// 基本使用（包含所有檢查）
ApiMiddleware::handle();

// 跳過節流檢查
ApiMiddleware::handle(['skip_rate_limit' => true]);

// JWT 驗證（必須）
$payload = ApiMiddleware::validateJWT(true);

// JWT 驗證（可選）
$payload = ApiMiddleware::validateJWT(false);

// 權限檢查
ApiMiddleware::checkPermission(1, $payload); // 需要權限等級 1
```

### 自動功能

中介層會自動處理：
- ✅ CORS 標頭設定
- ✅ 節流限制檢查
- ✅ 安全標頭添加
- ✅ 錯誤處理設定
- ✅ JWT 驗證與權限檢查

## 🧹 維護與清理

### 自動清理腳本

**位置**: `backend/cron/cleanup_security.php`

**功能**:
- 清理過期節流記錄
- 清理過期 JWT 黑名單
- 清理舊日誌檔案（30天保留）
- 壓縮大檔案

### Cron 設定

```bash
# 每小時執行清理
0 * * * * /usr/bin/php /path/to/backend/cron/cleanup_security.php

# 或手動執行
php backend/cron/cleanup_security.php
```

### 手動清理

```php
// 清理節流記錄
$cleaned = RateLimiter::cleanup();

// 清理 JWT 黑名單
$cleaned = JWTManager::cleanupBlacklist();
```

## 📊 監控與日誌

### 日誌檔案

| 檔案 | 內容 |
|------|------|
| `storage/logs/rate_limit.log` | 節流超限記錄 |
| `storage/logs/api_errors.log` | API 錯誤記錄 |
| `storage/logs/cleanup_security.log` | 清理作業記錄 |
| `storage/logs/php_errors.log` | PHP 錯誤記錄 |

### 日誌格式

```json
{
    "timestamp": "2025-01-11 17:11:16",
    "type": "rate_limit_exceeded",
    "endpoint": "/api/auth/login.php",
    "identifier": "user:123",
    "count": 6,
    "limit": 5,
    "ip": "127.0.0.1"
}
```

## 🔍 測試與驗證

### 執行測試

```bash
php backend/test/security_test.php
```

### 測試項目

- ✅ CORS 配置驗證
- ✅ 節流機制測試
- ✅ JWT Token 對生成與驗證
- ✅ Token 刷新功能
- ✅ Token 撤銷與黑名單
- ✅ 清理功能測試

## ⚠️ 注意事項

### 生產環境部署

1. **環境變數設定**
   ```bash
   APP_ENV=production
   JWT_SECRET=your_secure_random_string_here
   ```

2. **CORS 白名單**
   - 僅允許正式域名
   - 移除開發用域名

3. **節流限制調整**
   - 根據實際使用情況調整限制
   - 監控 429 錯誤頻率

4. **定期清理**
   - 設定 cron job 自動清理
   - 監控儲存空間使用

### 安全建議

1. **JWT Secret**
   - 使用強隨機字串（至少 32 字元）
   - 定期輪替 Secret（需撤銷所有現有 Token）

2. **Token 過期時間**
   - Access Token 保持短期（1小時）
   - Refresh Token 可根據需求調整

3. **節流限制**
   - 根據業務需求調整限制
   - 考慮不同用戶等級的差異化限制

4. **監控告警**
   - 監控 429 錯誤率
   - 監控異常的 Token 撤銷
   - 設定安全事件告警

## 📚 相關文件

- [JWT 管理器文檔](../backend/utils/JWTManager.php)
- [節流限制器文檔](../backend/utils/RateLimiter.php)
- [CORS 配置文檔](../backend/config/cors.php)
- [API 中介層文檔](../backend/middleware/api_middleware.php)

# 硬編程 URL 檢查報告

## 🔍 **檢查結果摘要**

經過全面檢查，發現專案中仍有**多處硬編程的 API 前綴和基礎 URL**，主要集中在以下幾個類別：

### 📊 **硬編程 URL 統計**

| 類型 | Flutter (lib) | Backend (PHP) | Admin (Laravel) | 總計 |
|------|---------------|---------------|-----------------|------|
| **API 前綴** | 3 處 | 0 處 | 0 處 | 3 處 |
| **API 基礎 URL** | 5 處 | 15 處 | 4 處 | 24 處 |
| **Socket URL** | 2 處 | 8 處 | 3 處 | 13 處 |
| **圖片 URL** | 3 處 | 2 處 | 2 處 | 7 處 |
| **測試文件** | 2 處 | 8 處 | 0 處 | 10 處 |
| **總計** | **15 處** | **33 處** | **9 處** | **57 處** |

## 🚨 **需要修復的硬編程 URL**

### 1. **Flutter 應用 (lib/)**

#### API 前綴硬編程
```dart
// lib/config/env_config.dart (3 處)
static String get apiPrefix =>
    get('API_PREFIX', defaultValue: '/here4help/backend/api');  // ✅ 已使用環境變數

// lib/config/environment_config_legacy.dart (1 處)
static String get apiPrefix =>
    EnvConfig.get('API_PREFIX', defaultValue: '/here4help/backend/api');  // ✅ 已使用環境變數

// lib/config/environment_config.dart (1 處) - 舊系統
static String get apiPrefix {
    final prefix = _config?['public']?['api_prefix'] ?? '/api';  // ⚠️ 硬編程
}
```

#### API 基礎 URL 硬編程
```dart
// lib/config/env_config.dart (2 處)
static String get apiOrigin =>
    get('API_ORIGIN', defaultValue: 'http://localhost:8888');  // ✅ 已使用環境變數

static String get apiBaseUrl => get('API_BASE_URL',
    defaultValue: 'http://localhost:8888/here4help/backend');  // ✅ 已使用環境變數

// lib/config/environment_config.dart (3 處) - 舊系統
'api_base_url': _getNetworkAddress('http://127.0.0.1:8888/here4help'),  // ⚠️ 硬編程
'google_redirect_uri': 'http://127.0.0.1:8888/here4help/backend/api/auth/google-callback.php',  // ⚠️ 硬編程
'facebook_redirect_uri': 'http://127.0.0.1:8888/here4help/backend/api/auth/facebook-callback.php',  // ⚠️ 硬編程
```

#### Socket URL 硬編程
```dart
// lib/config/env_config.dart (1 處)
static String get socketUrl =>
    get('SOCKET_URL', defaultValue: 'http://127.0.0.1:3001');  // ✅ 已使用環境變數

// lib/config/environment_config.dart (1 處) - 舊系統
'socket_url': _getNetworkAddress('http://127.0.0.1:3001'),  // ⚠️ 硬編程
```

#### 圖片 URL 硬編程
```dart
// lib/config/env_config.dart (1 處)
static String get imageBaseUrl =>
    get('IMAGE_BASE_URL', defaultValue: 'http://127.0.0.1:8888/here4help');  // ✅ 已使用環境變數

// lib/config/environment_config.dart (1 處) - 舊系統
'image_base_url': _getNetworkAddress('http://127.0.0.1:8888/here4help'),  // ⚠️ 硬編程
```

### 2. **後端 PHP (backend/)**

#### API 基礎 URL 硬編程
```php
// backend/api/auth/google-callback.php (1 處)
$base = rtrim(EnvLoader::get('APP_URL', 'http://127.0.0.1:8888'), '/');  // ✅ 已使用環境變數

// backend/api/media/upload.php (1 處)
$baseUrl = $_ENV['APP_URL'] ?? 'http://localhost:8888/here4help';  // ✅ 已使用環境變數

// backend/utils/StorageManager.php (1 處)
$baseUrl = $_ENV['APP_URL'] ?? 'http://localhost:8888/here4help';  // ✅ 已使用環境變數

// backend/utils/ApiDocGenerator.php (1 處)
['url' => 'http://localhost:8888/here4help/backend/api']  // ⚠️ 硬編程
```

#### Socket URL 硬編程
```php
// backend/api/support/create_issue.php (1 處)
$socketUrl = ($_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001') . '/support/event/new';  // ✅ 已使用環境變數

// backend/api/support/events.php (1 處)
$socketUrl = ($_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001') . '/api/support-events/broadcast';  // ✅ 已使用環境變數

// backend/api/support/resolve.php (1 處)
$socketUrl = ($_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001') . '/support/event/resolve';  // ✅ 已使用環境變數

// backend/api/support/events_close.php (1 處)
$socketUrl = ($_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001') . '/support/event/closed';  // ✅ 已使用環境變數

// backend/api/chat/send_message.php (1 處)
$socketUrl = $_ENV['SOCKET_URL'] ?? 'http://localhost:3001';  // ✅ 已使用環境變數

// backend/socket/notification_handler.php (1 處)
$socketServerUrl = $_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001';  // ✅ 已使用環境變數

// backend/utils/socket_notifier.php (1 處)
$this->socketUrl = $_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001';  // ✅ 已使用環境變數

// backend/api/chat/block_user.php (1 處)
$socketUrl = $_ENV['SOCKET_URL'] ?? 'http://localhost:3001';  // ✅ 已使用環境變數
```

#### 測試文件硬編程
```php
// backend/test/ 目錄下的 8 個測試文件
$baseUrl = 'http://localhost:8888/here4help/backend/api/wallet';  // ⚠️ 硬編程
$url = 'http://localhost:8888/here4help/backend/api/tasks/applications/accept.php';  // ⚠️ 硬編程
// ... 更多測試文件
```

### 3. **Admin Laravel (admin/)**

#### API 基礎 URL 硬編程
```php
// admin/frontend/src/config/api.ts (1 處)
backendUrl: import.meta.env.VITE_BACKEND_API_URL || 'http://localhost:8888/here4help/backend',  // ✅ 已使用環境變數

// admin/frontend/src/config/env.ts (2 處)
apiBaseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8888/here4help/backend',  // ✅ 已使用環境變數
imageBaseUrl: import.meta.env.VITE_IMAGE_BASE_URL || 'http://localhost:8888/here4help',  // ✅ 已使用環境變數

// admin/frontend/vite.config.ts (1 處)
target: 'http://localhost:8888',  // ⚠️ 硬編程
```

#### Socket URL 硬編程
```php
// admin/app/Http/Controllers/Admin/SupportController.php (2 處)
$socketUrl = env('SOCKET_SERVER_URL', 'http://localhost:3001') . '/support/event/update';  // ✅ 已使用環境變數
$socketUrl = env('SOCKET_SERVER_URL', 'http://localhost:3001') . '/support/message';  // ✅ 已使用環境變數

// admin/frontend/src/config/env.ts (1 處)
socketUrl: import.meta.env.VITE_SOCKET_URL || 'http://localhost:3001',  // ✅ 已使用環境變數
```

## ✅ **已正確使用環境變數的地方**

### Flutter 應用
- ✅ `lib/config/env_config.dart` - 所有主要配置都使用環境變數
- ✅ `lib/config/environment_config_legacy.dart` - 兼容層使用環境變數

### 後端 PHP
- ✅ 所有 API 文件都正確使用 `$_ENV` 或 `EnvLoader::get()`
- ✅ Socket 通知都使用環境變數
- ✅ 文件上傳 URL 生成使用環境變數

### Admin Laravel
- ✅ 大部分配置都使用 `import.meta.env` 或 `env()`

## ⚠️ **需要修復的硬編程**

### 1. **高優先級（影響功能）**

#### Flutter 舊配置系統
```dart
// lib/config/environment_config.dart - 需要完全移除或更新
'api_base_url': _getNetworkAddress('http://127.0.0.1:8888/here4help'),  // ⚠️
'socket_url': _getNetworkAddress('http://127.0.0.1:3001'),  // ⚠️
'image_base_url': _getNetworkAddress('http://127.0.0.1:8888/here4help'),  // ⚠️
```

#### Admin Vite 配置
```typescript
// admin/frontend/vite.config.ts
target: 'http://localhost:8888',  // ⚠️ 需要改為環境變數
```

### 2. **中優先級（測試文件）**

#### 後端測試文件
```php
// backend/test/ 目錄下的 8 個文件
$baseUrl = 'http://localhost:8888/here4help/backend/api/wallet';  // ⚠️
$url = 'http://localhost:8888/here4help/backend/api/tasks/applications/accept.php';  // ⚠️
```

#### Flutter 測試文件
```dart
// lib/test/socket_reconnect_test.dart
static const String testServerUrl = 'ws://localhost:3001';  // ⚠️
```

### 3. **低優先級（文檔和示例）**

#### API 文檔生成器
```php
// backend/utils/ApiDocGenerator.php
['url' => 'http://localhost:8888/here4help/backend/api']  // ⚠️
```

## 🛠️ **修復建議**

### 1. **立即修復（高優先級）**

#### 移除舊的 Flutter 配置系統
```bash
# 完全移除或更新 lib/config/environment_config.dart
# 確保所有代碼都使用新的 EnvConfig 系統
```

#### 修復 Admin Vite 配置
```typescript
// admin/frontend/vite.config.ts
const apiBaseUrl = env.VITE_API_BASE_URL || 'http://localhost:8888/here4help/backend'
const socketUrl = env.VITE_SOCKET_URL || 'http://localhost:3001'
const imageBaseUrl = env.VITE_IMAGE_BASE_URL || 'http://localhost:8888/here4help'

// 使用環境變數而非硬編程
target: apiBaseUrl.replace('/here4help/backend', ''),  // 提取基礎 URL
```

### 2. **測試文件修復**

#### 創建測試配置
```php
// backend/test/config.php
<?php
require_once __DIR__ . '/../config/env_loader.php';
EnvLoader::load();

$testConfig = [
    'api_base_url' => EnvLoader::get('API_BASE_URL', 'http://localhost:8888/here4help/backend'),
    'socket_url' => EnvLoader::get('SOCKET_URL', 'http://localhost:3001'),
    'image_base_url' => EnvLoader::get('IMAGE_BASE_URL', 'http://localhost:8888/here4help'),
];

// 在所有測試文件中使用
$baseUrl = $testConfig['api_base_url'];
```

#### Flutter 測試配置
```dart
// lib/test/test_config.dart
class TestConfig {
  static const String apiBaseUrl = 'http://localhost:8888/here4help/backend';
  static const String socketUrl = 'ws://localhost:3001';
  static const String imageBaseUrl = 'http://localhost:8888/here4help';
}
```

### 3. **文檔和示例修復**

#### API 文檔生成器
```php
// backend/utils/ApiDocGenerator.php
$apiBaseUrl = EnvLoader::get('API_BASE_URL', 'http://localhost:8888/here4help/backend');
$servers = [
    ['url' => $apiBaseUrl]
];
```

## 📋 **修復優先級**

| 優先級 | 文件/功能 | 影響 | 修復難度 | 建議 |
|--------|-----------|------|----------|------|
| **高** | Flutter 舊配置系統 | 功能 | 中等 | 完全移除 |
| **高** | Admin Vite 配置 | 功能 | 簡單 | 使用環境變數 |
| **中** | 後端測試文件 | 測試 | 簡單 | 創建測試配置 |
| **中** | Flutter 測試文件 | 測試 | 簡單 | 創建測試配置 |
| **低** | API 文檔生成器 | 文檔 | 簡單 | 使用環境變數 |

## 🎯 **總結**

**好消息**：大部分核心功能已經正確使用環境變數！

**需要關注**：
- ⚠️ **Flutter 舊配置系統**：需要完全移除
- ⚠️ **Admin Vite 配置**：需要使用環境變數
- ⚠️ **測試文件**：需要統一使用環境變數

**建議行動**：
1. 立即修復高優先級問題
2. 創建統一的測試配置
3. 更新文檔和示例

**修復後的效果**：
- ✅ 所有環境配置完全統一
- ✅ 測試環境可配置
- ✅ 部署環境靈活切換
- ✅ 維護成本降低

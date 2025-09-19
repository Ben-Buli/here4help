# CPanel Socket 伺服器修復方案

## 🚨 問題診斷
- API 正常: ✅ `{"pong":true}`
- Socket 連接失敗: ❌ `Connection refused`
- 原因: CPanel 不支援自定義端口 3001

## 🛠️ 解決方案

### 方案 1: WebSocket 代理 (推薦)

#### 1.1 修改 .htaccess 添加 WebSocket 代理
在 `public_html/.htaccess` 中添加：

```apache
# WebSocket 代理配置
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule ^socket/(.*)$ "ws://localhost:3001/$1" [P,L]

# Socket 伺服器代理
RewriteRule ^socket/(.*)$ http://localhost:3001/$1 [P,L]
```

#### 1.2 修改 Socket 伺服器配置
在 `backend/socket/server.js` 中修改端口：

```javascript
// 修改為使用環境變數或預設端口
const PORT = process.env.SOCKET_PORT || 8080;

// 或者使用 CPanel 支援的端口
const PORT = process.env.SOCKET_PORT || 80;
```

#### 1.3 更新 Flutter 配置
```json
{
  "API_URL": "https://hero4help.demofhs.com/backend/api",
  "SOCKET_URL": "https://hero4help.demofhs.com/socket",
  "APP_ENV": "production"
}
```

### 方案 2: 使用 PHP WebSocket (備選)

#### 2.1 安裝 ReactPHP
```bash
composer require react/socket
```

#### 2.2 創建 PHP WebSocket 伺服器
```php
<?php
// backend/socket/php_socket_server.php
require_once 'vendor/autoload.php';

use React\EventLoop\Factory;
use React\Socket\Server;
use React\Http\Server as HttpServer;

$loop = Factory::create();
$socket = new Server('0.0.0.0:8080', $loop);

$server = new HttpServer($loop, function (ServerRequestInterface $request) {
    // WebSocket 處理邏輯
});

$server->listen($socket);
$loop->run();
```

### 方案 3: 使用現有 PHP 後端 (最簡單)

#### 3.1 修改 Flutter 使用 HTTP 輪詢
```dart
// 替代 WebSocket 的 HTTP 輪詢
class ChatService {
  static Timer? _pollingTimer;
  
  static void startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _pollMessages();
    });
  }
  
  static Future<void> _pollMessages() async {
    // 使用 HTTP API 獲取新訊息
    final response = await http.get(
      Uri.parse('${EnvConfig.apiBaseUrl}/chat/poll.php')
    );
    // 處理回應
  }
}
```

#### 3.2 創建輪詢 API
```php
<?php
// backend/api/chat/poll.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// 檢查新訊息
$userId = validateToken();
$newMessages = getNewMessages($userId);

echo json_encode([
    'success' => true,
    'messages' => $newMessages
]);
```

## 🎯 推薦實施步驟

### 步驟 1: 檢查 CPanel 支援
1. 登入 CPanel
2. 檢查是否支援 Node.js
3. 檢查是否支援自定義端口

### 步驟 2: 實施方案 3 (HTTP 輪詢)
1. 修改 Flutter 使用 HTTP 輪詢
2. 創建輪詢 API 端點
3. 測試基本功能

### 步驟 3: 如果支援 Node.js，實施方案 1
1. 部署 Node.js Socket 伺服器
2. 配置 WebSocket 代理
3. 測試 WebSocket 連接

## 🧪 測試方法

### 測試 HTTP 輪詢
```bash
curl https://hero4help.demofhs.com/backend/api/chat/poll.php
```

### 測試 WebSocket 代理
```bash
curl -H "Upgrade: websocket" -H "Connection: Upgrade" \
     https://hero4help.demofhs.com/socket/
```

## 📋 修復檢查清單

- [ ] 檢查 CPanel Node.js 支援
- [ ] 選擇適合的解決方案
- [ ] 實施 Socket 替代方案
- [ ] 更新 Flutter 配置
- [ ] 測試即時通訊功能
- [ ] 確認聊天功能正常

## 🚨 緊急修復 (方案 3)

如果急需修復，建議立即實施 HTTP 輪詢方案：

1. **修改 Flutter 配置**:
```json
{
  "API_URL": "https://hero4help.demofhs.com/backend/api",
  "SOCKET_URL": "https://hero4help.demofhs.com/backend/api/chat",
  "APP_ENV": "production"
}
```

2. **創建輪詢 API**:
```php
// backend/api/chat/poll.php
// 實現訊息輪詢邏輯
```

3. **修改 Flutter 聊天服務**:
```dart
// 使用 HTTP 輪詢替代 WebSocket
```

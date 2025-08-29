<?php
/**
 * Socket.IO 通知處理器
 * 用於接收後端發送的狀態更新通知並轉發給相關用戶
 */

require_once __DIR__ . '/../config/env_loader.php';

// 確保環境變數已載入
EnvLoader::load();

// 設置 CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

try {
    // 驗證請求
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $expectedToken = $_ENV['SOCKET_SERVER_TOKEN'] ?? 'your-socket-server-token';
    
    if (empty($authHeader) || !preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        throw new Exception('Authorization header required');
    }
    
    $token = $matches[1];
    if ($token !== $expectedToken) {
        throw new Exception('Invalid token');
    }
    
    // 解析請求數據
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON data');
    }
    
    $event = $input['event'] ?? '';
    $data = $input['data'] ?? [];
    $userIds = $input['userIds'] ?? [];
    
    if (empty($event)) {
        throw new Exception('Event is required');
    }
    
    // 記錄通知
    error_log("[SocketNotifier] Received notification: $event for users: " . implode(',', $userIds));
    
    // 這裡應該連接到 Socket.IO 服務器並發送事件
    // 由於我們沒有實際的 Socket.IO 服務器，這裡只是記錄
    // 在實際部署時，這裡會連接到 Socket.IO 服務器
    
    // 模擬發送成功
    $response = [
        'success' => true,
        'event' => $event,
        'userIds' => $userIds,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    http_response_code(200);
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("[SocketNotifier] Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
?>

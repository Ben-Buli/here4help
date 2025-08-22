<?php
/**
 * 通知觸發 API
 * 用於手動觸發通知事件
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/NotificationManager.php';

// 設定 CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('METHOD_NOT_ALLOWED', '僅支援 POST 請求');
    exit;
}

try {
    // JWT 驗證
    $jwt = JWTManager::validateToken();
    if (!$jwt['valid']) {
        Response::error('UNAUTHORIZED', $jwt['message']);
        exit;
    }
    
    $userId = $jwt['payload']['user_id'];
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('INVALID_JSON', '無效的 JSON 資料');
        exit;
    }
    
    // 驗證必要欄位
    $requiredFields = ['event_type', 'event_action', 'target_users'];
    foreach ($requiredFields as $field) {
        if (!isset($input[$field]) || empty($input[$field])) {
            Response::error('MISSING_FIELD', "缺少必要欄位: $field");
            exit;
        }
    }
    
    $eventType = $input['event_type'];
    $eventAction = $input['event_action'];
    $eventData = $input['event_data'] ?? [];
    $targetUsers = $input['target_users'];
    
    // 驗證事件類型
    $allowedEventTypes = ['task', 'chat', 'support', 'admin'];
    if (!in_array($eventType, $allowedEventTypes)) {
        Response::error('INVALID_EVENT_TYPE', '無效的事件類型');
        exit;
    }
    
    // 驗證目標使用者
    if (!is_array($targetUsers) || empty($targetUsers)) {
        Response::error('INVALID_TARGET_USERS', '目標使用者必須是非空陣列');
        exit;
    }
    
    // 權限檢查：只有管理員或事件相關使用者可以觸發通知
    if (!isAuthorizedToTrigger($userId, $eventType, $eventData)) {
        Response::error('FORBIDDEN', '沒有權限觸發此通知');
        exit;
    }
    
    // 觸發通知
    $notificationManager = new NotificationManager();
    $result = $notificationManager->triggerEvent($eventType, $eventAction, $eventData, $targetUsers);
    
    if ($result['success']) {
        Response::success([
            'message' => $result['message'],
            'queued_notifications' => $result['queued']
        ]);
    } else {
        Response::error('NOTIFICATION_FAILED', $result['message']);
    }
    
} catch (Exception $e) {
    Logger::logError('notification_trigger_failed', ['user_id' => $userId ?? null], $e);
    Response::error('INTERNAL_ERROR', '通知觸發失敗');
}

/**
 * 檢查是否有權限觸發通知
 */
function isAuthorizedToTrigger($userId, $eventType, $eventData) {
    // 管理員可以觸發所有通知
    if (isAdmin($userId)) {
        return true;
    }
    
    // 根據事件類型檢查權限
    switch ($eventType) {
        case 'task':
            // 任務相關：發布者或接受者可以觸發
            return isset($eventData['poster_id']) && $eventData['poster_id'] == $userId ||
                   isset($eventData['acceptor_id']) && $eventData['acceptor_id'] == $userId;
                   
        case 'chat':
            // 聊天相關：發送者可以觸發
            return isset($eventData['sender_id']) && $eventData['sender_id'] == $userId;
            
        case 'support':
            // 客服相關：事件建立者或管理員可以觸發
            return isset($eventData['user_id']) && $eventData['user_id'] == $userId;
            
        case 'admin':
            // 管理相關：只有管理員可以觸發
            return false;
            
        default:
            return false;
    }
}

/**
 * 檢查是否為管理員
 */
function isAdmin($userId) {
    try {
        $db = Database::getInstance()->getConnection();
        $sql = "SELECT COUNT(*) FROM users WHERE id = ? AND role = 'admin'";
        $stmt = $db->prepare($sql);
        $stmt->execute([$userId]);
        return $stmt->fetchColumn() > 0;
    } catch (Exception $e) {
        return false;
    }
}

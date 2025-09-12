<?php
/**
 * 客服事件結案 API
 * 
 * 功能：
 * - POST: 客戶結案事件
 * - 支援評分與評論
 * 
 * 路徑：/api/support/events/{id}/close
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // JWT 認證（支援 Header 或 URL 參數）
    $token = null;
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
    
    if ($authHeader && preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        $token = $matches[1];
    } elseif (isset($_GET['token'])) {
        $token = $_GET['token'];
    }
    
    if (!$token) {
        Response::error('Missing or invalid authorization header', 401);
    }
    $jwtManager = new JWTManager();
    $payload = $jwtManager->validateToken($token);
    
    if (!$payload) {
        Response::error('Invalid or expired token', 401);
    }
    
    $userId = $payload['user_id'];
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $eventId = $input['event_id'] ?? null;
    $rating = $input['rating'] ?? null;
    $review = trim($input['review'] ?? '');
    
    if (!$eventId) {
        Response::error('event_id is required', 400);
    }
    
    // 只強制 rating 必填，review 為可選
    if ($rating === null || $rating === '') {
        Response::error('Rating is required (1-5)', 400);
    }
    
    // Review 為可選，允許空字符串
    
    // 驗證評分範圍
    if ($rating < 1 || $rating > 5) {
        Response::error('Rating must be between 1 and 5', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取事件詳情
    $eventStmt = $db->prepare("
        SELECT se.*, scr.user_id, scr.admin_id
        FROM support_events se
        JOIN support_chat_rooms scr ON se.support_chat_room_id = scr.id
        WHERE se.id = ? AND scr.type = 'support'
    ");
    $eventStmt->execute([$eventId]);
    $event = $eventStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$event) {
        Response::error('Event not found', 404);
    }
    
    // 權限檢查：只有客戶可以結案
    if ($event['user_id'] != $userId) {
        Response::error('Only the customer can close this event', 403);
    }
    
    // 狀態檢查：只有 submitted 或 in_progress 狀態的事件可以被客戶結案
    if (!in_array($event['status'], ['submitted', 'in_progress'])) {
        Response::error('Only submitted or in_progress events can be closed by customer', 400);
    }
    
    try {
        $db->beginTransaction();
        
        // 更新事件狀態與評分
        $updateStmt = $db->prepare("
            UPDATE support_events 
            SET 
                status = 'resolved',
                closed_at = NOW(),
                rating = ?,
                review = ?,
                updated_at = NOW()
            WHERE id = ?
        ");
        $updateStmt->execute([$rating, $review, $eventId]);
        
        // 記錄狀態變更日誌
        $logStmt = $db->prepare("
            INSERT INTO support_event_logs (
                event_id,
                admin_id,
                old_status,
                new_status,
                created_at
            ) VALUES (?, NULL, ?, 'resolved', NOW())
        ");
        $logStmt->execute([$eventId, $event['status']]);
        
        $db->commit();
        
        // 觸發 Socket 事件通知
        try {
            $socketUrl = ($_ENV['SOCKET_SERVER_URL'] ?? 'http://localhost:3001') . '/support/event/closed';
            $socketData = [
                'chatRoomId' => $event['support_chat_room_id'],
                'eventId' => $eventId,
                'rating' => $rating,
                'review' => $review
            ];
            
            // 非阻塞式 Socket 通知
            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => 'Content-Type: application/json',
                    'content' => json_encode($socketData),
                    'timeout' => 1
                ]
            ]);
            
            @file_get_contents($socketUrl, false, $context);
        } catch (Exception $e) {
            error_log("Support Event Socket notification failed: " . $e->getMessage());
        }
        
        Response::success([
            'event_id' => $eventId,
            'status' => 'resolved',
            'rating' => $rating,
            'review' => $review,
            'message' => 'Event closed successfully'
        ]);
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log('Support Events Close API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}

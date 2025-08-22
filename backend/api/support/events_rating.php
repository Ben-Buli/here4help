<?php
/**
 * 客服事件評分 API
 * 
 * 功能：
 * - POST: 提交事件評分與評論
 * 
 * 路徑：/api/support/events/{id}/rating
 */

require_once '../../config/database.php';
require_once '../../utils/JWTManager.php';
require_once '../../utils/Response.php';

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
    // JWT 認證
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
    
    if (!$authHeader || !preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
        Response::error('Missing or invalid authorization header', 401);
    }
    
    $token = $matches[1];
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
    
    if (!$eventId || $rating === null) {
        Response::error('event_id and rating are required', 400);
    }
    
    // 驗證評分範圍
    if ($rating < 1 || $rating > 5) {
        Response::error('Rating must be between 1 and 5', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取事件詳情
    $eventStmt = $db->prepare("
        SELECT se.*, cr.creator_id, cr.participant_id
        FROM support_events se
        JOIN chat_rooms cr ON se.chat_room_id = cr.id
        WHERE se.id = ? AND cr.type = 'support'
    ");
    $eventStmt->execute([$eventId]);
    $event = $eventStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$event) {
        Response::error('Event not found', 404);
    }
    
    // 權限檢查：只有客戶可以評分
    if ($event['user_id'] != $userId) {
        Response::error('Only the customer can rate this event', 403);
    }
    
    // 狀態檢查：只有已結案的事件可以評分
    if (!in_array($event['status'], ['resolved', 'closed_by_customer'])) {
        Response::error('Only resolved or closed events can be rated', 400);
    }
    
    // 檢查是否已經評分過
    if ($event['rating'] !== null) {
        Response::error('This event has already been rated', 400);
    }
    
    try {
        $db->beginTransaction();
        
        // 更新事件評分
        $updateStmt = $db->prepare("
            UPDATE support_events 
            SET 
                rating = ?,
                review = ?,
                updated_at = NOW()
            WHERE id = ?
        ");
        $updateStmt->execute([$rating, $review, $eventId]);
        
        $db->commit();
        
        Response::success([
            'event_id' => $eventId,
            'rating' => $rating,
            'review' => $review,
            'message' => 'Rating submitted successfully'
        ]);
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log('Support Events Rating API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}

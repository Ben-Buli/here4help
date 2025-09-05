<?php
/**
 * 用戶客服事件列表 API
 * 
 * 獲取指定用戶的所有客服事件
 * 
 * 路徑：/api/support/user_events.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶身份（普通用戶或管理員）
    $adminStmt = $db->prepare("
        SELECT a.id, a.role_id, ar.name as role_name
        FROM admins a
        LEFT JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.user_id = ?
    ");
    $adminStmt->execute([$userId]);
    $admin = $adminStmt->fetch(PDO::FETCH_ASSOC);
    
    $isAdmin = ($admin && in_array($admin['role_name'], ['admin', 'super_admin']));
    
    // 根據用戶身份獲取不同的客服事件
    if ($isAdmin) {
        // 管理員：獲取所有被分配的客服事件
        $eventsStmt = $db->prepare("
            SELECT 
                se.id,
                se.title,
                se.description,
                se.status,
                se.rating,
                se.review,
                se.created_at,
                se.updated_at,
                se.support_chat_room_id,
                u.name as customer_name,
                COALESCE(a.full_name, a.username) as admin_name,
                cr.type as chat_room_type
            FROM support_events se
            LEFT JOIN users u ON se.user_id = u.id
            LEFT JOIN admins a ON se.admin_id = a.id
            LEFT JOIN chat_rooms cr ON se.support_chat_room_id = cr.id
            WHERE se.admin_id = ?
            ORDER BY se.created_at DESC
        ");
        $eventsStmt->execute([$admin['id']]);
    } else {
        // 普通用戶：獲取自己建立的客服事件
        $eventsStmt = $db->prepare("
            SELECT 
                se.id,
                se.title,
                se.description,
                se.status,
                se.rating,
                se.review,
                se.created_at,
                se.updated_at,
                se.support_chat_room_id,
                u.name as customer_name,
                COALESCE(a.full_name, a.username) as admin_name,
                cr.type as chat_room_type
            FROM support_events se
            LEFT JOIN users u ON se.user_id = u.id
            LEFT JOIN admins a ON se.admin_id = a.id
            LEFT JOIN chat_rooms cr ON se.support_chat_room_id = cr.id
            WHERE se.user_id = ?
            ORDER BY se.created_at DESC
        ");
        $eventsStmt->execute([$userId]);
    }
    $events = $eventsStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 為每個事件獲取歷程記錄
    foreach ($events as &$event) {
        $logsStmt = $db->prepare("
            SELECT 
                sel.old_status,
                sel.new_status,
                sel.created_at,
                COALESCE(a.full_name, a.username) as admin_name
            FROM support_event_logs sel
            LEFT JOIN admins a ON sel.admin_id = a.id
            WHERE sel.event_id = ?
            ORDER BY sel.created_at ASC
        ");
        $logsStmt->execute([$event['id']]);
        $event['logs'] = $logsStmt->fetchAll(PDO::FETCH_ASSOC);
    }
    
    // 統計資訊
    if ($isAdmin) {
        // 管理員統計
        $statsStmt = $db->prepare("
            SELECT 
                COUNT(*) as total_events,
                SUM(CASE WHEN status = 'submitted' THEN 1 ELSE 0 END) as submitted_count,
                SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
                SUM(CASE WHEN status = 'resolved' THEN 1 ELSE 0 END) as resolved_count
            FROM support_events 
            WHERE admin_id = ?
        ");
        $statsStmt->execute([$admin['id']]);
    } else {
        // 普通用戶統計
        $statsStmt = $db->prepare("
            SELECT 
                COUNT(*) as total_events,
                SUM(CASE WHEN status = 'submitted' THEN 1 ELSE 0 END) as submitted_count,
                SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
                SUM(CASE WHEN status = 'resolved' THEN 1 ELSE 0 END) as resolved_count
            FROM support_events 
            WHERE user_id = ?
        ");
        $statsStmt->execute([$userId]);
    }
    $stats = $statsStmt->fetch(PDO::FETCH_ASSOC);
    
    Response::success([
        'events' => $events,
        'stats' => $stats,
        'user_id' => $userId
    ]);
    
} catch (Exception $e) {
    error_log('User Events API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}

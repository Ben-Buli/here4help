<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

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
    
    // 檢查請求來源，決定查詢類型
    $viewType = $_GET['view_type'] ?? 'customer'; // 默認為客戶視角
    
    // 檢查用戶權限
    $userStmt = $db->prepare("SELECT permission FROM users WHERE id = ?");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 根據視圖類型決定查詢邏輯
    // 'admin' = Vue Admin Web 管理員後台視角
    // 'customer' = Flutter App 用戶視角（包括 permission=99 的用戶）
    $isAdminView = ($user['permission'] == 99 && $viewType === 'admin');
    
    // 根據視圖類型獲取不同的客服事件
    if ($isAdminView) {
        // Vue Admin Web 管理員後台視角：獲取接手的客服事件
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
                admin_u.name as admin_name,
                scr.type as chat_room_type
            FROM support_events se
            LEFT JOIN users u ON se.user_id = u.id
            LEFT JOIN users admin_u ON se.admin_id = admin_u.id
            LEFT JOIN support_chat_rooms scr ON se.support_chat_room_id = scr.id
            WHERE scr.admin_id = ?
            ORDER BY se.created_at DESC
        ");
        $eventsStmt->execute([$userId]);
    } else {
        // Flutter App 用戶視角：獲取自己創建的客服事件
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
                admin_u.name as admin_name,
                scr.type as chat_room_type
            FROM support_events se
            LEFT JOIN users u ON se.user_id = u.id
            LEFT JOIN users admin_u ON se.admin_id = admin_u.id
            LEFT JOIN support_chat_rooms scr ON se.support_chat_room_id = scr.id
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
    if ($isAdminView) {
        // Vue Admin Web 管理員後台統計：接手的客服事件
        $statsStmt = $db->prepare("
            SELECT 
                COUNT(*) as total_events,
                SUM(CASE WHEN se.status = 'submitted' THEN 1 ELSE 0 END) as submitted_count,
                SUM(CASE WHEN se.status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_count,
                SUM(CASE WHEN se.status = 'resolved' THEN 1 ELSE 0 END) as resolved_count
            FROM support_events se
            LEFT JOIN support_chat_rooms scr ON se.support_chat_room_id = scr.id
            WHERE scr.admin_id = ?
        ");
        $statsStmt->execute([$userId]);
    } else {
        // Flutter App 用戶統計：自己創建的客服事件
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

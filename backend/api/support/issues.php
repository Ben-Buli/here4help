<?php
/**
 * 管理員客服事件列表 API
 * 
 * 功能：
 * - 聚合查詢 chat_rooms + support_events + chat_messages
 * - 支援篩選：type, status, search, pagination
 * - 回傳欄位：room_id, type, status, title, user_name, user_email, last_message_at
 * 
 * 路徑：GET /api/support/issues.php
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

// 僅允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // JWT 認證 - 支援 Header 和 URL 參數
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? '';
    $token = null;
    
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
    
    // TODO: 檢查管理員權限
    // $adminId = $payload['user_id'];
    // 暫時跳過管理員權限檢查，實際部署時需要實作
    
    $db = Database::getInstance()->getConnection();
    
    // 解析查詢參數
    $type = $_GET['type'] ?? 'support'; // support, dispute, all
    $status = $_GET['status'] ?? ''; // submitted, in_progress, resolved
    $search = trim($_GET['search'] ?? '');
    $page = max(1, intval($_GET['page'] ?? 1));
    $perPage = max(1, min(100, intval($_GET['per_page'] ?? 15)));
    
    // 建構 WHERE 條件
    $whereConditions = [];
    $params = [];
    
    // 類型篩選
    if ($type !== 'all') {
        $whereConditions[] = "cr.type = ?";
        $params[] = $type;
    } else {
        $whereConditions[] = "cr.type IN ('support', 'dispute')";
    }
    
    // 狀態篩選
    if (!empty($status)) {
        $whereConditions[] = "latest_event.status = ?";
        $params[] = $status;
    }
    
    // 搜尋條件（標題或使用者名稱/信箱）
    if (!empty($search)) {
        $whereConditions[] = "(latest_event.title LIKE ? OR u.name LIKE ? OR u.email LIKE ?)";
        $searchParam = "%{$search}%";
        $params[] = $searchParam;
        $params[] = $searchParam;
        $params[] = $searchParam;
    }
    
    $whereClause = implode(' AND ', $whereConditions);
    
    // 計算總數
    $countSql = "
        SELECT COUNT(DISTINCT cr.id) as total
        FROM chat_rooms cr
        LEFT JOIN (
            SELECT 
                se1.support_chat_room_id,
                se1.id,
                se1.title,
                se1.status,
                se1.user_id,
                se1.admin_id,
                se1.created_at
            FROM support_events se1
            INNER JOIN (
                SELECT support_chat_room_id, MAX(created_at) as max_created_at
                FROM support_events
                GROUP BY support_chat_room_id
            ) se2 ON se1.support_chat_room_id = se2.support_chat_room_id 
                  AND se1.created_at = se2.max_created_at
        ) latest_event ON latest_event.support_chat_room_id = cr.id
        LEFT JOIN users u ON latest_event.user_id = u.id
        WHERE {$whereClause}
    ";
    
    $countStmt = $db->prepare($countSql);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 計算分頁
    $lastPage = ceil($total / $perPage);
    $offset = ($page - 1) * $perPage;
    
    // 主查詢：獲取事件列表
    $sql = "
        SELECT 
            cr.id as room_id,
            cr.type,
            latest_event.status,
            latest_event.title,
            latest_event.id as event_id,
            latest_event.admin_id,
            u.name as user_name,
            u.email as user_email,
            latest_event.created_at as event_created_at,
            last_message.last_message_at
        FROM chat_rooms cr
        LEFT JOIN (
            SELECT 
                se1.support_chat_room_id,
                se1.id,
                se1.title,
                se1.status,
                se1.user_id,
                se1.admin_id,
                se1.created_at
            FROM support_events se1
            INNER JOIN (
                SELECT support_chat_room_id, MAX(created_at) as max_created_at
                FROM support_events
                GROUP BY support_chat_room_id
            ) se2 ON se1.support_chat_room_id = se2.support_chat_room_id 
                  AND se1.created_at = se2.max_created_at
        ) latest_event ON latest_event.support_chat_room_id = cr.id
        LEFT JOIN users u ON latest_event.user_id = u.id
        LEFT JOIN (
            SELECT 
                room_id,
                MAX(created_at) as last_message_at
            FROM chat_messages
            GROUP BY room_id
        ) last_message ON last_message.room_id = cr.id
        WHERE {$whereClause}
        ORDER BY 
            CASE 
                WHEN latest_event.status = 'submitted' THEN 1
                WHEN latest_event.status = 'in_progress' THEN 2
                WHEN latest_event.status = 'resolved' THEN 3
                ELSE 4
            END,
            COALESCE(last_message.last_message_at, latest_event.created_at) DESC
        LIMIT {$perPage} OFFSET {$offset}
    ";
    
    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 格式化結果
    $formattedItems = array_map(function($item) {
        return [
            'room_id' => $item['room_id'],
            'type' => $item['type'],
            'status' => $item['status'] ?? 'unknown',
            'title' => $item['title'] ?? 'Untitled',
            'event_id' => $item['event_id'],
            'admin_id' => $item['admin_id'],
            'user_name' => $item['user_name'] ?? 'Unknown User',
            'user_email' => $item['user_email'] ?? '',
            'event_created_at' => $item['event_created_at'],
            'last_message_at' => $item['last_message_at'],
            // 判斷是否已被接手
            'is_claimed' => !empty($item['admin_id']),
            // 格式化時間顯示
            'last_message_at_formatted' => $item['last_message_at'] 
                ? date('Y-m-d H:i:s', strtotime($item['last_message_at']))
                : ($item['event_created_at'] 
                    ? date('Y-m-d H:i:s', strtotime($item['event_created_at']))
                    : null)
        ];
    }, $items);
    
    // 回傳結果
    Response::success([
        'items' => $formattedItems,
        'pagination' => [
            'current_page' => $page,
            'per_page' => $perPage,
            'total' => (int)$total,
            'last_page' => $lastPage,
            'from' => $total > 0 ? $offset + 1 : 0,
            'to' => min($offset + $perPage, $total)
        ],
        'filters' => [
            'type' => $type,
            'status' => $status,
            'search' => $search
        ]
    ]);
    
} catch (Exception $e) {
    error_log('Support Issues List API Error: ' . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

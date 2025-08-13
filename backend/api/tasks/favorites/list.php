<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 引入資料庫配置
require_once '../../config/database.php';

// 簡單的 token 驗證函數（使用 base64 編碼的 JSON）
function validateToken($token) {
    try {
        // 嘗試 base64 解碼
        $decoded = base64_decode($token);
        if ($decoded === false) {
            return null;
        }
        
        $payload = json_decode($decoded, true);
        if (!$payload) {
            return null;
        }
        
        // 檢查必要欄位
        if (!isset($payload['user_id']) || !isset($payload['exp'])) {
            return null;
        }
        
        // 檢查 token 是否過期
        if ($payload['exp'] < time()) {
            return null;
        }
        
        return $payload;
        
    } catch (Exception $e) {
        return null;
    }
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

try {
    $db = Database::getInstance();
    
    // Auth - 支援多種 token 傳遞方式
    $token = null;
    
    // 嘗試從 Authorization header 獲取
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        $token = $m[1];
    }
    // 備用方案：從 GET 參數獲取 token
    elseif (isset($_GET['token'])) {
        $token = $_GET['token'];
    }
    
    if (empty($token)) {
        throw new Exception('Authorization header required');
    }
    
    $payload = validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 取得分頁參數
    $limit = (int)($_GET['limit'] ?? 20);
    $offset = (int)($_GET['offset'] ?? 0);
    $limit = min($limit, 100); // 最大限制100筆
    
    // 查詢用戶收藏的任務
    $sql = "
        SELECT 
            t.*,
            tf.created_at as favorited_at,
            u.name as creator_name,
            u.avatar_url as creator_avatar,
            (SELECT COUNT(*) FROM task_applications ta WHERE ta.task_id = t.id) as applicant_count,
            ts.display_name as status_display,
            ts.code as status_code
        FROM task_favorites tf
        INNER JOIN tasks t ON tf.task_id = t.id
        LEFT JOIN users u ON t.creator_id = u.id
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE tf.user_id = ?
        ORDER BY tf.created_at DESC
        LIMIT ? OFFSET ?
    ";
    
    $stmt = $db->query($sql, [$userId, $limit, $offset]);
    $favoriteTasks = $stmt->fetchAll();
    
    // 為每個任務添加收藏狀態標記
    foreach ($favoriteTasks as &$task) {
        $task['is_favorited'] = true; // 這些都是收藏的任務
        $task['applicant_count'] = (int)$task['applicant_count'];
    }
    
    // 計算總數
    $countStmt = $db->query(
        "SELECT COUNT(*) as total FROM task_favorites WHERE user_id = ?", 
        [$userId]
    );
    $countResult = $countStmt->fetch();
    $total = (int)($countResult['total'] ?? 0);
    
    echo json_encode([
        'success' => true,
        'message' => 'Favorite tasks retrieved successfully',
        'data' => [
            'tasks' => $favoriteTasks,
            'pagination' => [
                'total' => $total,
                'limit' => $limit,
                'offset' => $offset,
                'has_more' => ($offset + $limit) < $total
            ]
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
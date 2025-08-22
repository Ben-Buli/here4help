<?php
/**
 * 任務收藏管理 API
 * 
 * 支援的操作：
 * - POST: 收藏任務
 * - DELETE: 取消收藏
 * - GET: 獲取用戶收藏列表
 * 
 * 路徑：/api/tasks/favorites
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
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
    
    // 根據 HTTP 方法分發處理
    switch ($_SERVER['REQUEST_METHOD']) {
        case 'GET':
            handleGetFavorites($db, $userId);
            break;
        case 'POST':
            handleAddFavorite($db, $userId);
            break;
        case 'DELETE':
            handleRemoveFavorite($db, $userId);
            break;
        default:
            Response::error('Method not allowed', 405);
    }
    
} catch (Exception $e) {
    error_log("Task Favorites API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}

/**
 * 獲取用戶收藏列表
 */
function handleGetFavorites($db, $userId) {
    try {
        $page = intval($_GET['page'] ?? 1);
        $perPage = intval($_GET['per_page'] ?? 20);
        $offset = ($page - 1) * $perPage;
        
        // 獲取收藏任務列表
        $sql = "
            SELECT 
                tf.id as favorite_id,
                tf.created_at as favorited_at,
                t.id as task_id,
                t.title,
                t.description,
                t.reward_points,
                t.status_code,
                ts.display_name as status_display,
                u.name as creator_name,
                u.avatar_url as creator_avatar,
                t.created_at as task_created_at,
                t.deadline
            FROM task_favorites tf
            INNER JOIN tasks t ON tf.task_id = t.id
            LEFT JOIN task_statuses ts ON t.status_code = ts.code
            LEFT JOIN users u ON t.creator_id = u.id
            WHERE tf.user_id = ?
            ORDER BY tf.created_at DESC
            LIMIT ? OFFSET ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$userId, $perPage, $offset]);
        $favorites = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 獲取總數
        $countSql = "SELECT COUNT(*) as total FROM task_favorites WHERE user_id = ?";
        $countStmt = $db->prepare($countSql);
        $countStmt->execute([$userId]);
        $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
        
        Response::success([
            'favorites' => $favorites,
            'pagination' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => intval($total),
                'total_pages' => ceil($total / $perPage)
            ]
        ]);
        
    } catch (Exception $e) {
        throw $e;
    }
}

/**
 * 收藏任務
 */
function handleAddFavorite($db, $userId) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $taskId = $input['task_id'] ?? null;
    
    if (!$taskId) {
        Response::error('task_id is required', 400);
    }
    
    try {
        // 檢查任務是否存在
        $taskStmt = $db->prepare("SELECT id, creator_id, status_code FROM tasks WHERE id = ?");
        $taskStmt->execute([$taskId]);
        $task = $taskStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$task) {
            Response::error('Task not found', 404);
        }
        
        // 檢查是否為自己的任務（不能收藏自己的任務）
        if ($task['creator_id'] == $userId) {
            Response::error('Cannot favorite your own task', 400);
        }
        
        // 檢查是否已經收藏
        $checkStmt = $db->prepare("SELECT id FROM task_favorites WHERE user_id = ? AND task_id = ?");
        $checkStmt->execute([$userId, $taskId]);
        
        if ($checkStmt->fetch()) {
            Response::error('Task already favorited', 400);
        }
        
        // 新增收藏記錄
        $insertStmt = $db->prepare("
            INSERT INTO task_favorites (user_id, task_id, created_at) 
            VALUES (?, ?, NOW())
        ");
        $insertStmt->execute([$userId, $taskId]);
        
        $favoriteId = $db->lastInsertId();
        
        // 記錄到 task_logs
        $logStmt = $db->prepare("
            INSERT INTO task_logs (
                task_id, 
                action, 
                user_id, 
                description, 
                created_at
            ) VALUES (?, 'task_favorited', ?, ?, NOW())
        ");
        $logStmt->execute([
            $taskId,
            $userId,
            "用戶收藏了任務"
        ]);
        
        Response::success([
            'favorite_id' => $favoriteId,
            'message' => 'Task favorited successfully'
        ]);
        
    } catch (Exception $e) {
        throw $e;
    }
}

/**
 * 取消收藏任務
 */
function handleRemoveFavorite($db, $userId) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $taskId = $input['task_id'] ?? null;
    
    if (!$taskId) {
        Response::error('task_id is required', 400);
    }
    
    try {
        // 檢查收藏是否存在
        $checkStmt = $db->prepare("SELECT id FROM task_favorites WHERE user_id = ? AND task_id = ?");
        $checkStmt->execute([$userId, $taskId]);
        $favorite = $checkStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$favorite) {
            Response::error('Favorite not found', 404);
        }
        
        // 刪除收藏記錄
        $deleteStmt = $db->prepare("DELETE FROM task_favorites WHERE user_id = ? AND task_id = ?");
        $deleteStmt->execute([$userId, $taskId]);
        
        // 記錄到 task_logs
        $logStmt = $db->prepare("
            INSERT INTO task_logs (
                task_id, 
                action, 
                user_id, 
                description, 
                created_at
            ) VALUES (?, 'task_unfavorited', ?, ?, NOW())
        ");
        $logStmt->execute([
            $taskId,
            $userId,
            "用戶取消收藏了任務"
        ]);
        
        Response::success([
            'message' => 'Task unfavorited successfully'
        ]);
        
    } catch (Exception $e) {
        throw $e;
    }
}
?>


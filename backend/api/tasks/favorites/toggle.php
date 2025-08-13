<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit();
}

try {
    $db = Database::getInstance();
    
    // 取得請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    // Auth - 支援多種 token 傳遞方式
    $token = null;
    
    // 嘗試從 Authorization header 獲取
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        $token = $m[1];
    }
    // 備用方案：從 JSON 輸入獲取 token
    elseif (isset($input['token'])) {
        $token = $input['token'];
    }
    
    if (empty($token)) {
        throw new Exception('Authorization header required');
    }
    
    $payload = validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    $taskId = $input['task_id'] ?? null;
    if (!$taskId) {
        throw new Exception('Task ID is required');
    }
    
    // 檢查任務是否存在
    $taskStmt = $db->query("SELECT id FROM tasks WHERE id = ?", [$taskId]);
    if (!$taskStmt->fetch()) {
        throw new Exception('Task not found');
    }
    
    // 檢查目前收藏狀態
    $favoriteStmt = $db->query(
        "SELECT id FROM task_favorites WHERE user_id = ? AND task_id = ?", 
        [$userId, $taskId]
    );
    $existingFavorite = $favoriteStmt->fetch();
    
    if ($existingFavorite) {
        // 已收藏 → 取消收藏
        $db->query(
            "DELETE FROM task_favorites WHERE user_id = ? AND task_id = ?", 
            [$userId, $taskId]
        );
        $isFavorited = false;
        $action = 'removed';
    } else {
        // 未收藏 → 添加收藏
        $db->query(
            "INSERT INTO task_favorites (user_id, task_id) VALUES (?, ?)", 
            [$userId, $taskId]
        );
        $isFavorited = true;
        $action = 'added';
    }
    
    // 取得該任務的總收藏數
    $countStmt = $db->query(
        "SELECT COUNT(*) as favorites_count FROM task_favorites WHERE task_id = ?", 
        [$taskId]
    );
    $countResult = $countStmt->fetch();
    $favoritesCount = $countResult['favorites_count'] ?? 0;
    
    echo json_encode([
        'success' => true,
        'message' => "Task {$action} successfully",
        'data' => [
            'task_id' => $taskId,
            'is_favorited' => $isFavorited,
            'favorites_count' => (int)$favoritesCount,
            'action' => $action
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
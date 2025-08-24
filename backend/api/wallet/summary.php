<?php
/**
 * GET /api/wallet/summary.php
 * Wallet summary API - Returns the user's total points, available points, and active tasks
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::error($tokenValidation['message'], 401);
    }
    $tokenData = $tokenValidation['payload'];
    $userId = $tokenData['user_id'];
    
    $db = Database::getInstance();
    
    // 1. 獲取用戶基本資訊和總點數
    $userQuery = "SELECT id, name, nickname, points FROM users WHERE id = ?";
    $user = $db->fetch($userQuery, [$userId]);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    $totalPoints = (int)$user['points'];
    
    // 2. 計算發布中任務佔用的點數
    // 根據 open_questions 回應：包含任務狀態 IN (1,2,3,4) 皆視為佔用
    $occupiedQuery = "
        SELECT COALESCE(SUM(CAST(reward_point AS SIGNED)), 0) as occupied_points
        FROM tasks 
        WHERE creator_id = ? 
        AND status_id IN (1, 2, 3, 4)
        AND reward_point IS NOT NULL 
        AND reward_point != ''
    ";
    
    $occupiedResult = $db->fetch($occupiedQuery, [$userId]);
    $occupiedPoints = (int)$occupiedResult['occupied_points'];
    
    // 3. 計算可用點數
    $availablePoints = max(0, $totalPoints - $occupiedPoints);
    
    // 4. 獲取發布中任務詳情（用於調試和驗證）
    $tasksQuery = "
        SELECT id, title, reward_point, status_id, created_at
        FROM tasks 
        WHERE creator_id = ? 
        AND status_id IN (1, 2, 3, 4, 5)
        ORDER BY created_at DESC
        LIMIT 10
    ";
    
    $activeTasks = $db->fetchAll($tasksQuery, [$userId]);
    
    // 5. 格式化任務數據
    $formattedTasks = array_map(function($task) {
        return [
            'id' => $task['id'],
            'title' => $task['title'],
            'reward_point' => (int)$task['reward_point'],
            'status_id' => (int)$task['status_id'],
            'created_at' => $task['created_at']
        ];
    }, $activeTasks);
    
    Response::success([
        'user_info' => [
            'id' => (int)$user['id'],
            'name' => $user['name'],
            'nickname' => $user['nickname']
        ],
        'points_summary' => [
            'total_points' => $totalPoints,
            'occupied_points' => $occupiedPoints,
            'available_points' => $availablePoints
        ],
        'active_tasks' => $formattedTasks,
        'active_tasks_count' => count($formattedTasks),
        'calculation_note' => 'Available points = Total points - Occupied points (tasks with status_id IN 1,2,3,4,5)'
    ], 'Wallet summary retrieved successfully');
    
} catch (Exception $e) {
    error_log("Wallet summary error: " . $e->getMessage());
    Response::error('Failed to retrieve wallet summary: ' . $e->getMessage(), 500);
}
?>

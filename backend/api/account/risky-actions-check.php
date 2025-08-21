<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

header('Content-Type: application/json');

try {
    // 驗證 JWT token
    $jwtManager = new JWTManager();
    $token = $_GET['token'] ?? null;
    
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 檢查是否有進行中的任務（作為參與者）
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM tasks 
        WHERE participant_id = ? 
        AND status_id IN (2, 3, 4) 
        AND deleted_at IS NULL
    ");
    $stmt->execute([$userId]);
    $activeTasks = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // 檢查是否有發布中的任務（作為創建者）
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM tasks 
        WHERE creator_id = ? 
        AND status_id IN (1, 2, 3, 4) 
        AND deleted_at IS NULL
    ");
    $stmt->execute([$userId]);
    $postedTasks = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // 檢查是否有未完成的聊天室
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM chat_rooms cr
        JOIN tasks t ON cr.task_id = t.id
        WHERE (cr.user1_id = ? OR cr.user2_id = ?)
        AND t.status_id IN (1, 2, 3, 4)
        AND t.deleted_at IS NULL
    ");
    $stmt->execute([$userId, $userId]);
    $activeChats = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $response = [
        'success' => true,
        'data' => [
            'has_active_tasks' => $activeTasks > 0,
            'has_posted_open_tasks' => $postedTasks > 0,
            'has_active_chats' => $activeChats > 0,
            'active_tasks_count' => $activeTasks,
            'posted_tasks_count' => $postedTasks,
            'active_chats_count' => $activeChats,
            'can_deactivate' => ($activeTasks == 0 && $postedTasks == 0),
            'risky_actions' => [
                'active_tasks' => $activeTasks,
                'posted_tasks' => $postedTasks,
                'active_chats' => $activeChats
            ]
        ]
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>

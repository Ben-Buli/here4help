<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    // 驗證 JWT token
    $jwtManager = new JWTManager();
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = str_replace('Bearer ', '', $authHeader);
    
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $raterId = $payload['user_id'];
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $taskId = $input['task_id'] ?? '';
    $taskerId = $input['tasker_id'] ?? '';
    $rating = (int)($input['rating'] ?? 0);
    $comment = $input['comment'] ?? null;
    
    // 驗證必要欄位
    if (empty($taskId)) {
        throw new Exception('Task ID is required');
    }
    
    if (empty($taskerId)) {
        throw new Exception('Tasker ID is required');
    }
    
    if ($rating < 1 || $rating > 5) {
        throw new Exception('Rating must be between 1 and 5');
    }
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    // 檢查任務是否存在且用戶有權限評價
    $taskCheckSql = "
        SELECT t.id, t.creator_id, ta.user_id as acceptor_id, ts.code as status_code
        FROM tasks t
        LEFT JOIN task_applications ta ON t.id = ta.task_id AND ta.status = 'accepted'
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE t.id = ?
    ";
    
    $stmt = $pdo->prepare($taskCheckSql);
    $stmt->execute([$taskId]);
    $task = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$task) {
        throw new Exception('Task not found');
    }
    
    // 檢查評價權限
    $canRate = false;
    if ($raterId == $task['creator_id'] && $taskerId == $task['acceptor_id']) {
        // 任務發布者評價接受者
        $canRate = true;
    } elseif ($raterId == $task['acceptor_id'] && $taskerId == $task['creator_id']) {
        // 任務接受者評價發布者
        $canRate = true;
    }
    
    if (!$canRate) {
        throw new Exception('You do not have permission to rate this task');
    }
    
    // 檢查任務狀態是否允許評價
    if (!in_array($task['status_code'], ['completed', 'cancelled'])) {
        throw new Exception('Task must be completed or cancelled to submit a review');
    }
    
    // 檢查是否已經評價過
    $existingRating = $pdo->prepare("
        SELECT id FROM task_ratings 
        WHERE task_id = ? AND rater_id = ? AND tasker_id = ?
    ");
    $existingRating->execute([$taskId, $raterId, $taskerId]);
    
    if ($existingRating->fetch()) {
        throw new Exception('You have already rated this task');
    }
    
    // 插入評價
    $insertSql = "
        INSERT INTO task_ratings (task_id, rater_id, tasker_id, rating, comment, created_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ";
    
    $stmt = $pdo->prepare($insertSql);
    $stmt->execute([$taskId, $raterId, $taskerId, $rating, $comment]);
    
    // 記錄操作日誌
    $logSql = "
        INSERT INTO user_activity_logs (user_id, action, details, ip_address, created_at)
        VALUES (?, 'task_review_submitted', ?, ?, NOW())
    ";
    
    $logStmt = $pdo->prepare($logSql);
    $logStmt->execute([
        $raterId, 
        json_encode([
            'task_id' => $taskId,
            'tasker_id' => $taskerId,
            'rating' => $rating,
            'has_comment' => !empty($comment)
        ]),
        $_SERVER['REMOTE_ADDR'] ?? 'unknown'
    ]);
    
    $response = [
        'success' => true,
        'message' => 'Review submitted successfully',
        'data' => [
            'task_id' => $taskId,
            'rating' => $rating,
            'comment' => $comment,
            'submitted_at' => date('Y-m-d H:i:s')
        ]
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>


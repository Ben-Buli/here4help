<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../auth_helper.php';

// CORS headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

try {
    // 驗證 JWT token（支援多種來源，以兼容 MAMP/FastCGI 環境）
    $jwtManager = new JWTManager();
    $authHeader = getAuthorizationHeader();
    $token = null;
    if ($authHeader && strpos($authHeader, 'Bearer ') === 0) {
        $token = trim(substr($authHeader, 7));
    }
    if (!$token) {
        // 查詢參數或 POST 體備援
        $token = $_GET['token'] ?? ($_POST['token'] ?? null);
    }
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 建立資料庫連線（啟用異常拋出與 utf8mb4）
    $pdo = new PDO(
        "mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'),
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4"
        ]
    );
    
    // 讀取使用者目前權限與狀態
    $stmt = $pdo->prepare("SELECT permission, status FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        throw new Exception('User not found');
    }
    
    // 應徵端：以 user_id + status（字串）計數，採用常用狀態
    $activeTasks = 0;
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) AS count FROM task_applications WHERE user_id = ? AND status IN ('pending','accepted')");
        $stmt->execute([$userId]);
        $activeTasks = (int)$stmt->fetchColumn();
    } catch (Exception $e) {
        // 退而求其次：若欄位不同，改用 applicant_id
        try {
            $stmt = $pdo->prepare("SELECT COUNT(*) AS count FROM task_applications WHERE applicant_id = ? AND status IN ('pending','accepted')");
            $stmt->execute([$userId]);
            $activeTasks = (int)$stmt->fetchColumn();
        } catch (Exception $e2) {
            $activeTasks = 0;
        }
    }

    // 發布端：多層回退，支援不同 schema
    $postedTasks = 0;
    try {
        // 1) tasks.status_code + task_statuses.code
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM tasks t JOIN task_statuses s ON t.status_code = s.code WHERE t.creator_id = ? AND s.code IN ('open','in_progress')");
        $stmt->execute([$userId]);
        $postedTasks = (int)$stmt->fetchColumn();
    } catch (Exception $e1) {
        try {
            // 2) tasks.status_id + task_statuses.name
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM tasks t JOIN task_statuses s ON t.status_id = s.id WHERE t.creator_id = ? AND s.name IN ('open','in_progress')");
            $stmt->execute([$userId]);
            $postedTasks = (int)$stmt->fetchColumn();
        } catch (Exception $e2) {
            try {
                // 3) 只有 tasks.status_code 字串
                $stmt = $pdo->prepare("SELECT COUNT(*) FROM tasks WHERE creator_id = ? AND status_code IN ('open','in_progress')");
                $stmt->execute([$userId]);
                $postedTasks = (int)$stmt->fetchColumn();
            } catch (Exception $e3) {
                try {
                    // 4) 只有 tasks.status_id 數字（舊版假設 open=1,in_progress=2）
                    $stmt = $pdo->prepare("SELECT COUNT(*) FROM tasks WHERE creator_id = ? AND status_id IN (1,2)");
                    $stmt->execute([$userId]);
                    $postedTasks = (int)$stmt->fetchColumn();
                } catch (Exception $e4) {
                    $postedTasks = 0;
                }
            }
        }
    }
      
    // 聊天室結構目前無 user1_id/user2_id 欄位，先回傳 0
    $activeChats = 0;
    
    $response = [
        'success' => true,
        'data' => [
            // 回傳使用者目前權限與狀態，供前端判斷顯示
            'permission' => isset($user['permission']) ? (int)$user['permission'] : null,
            'status' => $user['status'] ?? null,
            'has_active_tasks' => $activeTasks > 0,
            'has_posted_open_tasks' => $postedTasks > 0,
            'has_active_chats' => $activeChats > 0,
            'active_tasks_count' => $activeTasks,
            'posted_tasks_count' => $postedTasks,
            'active_chats_count' => $activeChats,
            'can_deactivate' => ($activeTasks === 0 && $postedTasks === 0),
            'risky_actions' => [
                'active_tasks' => $activeTasks,
                'posted_tasks' => $postedTasks,
                'active_chats' => $activeChats
            ]
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

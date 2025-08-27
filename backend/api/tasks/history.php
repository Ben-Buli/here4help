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
    $role = $_GET['role'] ?? 'poster'; // poster 或 acceptor
    $page = (int)($_GET['page'] ?? 1);
    $perPage = (int)($_GET['per_page'] ?? 20);
    $offset = ($page - 1) * $perPage;
    
    // 建立資料庫連線
    $pdo = new PDO("mysql:host=" . EnvLoader::get('DB_HOST') . ";dbname=" . EnvLoader::get('DB_NAME'), 
                   EnvLoader::get('DB_USERNAME'), EnvLoader::get('DB_PASSWORD'));
    
    if ($role === 'poster') {
        // 查詢發布的任務歷史
        $sql = "
            SELECT 
                t.id,
                t.title,
                t.description,
                t.reward_point,
                t.created_at,
                t.updated_at,
                ts.display_name as status_name,
                ts.code as status_code,
                ta.user_id as acceptor_id,
                u.name as acceptor_name,
                u.avatar_url as acceptor_avatar,
                CASE 
                    WHEN tr_poster.id IS NOT NULL THEN 1 
                    ELSE 0 
                END as has_reviewed_acceptor,
                CASE 
                    WHEN tr_acceptor.id IS NOT NULL THEN 1 
                    ELSE 0 
                END as has_been_reviewed,
                tr_poster.rating as my_rating,
                tr_poster.comment as my_comment,
                tr_acceptor.rating as received_rating,
                tr_acceptor.comment as received_comment,
                CASE 
                    WHEN ts.code IN ('completed', 'cancelled') AND tr_poster.id IS NULL AND ta.user_id IS NOT NULL THEN 1
                    ELSE 0
                END as can_review
            FROM tasks t
            LEFT JOIN task_statuses ts ON t.status_id = ts.id
            LEFT JOIN task_applications ta ON t.id = ta.task_id AND ta.status = 'accepted'
            LEFT JOIN users u ON ta.user_id = u.id
            LEFT JOIN task_ratings tr_poster ON t.id = tr_poster.task_id AND tr_poster.rater_id = ? AND tr_poster.tasker_id = ta.user_id
            LEFT JOIN task_ratings tr_acceptor ON t.id = tr_acceptor.task_id AND tr_acceptor.rater_id = ta.user_id AND tr_acceptor.tasker_id = ?
            WHERE t.creator_id = ?
            AND t.deleted_at IS NULL
            ORDER BY t.updated_at DESC
            LIMIT ? OFFSET ?
        ";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$userId, $userId, $userId, $perPage, $offset]);
        
    } else {
        // 查詢接受的任務歷史
        $sql = "
            SELECT 
                t.id,
                t.title,
                t.description,
                t.reward_point,
                t.created_at,
                t.updated_at,
                ts.display_name as status_name,
                ts.code as status_code,
                t.creator_id as poster_id,
                u.name as poster_name,
                u.avatar_url as poster_avatar,
                CASE 
                    WHEN tr_acceptor.id IS NOT NULL THEN 1 
                    ELSE 0 
                END as has_reviewed_poster,
                CASE 
                    WHEN tr_poster.id IS NOT NULL THEN 1 
                    ELSE 0 
                END as has_been_reviewed,
                tr_acceptor.rating as my_rating,
                tr_acceptor.comment as my_comment,
                tr_poster.rating as received_rating,
                tr_poster.comment as received_comment,
                CASE 
                    WHEN ts.code IN ('completed', 'cancelled') AND tr_acceptor.id IS NULL THEN 1
                    ELSE 0
                END as can_review
            FROM tasks t
            INNER JOIN task_applications ta ON t.id = ta.task_id AND ta.user_id = ? AND ta.status = 'accepted'
            LEFT JOIN task_statuses ts ON t.status_id = ts.id
            LEFT JOIN users u ON t.creator_id = u.id
            LEFT JOIN task_ratings tr_acceptor ON t.id = tr_acceptor.task_id AND tr_acceptor.rater_id = ? AND tr_acceptor.tasker_id = t.creator_id
            LEFT JOIN task_ratings tr_poster ON t.id = tr_poster.task_id AND tr_poster.rater_id = t.creator_id AND tr_poster.tasker_id = ?
            WHERE t.deleted_at IS NULL
            ORDER BY t.updated_at DESC
            LIMIT ? OFFSET ?
        ";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute([$userId, $userId, $userId, $perPage, $offset]);
    }
    
    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 計算總數
    if ($role === 'poster') {
        $countSql = "SELECT COUNT(*) as total FROM tasks WHERE creator_id = ? AND deleted_at IS NULL";
        $countStmt = $pdo->prepare($countSql);
        $countStmt->execute([$userId]);
    } else {
        $countSql = "
            SELECT COUNT(*) as total 
            FROM tasks t
            INNER JOIN task_applications ta ON t.id = ta.task_id AND ta.user_id = ? AND ta.status = 'accepted'
            WHERE t.deleted_at IS NULL
        ";
        $countStmt = $pdo->prepare($countSql);
        $countStmt->execute([$userId]);
    }
    
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    $totalPages = ceil($totalCount / $perPage);
    
    // 統計未評價數量
    $unreviewed_count = 0;
    foreach ($tasks as $task) {
        if ($task['can_review']) {
            $unreviewed_count++;
        }
    }
    
    $response = [
        'success' => true,
        'data' => [
            'tasks' => $tasks,
            'pagination' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total_count' => $totalCount,
                'total_pages' => $totalPages,
                'has_next' => $page < $totalPages,
                'has_prev' => $page > 1
            ],
            'stats' => [
                'total_tasks' => $totalCount,
                'unreviewed_count' => $unreviewed_count,
                'role' => $role
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

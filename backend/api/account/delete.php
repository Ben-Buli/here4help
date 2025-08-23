<?php
/// 操作帳號軟刪除
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/UserActiveLogger.php';

// CORS headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    // 驗證 JWT token - 支持多源讀取（Authorization header 和查詢參數）
    $jwtManager = new JWTManager();
    
    // 嘗試從 Authorization header 讀取
    $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    $token = str_replace('Bearer ', '', $authHeader);
    
    // 如果 header 中沒有 token，嘗試從查詢參數讀取（MAMP 兼容性）
    if (!$token) {
        $token = $_GET['token'] ?? $_POST['token'] ?? '';
    }
    
    if (!$token) {
        throw new Exception('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON input');
    }
    
    $confirmation = $input['confirmation'] ?? '';
    $reason = $input['reason'] ?? '';
    
    // 驗證必要欄位
    if ($confirmation !== 'DELETE') {
        throw new Exception('Please type "DELETE" to confirm account deletion');
    }
    
    // 建立資料庫連線（加入 port 與 charset，並設定 ERRMODE_EXCEPTION）
    $pdo = new PDO(
        "mysql:host=" . EnvLoader::get('DB_HOST') .
        ";port=" . EnvLoader::get('DB_PORT') .
        ";dbname=" . EnvLoader::get('DB_NAME') .
        ";charset=utf8mb4",
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
    
    // 查詢用戶資料
    $stmt = $pdo->prepare("SELECT permission, status FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        throw new Exception('User not found');
    }
    
    // 檢查用戶是否已被管理員停權
    if ($user['permission'] == -1 || $user['status'] == 'banned') {
        throw new Exception('Account is suspended by administrator. Please contact support for account deletion.');
    }
    
    // 檢查是否有活躍的任務
    $activeTasksStmt = $pdo->prepare("
        SELECT COUNT(*) as count FROM tasks t
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE (t.creator_id = ? OR EXISTS (
            SELECT 1 FROM task_applications ta 
            WHERE ta.task_id = t.id AND ta.user_id = ? AND ta.status = 'accepted'
        ))
        AND ts.code NOT IN ('completed', 'cancelled')
        AND t.deleted_at IS NULL
    ");
    $activeTasksStmt->execute([$userId, $userId]);
    $activeTasksCount = $activeTasksStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    if ($activeTasksCount > 0) {
        throw new Exception('Cannot delete account with active tasks. Please complete or cancel all active tasks first.');
    }
    
    // 檢查是否有活躍的聊天室
    $activeChatStmt = $pdo->prepare("
        SELECT COUNT(*) as count FROM chat_rooms cr
        WHERE (cr.user_id = ? OR cr.participant_id = ?)
        AND cr.status = 'active'
    ");
    $activeChatStmt->execute([$userId, $userId]);
    $activeChatCount = $activeChatStmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    if ($activeChatCount > 0) {
        throw new Exception('Cannot delete account with active chat rooms. Please close all active conversations first.');
    }
    
    // 開始資料庫交易
    $pdo->beginTransaction();
    try {
        // 先抓舊值，供後續異動紀錄使用
        $before = $user; // 已於上方查詢取得 permission/status
        
        // 軟刪除用戶（設置為自行軟刪除狀態）— 不寫入 deleted_at（目前資料表無此欄）
        $updateStmt = $pdo->prepare("
            UPDATE users 
            SET permission = -4,
                status = 'inactive',
                updated_at = NOW()
            WHERE id = ?
        ");
        $updateStmt->execute([$userId]);
    
        // 統一使用 UserActiveLogger 紀錄
        $ip  = $_SERVER['REMOTE_ADDR']        ?? null;
        $ua  = $_SERVER['HTTP_USER_AGENT']    ?? null;
        $rid = $_SERVER['HTTP_X_REQUEST_ID']  ?? null;
        $tid = $_SERVER['HTTP_X_TRACE_ID']    ?? null;
    
        $logger = new UserActiveLogger($pdo);

        // 1) 主要事件：soft_delete
        $logger->logAction(
            pdo: $pdo,
            userId:    $userId,
            actorType: 'user',
            actorId:   $userId,
            action:    'soft_delete',
            field:     null,
            oldValue:  null,
            newValue:  null,
            reason:    $reason ?: 'User self-deleted account',
            requestId: $rid,
            traceId:   $tid ?? null,
            metadata:  ['note' => 'Account soft-deleted by user']
        );

        // 2) 權限異動
        if ((string)$before['permission'] !== '-4') {
            $logger->logAction(
                pdo: $pdo,
                userId:    $userId,
                actorType: 'user',
                actorId:   $userId,
                action:    'permission_change',
                field:     'permission',
                oldValue:  (string)$before['permission'],
                newValue:  '-4',
                reason:    'auto by soft_delete',
                requestId: $rid,
                traceId:   $tid,
                metadata:  null
            );
        }
    
        // 3) 狀態異動
        if ($before['status'] !== 'inactive') {
            $logger->logAction(
                pdo: $pdo,
                userId:    $userId,
                actorType: 'user',
                actorId:   $userId,
                action:    'status_change',
                field:     'status',
                oldValue:  $before['status'],
                newValue:  'inactive',
                reason:    'auto by soft_delete',
                requestId: $rid,
                traceId:   $tid,
                metadata:  null
            );
        }
    
        // （選用）匿名化敏感資料：若政策要求立即匿名化，保留；否則可移除
        $anonymizeStmt = $pdo->prepare("
            UPDATE users 
            SET email = CONCAT('deleted_', id, '@deleted.local'),
                phone = NULL,
                avatar_url = NULL
            WHERE id = ?
        ");
        $anonymizeStmt->execute([$userId]);
    
        // 提交交易
        $pdo->commit();
    
        echo json_encode([
            'success' => true,
            'message' => 'Account deleted successfully',
            'data' => [
                'user_id'    => $userId,
                'permission' => -4,
                'status'     => 'inactive',
                'reason'     => $reason ?: 'User self-deleted account'
            ]
        ]);
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) { $pdo->rollBack(); }
        throw $e;
    }
    
} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO) {
        try {
            if ($pdo->inTransaction()) { $pdo->rollBack(); }
        } catch (Throwable $_) {}
    }
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>

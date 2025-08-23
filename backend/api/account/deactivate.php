<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/UserActiveLogger.php';
require_once __DIR__ . '/../../utils/ErrorCodes.php';
require_once __DIR__ . '/../../auth_helper.php';

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
        Response::badRequest('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        Response::unauthorized('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 建立資料庫連線
    $dbHost = EnvLoader::get('DB_HOST');
    if ($dbHost === 'localhost') { $dbHost = '127.0.0.1'; }
    $dbPort = EnvLoader::get('DB_PORT') ?: '3306';
    $dsn = "mysql:host={$dbHost};port={$dbPort};dbname=" . EnvLoader::get('DB_NAME') . ";charset=utf8mb4";

    $pdo = new PDO(
        $dsn,
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
    
    $stmt = $pdo->prepare("SELECT permission, status FROM users WHERE id = ?");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::notFound('User not found');
    }
    
    // 管理員控制的封鎖狀態：不允許自主停用
    if ($user['permission'] == -1 ) {
        Response::forbidden('Account is suspended or removed by administrator. Please contact customer service for assistance.');
    }

    // 已是自行停權/軟刪除：冪等成功
    if ($user['permission'] == -3 || $user['permission'] == -4) {
        Response::success([
            'user_id' => $userId,
            'permission' => $user['permission'],
            'status' => $user['status'],
        ], 'Account is already deactivated');
    }

    $oldPermission = (string)($user['permission']);

    // Step A: 檢查是否有發布中的任務（禁止停用） - 多層回退
    $activePosted = 0;
    try {
        // 1) tasks.status_code + task_statuses.code
        $postingTaskStmt = $pdo->prepare(
            "SELECT COUNT(*) FROM tasks t JOIN task_statuses s ON t.status_code = s.code WHERE t.creator_id = ? AND s.code IN ('open','in_progress')"
        );
        $postingTaskStmt->execute([$userId]);
        $activePosted = (int)$postingTaskStmt->fetchColumn();
    } catch (Exception $e1) {
        try {
            // 2) tasks.status_id + task_statuses.name
            $postingTaskStmt = $pdo->prepare(
                "SELECT COUNT(*) FROM tasks t JOIN task_statuses s ON t.status_id = s.id WHERE t.creator_id = ? AND s.name IN ('open','in_progress')"
            );
            $postingTaskStmt->execute([$userId]);
            $activePosted = (int)$postingTaskStmt->fetchColumn();
        } catch (Exception $e2) {
            try {
                // 3) 只有 tasks.status_code 字串
                $postingTaskStmt = $pdo->prepare(
                    "SELECT COUNT(*) FROM tasks WHERE creator_id = ? AND status_code IN ('open','in_progress')"
                );
                $postingTaskStmt->execute([$userId]);
                $activePosted = (int)$postingTaskStmt->fetchColumn();
            } catch (Exception $e3) {
                try {
                    // 4) 只有 tasks.status_id 數字（舊版假設 open=1,in_progress=2）
                    $postingTaskStmt = $pdo->prepare(
                        "SELECT COUNT(*) FROM tasks WHERE creator_id = ? AND status_id IN (1,2)"
                    );
                    $postingTaskStmt->execute([$userId]);
                    $activePosted = (int)$postingTaskStmt->fetchColumn();
                } catch (Exception $e4) {
                    $activePosted = 0;
                }
            }
        }
    }

    // Step B: 檢查是否有執行中的任務（禁止停用） - 多層回退
    $activeExecuting = 0;
    try {
        // 以 user_id + status 字串
        $executingTaskStmt = $pdo->prepare(
            "SELECT COUNT(*) FROM task_applications WHERE user_id = ? AND status IN ('pending','accepted','dispute')"
        );
        $executingTaskStmt->execute([$userId]);
        $activeExecuting = (int)$executingTaskStmt->fetchColumn();
    } catch (Exception $e1) {
        try {
            // 回退 applicant_id + status 字串
            $executingTaskStmt = $pdo->prepare(
                "SELECT COUNT(*) FROM task_applications WHERE applicant_id = ? AND status IN ('pending','accepted','dispute')"
            );
            $executingTaskStmt->execute([$userId]);
            $activeExecuting = (int)$executingTaskStmt->fetchColumn();
        } catch (Exception $e2) {
            try {
                // 回退 user_id + status_id 數字（舊版假設 1=pending,2=accepted,4=dispute）
                $executingTaskStmt = $pdo->prepare(
                    "SELECT COUNT(*) FROM task_applications WHERE user_id = ? AND status_id IN (1,2,4)"
                );
                $executingTaskStmt->execute([$userId]);
                $activeExecuting = (int)$executingTaskStmt->fetchColumn();
            } catch (Exception $e3) {
                $activeExecuting = 0;
            }
        }
    }

    if ($activePosted > 0 || $activeExecuting > 0) {
        Response::error(
            ErrorCodes::ACCOUNT_DEACTIVATION_BLOCKED,
            null,
            [
                'posted_open_tasks' => $activePosted,
                'executing_tasks' => $activeExecuting,
            ]
        );
    }
    
    // 使用交易保證一致性
    $pdo->beginTransaction();

    // 更新用戶權限為自主停用（permission = -3），不修改 status
    $upd = $pdo->prepare(
        "UPDATE users SET permission = -3, updated_at = NOW() WHERE id = ?"
    );
    $upd->execute([$userId]);

    // 將使用者投遞中的應徵撤銷：嘗試多種欄位/狀態名稱
    $withdrawnCount = 0;
    try {
        $withdraw = $pdo->prepare(
            "UPDATE task_applications SET status = 'withdrawn' WHERE user_id = ? AND status = 'pending'"
        );
        $withdraw->execute([$userId]);
        $withdrawnCount = $withdraw->rowCount();
    } catch (Exception $e1) {
        // 回退 applicant_id
        try {
            $withdraw = $pdo->prepare(
                "UPDATE task_applications SET status = 'withdrawn' WHERE applicant_id = ? AND status = 'pending'"
            );
            $withdraw->execute([$userId]);
            $withdrawnCount = $withdraw->rowCount();
        } catch (Exception $e2) {
            // 回退：如果舊資料使用 applied 名稱
            try {
                $withdraw = $pdo->prepare(
                    "UPDATE task_applications SET status = 'withdrawn' WHERE user_id = ? AND status = 'applied'"
                );
                $withdraw->execute([$userId]);
                $withdrawnCount = $withdraw->rowCount();
            } catch (Exception $e3) {
                // 最後回退 applicant_id + applied
                try {
                    $withdraw = $pdo->prepare(
                        "UPDATE task_applications SET status = 'withdrawn' WHERE applicant_id = ? AND status = 'applied'"
                    );
                    $withdraw->execute([$userId]);
                    $withdrawnCount = $withdraw->rowCount();
                } catch (Exception $e4) {
                    $withdrawnCount = 0;
                }
            }
        }
    }

    // 記錄操作日誌
    $rid = $_SERVER['HTTP_X_REQUEST_ID'] ?? null;
    $tid = $_SERVER['HTTP_X_TRACE_ID'] ?? null;
    
    // 1) 高階語意事件：deactivate
    UserActiveLogger::logAction(
        $pdo,
        $userId,
        'deactivate',
        null,
        null,
        null,
        'User self-deactivated account',
        'user',
        $userId,
        $rid,
        $tid,
        [
            'withdrawn_applications' => (int)$withdrawnCount,
            'deactivated_at' => date('Y-m-d H:i:s')
        ]
    );

    // 2) 欄位變更：permission
    if ($oldPermission !== '-3') {
        UserActiveLogger::logAction(
            $pdo,
            $userId,
            'permission_change',
            'permission',
            $oldPermission,
            '-3',
            'Auto changed by deactivate action',
            'user',
            $userId,
            $rid,
            $tid
        );
    }

    $pdo->commit();
    
    Response::success([
        'user_id' => $userId,
        'permission' => -3,
        'status' => $user['status'], // 保持原狀態不變
        'deactivated_at' => date('Y-m-d H:i:s'),
        'withdrawn_applications' => (int)$withdrawnCount
    ], 'Account has been deactivated successfully. You can reactivate it anytime from the security settings.');
    
} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    Response::badRequest($e->getMessage());
}
?>

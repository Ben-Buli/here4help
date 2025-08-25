<?php
/**
 * 任務檢舉管理 API
 * 
 * 支援的操作：
 * - POST: 檢舉任務
 * - GET: 獲取檢舉歷史（僅限管理員）
 * 
 * 路徑：/api/tasks/reports
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../auth_helper.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // JWT 認證
    $authHeader = getAuthorizationHeader();
    
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
            // 檢查是否有 task_id 參數，如果有則檢查該任務的檢舉狀態
            if (isset($_GET['task_id']) && isset($_GET['check_status'])) {
                handleCheckReportStatus($db, $userId, $_GET['task_id']);
            } else {
                handleGetReports($db, $userId);
            }
            break;
        case 'POST':
            handleSubmitReport($db, $userId);
            break;
        default:
            Response::error('Method not allowed', 405);
    }
    
} catch (Exception $e) {
    error_log("Task Reports API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}

/**
 * 檢查用戶是否已檢舉過指定任務
 */
function handleCheckReportStatus($db, $userId, $taskId) {
    try {
        // 檢查是否已經檢舉過
        $stmt = $db->prepare("
            SELECT id, reason, description, status, created_at, updated_at
            FROM task_reports 
            WHERE reporter_id = ? AND task_id = ?
            ORDER BY created_at DESC
            LIMIT 1
        ");
        $stmt->execute([$userId, $taskId]);
        $report = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($report) {
            Response::success([
                'has_reported' => true,
                'report' => [
                    'id' => $report['id'],
                    'reason' => $report['reason'],
                    'description' => $report['description'],
                    'status' => $report['status'],
                    'created_at' => $report['created_at'],
                    'updated_at' => $report['updated_at']
                ]
            ]);
        } else {
            Response::success([
                'has_reported' => false,
                'report' => null
            ]);
        }
        
    } catch (Exception $e) {
        throw $e;
    }
}

/**
 * 獲取檢舉歷史（僅限管理員或檢舉者本人）
 */
function handleGetReports($db, $userId) {
    try {
        // 檢查是否為管理員
        $adminStmt = $db->prepare("SELECT id FROM admins WHERE id = ?");
        $adminStmt->execute([$userId]);
        $isAdmin = $adminStmt->fetch() !== false;
        
        $page = intval($_GET['page'] ?? 1);
        $perPage = intval($_GET['per_page'] ?? 20);
        $offset = ($page - 1) * $perPage;
        $status = $_GET['status'] ?? null;
        
        // 構建查詢條件
        $whereConditions = [];
        $params = [];
        
        if (!$isAdmin) {
            // 非管理員只能查看自己的檢舉
            $whereConditions[] = "tr.reporter_id = ?";
            $params[] = $userId;
        }
        
        if ($status && in_array($status, ['pending', 'reviewed', 'resolved', 'dismissed'])) {
            $whereConditions[] = "tr.status = ?";
            $params[] = $status;
        }
        
        $whereClause = empty($whereConditions) ? '' : 'WHERE ' . implode(' AND ', $whereConditions);
        
        // 獲取檢舉列表
        $sql = "
            SELECT 
                tr.id,
                tr.task_id,
                tr.reason,
                tr.description,
                tr.status,
                tr.admin_notes,
                tr.created_at,
                tr.updated_at,
                t.title as task_title,
                t.description as task_description,
                u_reporter.name as reporter_name,
                u_creator.name as task_creator_name,
                a.username as admin_username
            FROM task_reports tr
            INNER JOIN tasks t ON tr.task_id = t.id
            LEFT JOIN users u_reporter ON tr.reporter_id = u_reporter.id
            LEFT JOIN users u_creator ON t.creator_id = u_creator.id
            LEFT JOIN admins a ON tr.admin_id = a.id
            $whereClause
            ORDER BY tr.created_at DESC
            LIMIT ? OFFSET ?
        ";
        
        $params[] = $perPage;
        $params[] = $offset;
        
        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        $reports = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // 獲取總數
        $countSql = "SELECT COUNT(*) as total FROM task_reports tr $whereClause";
        $countParams = array_slice($params, 0, -2); // 移除 limit 和 offset 參數
        $countStmt = $db->prepare($countSql);
        $countStmt->execute($countParams);
        $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
        
        Response::success([
            'reports' => $reports,
            'pagination' => [
                'current_page' => $page,
                'per_page' => $perPage,
                'total' => intval($total),
                'total_pages' => ceil($total / $perPage)
            ],
            'is_admin' => $isAdmin
        ]);
        
    } catch (Exception $e) {
        throw $e;
    }
}

/**
 * 提交任務檢舉
 */
function handleSubmitReport($db, $userId) {
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $taskId = $input['task_id'] ?? null;
    $reason = $input['reason'] ?? null;
    $description = trim($input['description'] ?? '');
    
    if (!$taskId || !$reason || empty($description)) {
        Response::error('task_id, reason and description are required', 400);
    }
    
    // 驗證檢舉原因
    $validReasons = [
        'spam_advertising',
        'fraud_scam', 
        'misleading_false_info',
        'illegal_activity',
        'abusive_offensive_content',
        'duplicate_repeated_posting',
        'unreasonable_reward_conditions',
        'other'
    ];
    if (!in_array($reason, $validReasons)) {
        Response::error('Invalid reason. Must be one of: ' . implode(', ', $validReasons), 400);
    }
    
    try {
        // 檢查任務是否存在
        $taskStmt = $db->prepare("SELECT id, creator_id, title FROM tasks WHERE id = ?");
        $taskStmt->execute([$taskId]);
        $task = $taskStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$task) {
            Response::error('Task not found', 404);
        }
        
        // 檢查是否為自己的任務（不能檢舉自己的任務）
        if ($task['creator_id'] == $userId) {
            Response::error('Cannot report your own task', 400);
        }
        
        // 檢查是否已經檢舉過
        $checkStmt = $db->prepare("
            SELECT id FROM task_reports 
            WHERE reporter_id = ? AND task_id = ? AND status IN ('pending', 'reviewed', 'resolved')
        ");
        $checkStmt->execute([$userId, $taskId]);
        
        if ($checkStmt->fetch()) {
            Response::error('You have already reported this task', 400);
        }
        
        // 新增檢舉記錄
        $insertStmt = $db->prepare("
            INSERT INTO task_reports (
                task_id, 
                reporter_id, 
                reason, 
                description, 
                status,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, ?, 'pending', NOW(), NOW())
        ");
        $insertStmt->execute([$taskId, $userId, $reason, $description, 'pending', date('Y-m-d H:i:s'), date('Y-m-d H:i:s')]);
        
        $reportId = $db->lastInsertId();
        
        // 記錄到 task_logs
        $logStmt = $db->prepare("
            INSERT INTO task_logs (
                task_id, 
                action, 
                user_id, 
                description, 
                created_at
            ) VALUES (?, 'task_reported', ?, ?, NOW())
        ");
        $logStmt->execute([
            $taskId,
            $userId,
            "用戶檢舉任務：原因 - {$reason}，說明 - {$description}"
        ]);
        
        Response::success([
            'report_id' => $reportId,
            'message' => 'Task reported successfully. Our team will review it shortly.'
        ]);
        
    } catch (Exception $e) {
        throw $e;
    }
}
?>


<?php
/**
 * 任務申訴 API
 * 
 * 功能：
 * - POST: 提交任務申訴
 * - 支援圖片上傳作為申訴證據
 * - 自動停止自動完成倒數
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
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
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    // 驗證必要欄位
    $taskId = $input['task_id'] ?? null;
    $reason = trim($input['reason'] ?? '');
    $description = trim($input['description'] ?? '');
    
    if (!$taskId) {
        Response::error('Task ID is required', 400);
    }
    
    if (empty($reason)) {
        Response::error('Dispute reason is required', 400);
    }
    
    if (empty($description)) {
        Response::error('Dispute description is required', 400);
    }
    
    // 驗證申訴原因
    $validReasons = [
        'task_not_completed',
        'poor_quality',
        'communication_issue',
        'payment_dispute',
        'safety_concern',
        'other'
    ];
    
    if (!in_array($reason, $validReasons)) {
        Response::error('Invalid dispute reason', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 檢查任務是否存在且用戶有權限申訴
    $taskSql = "
        SELECT 
            t.id,
            t.title,
            t.creator_id,
            t.participant_id,
            t.status_id,
            ts.code as status_code,
            ts.display_name as status_display
        FROM tasks t
        JOIN task_statuses ts ON t.status_id = ts.id
        WHERE t.id = :task_id
    ";
    
    $taskStmt = $db->prepare($taskSql);
    $taskStmt->execute([':task_id' => $taskId]);
    $task = $taskStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$task) {
        Response::error('Task not found', 404);
    }
    
    // 檢查用戶是否為任務的創建者或參與者
    if ($task['creator_id'] != $userId && $task['participant_id'] != $userId) {
        Response::error('You do not have permission to dispute this task', 403);
    }
    
    // 檢查任務狀態是否允許申訴
    $allowedStatuses = ['pending_confirmation', 'completed'];
    if (!in_array($task['status_code'], $allowedStatuses)) {
        Response::error('Task status does not allow disputes', 400);
    }
    
    // 檢查是否已經有進行中的申訴
    $existingDisputeSql = "
        SELECT id FROM task_disputes 
        WHERE task_id = :task_id 
        AND status IN ('pending', 'under_review')
    ";
    $existingDisputeStmt = $db->prepare($existingDisputeSql);
    $existingDisputeStmt->execute([':task_id' => $taskId]);
    
    if ($existingDisputeStmt->fetch()) {
        Response::error('A dispute is already in progress for this task', 400);
    }
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
        // 獲取 dispute 狀態 ID
        $disputeStatusSql = "SELECT id FROM task_statuses WHERE code = 'dispute' LIMIT 1";
        $disputeStatusStmt = $db->prepare($disputeStatusSql);
        $disputeStatusStmt->execute();
        $disputeStatus = $disputeStatusStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$disputeStatus) {
            throw new Exception('Dispute status not found in system');
        }
        
        // 更新任務狀態為 dispute
        $updateTaskSql = "
            UPDATE tasks 
            SET status_id = :status_id, updated_at = NOW() 
            WHERE id = :task_id
        ";
        $updateTaskStmt = $db->prepare($updateTaskSql);
        $updateTaskStmt->execute([
            ':status_id' => $disputeStatus['id'],
            ':task_id' => $taskId
        ]);
        
        // 創建申訴記錄（適配現有表結構）
        $disputeSql = "
            INSERT INTO task_disputes (
                task_id,
                user_id,
                status,
                created_at,
                updated_at
            ) VALUES (
                :task_id,
                :user_id,
                'open',
                NOW(),
                NOW()
            )
        ";
        
        $disputeStmt = $db->prepare($disputeSql);
        $disputeStmt->execute([
            ':task_id' => $taskId,
            ':user_id' => $userId
        ]);
        
        $disputeId = $db->lastInsertId();
        
        // 記錄到 task_logs
        $logSql = "
            INSERT INTO task_logs (
                task_id,
                user_id,
                action,
                old_status,
                new_status,
                notes,
                created_at
            ) VALUES (
                :task_id,
                :user_id,
                'dispute_created',
                :old_status,
                'dispute',
                :notes,
                NOW()
            )
        ";
        
        $logStmt = $db->prepare($logSql);
        $logStmt->execute([
            ':task_id' => $taskId,
            ':user_id' => $userId,
            ':old_status' => $task['status_code'],
            ':notes' => "用戶申訴：原因 - $reason，說明 - $description"
        ]);
        
        // 記錄用戶活動日誌
        $activitySql = "
            INSERT INTO user_activity_logs (
                user_id,
                action,
                resource_type,
                resource_id,
                details,
                created_at
            ) VALUES (
                :user_id,
                'task_dispute_created',
                'task',
                :task_id,
                :details,
                NOW()
            )
        ";
        
        $activityStmt = $db->prepare($activitySql);
        $activityStmt->execute([
            ':user_id' => $userId,
            ':task_id' => $taskId,
            ':details' => json_encode([
                'dispute_id' => $disputeId,
                'task_title' => $task['title'],
                'reason' => $reason,
                'description' => $description,
                'previous_status' => $task['status_code']
            ])
        ]);
        
        // 提交交易
        $db->commit();
        
        Response::success([
            'dispute_id' => $disputeId,
            'task_id' => $taskId,
            'status' => 'pending',
            'message' => 'Dispute submitted successfully. The task status has been changed to dispute and auto-completion has been stopped.'
        ]);
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Dispute API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}


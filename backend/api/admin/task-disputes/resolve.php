<?php
/**
 * 管理員爭議決策
 * PATCH /api/admin/task-disputes/{id}/resolve.php
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/UserActiveLogger.php';

header('Content-Type: application/json');
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'PATCH') {
    Response::methodNotAllowed('Only PATCH method is allowed');
}

try {
    // JWT 認證
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::unauthorized($tokenData['message']);
    }

    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::forbidden('Admin access required');
    }
    
    // 獲取爭議ID (從URL路徑或參數)
    $disputeId = $_GET['id'] ?? null;
    if (!$disputeId) {
        Response::badRequest('Dispute ID is required');
    }
    
    // 獲取 PATCH 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }
    
    $decisionResult = $input['decision_result'] ?? null;
    $decisionNote = trim($input['decision_note'] ?? '');
    
    // 驗證決策結果
    $allowedDecisions = ['completed', 'back_to_progress', 'reset'];
    if (!$decisionResult || !in_array($decisionResult, $allowedDecisions)) {
        Response::badRequest('Invalid decision_result. Must be one of: ' . implode(', ', $allowedDecisions));
    }
    
    if (empty($decisionNote)) {
        Response::badRequest('Decision note is required');
    }
    
    // 資料庫連接
    $db = Database::getInstance()->getConnection();
    
    // 驗證管理員角色
    $adminCheck = $db->prepare("
        SELECT ar.name as role_name, a.username
        FROM admins a
        JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.id = ?
    ");
    $adminCheck->execute([$adminId]);
    $admin = $adminCheck->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin || !in_array($admin['role_name'], ['admin', 'super_admin'])) {
        Response::forbidden('Insufficient permissions to resolve disputes');
    }
    
    $db->beginTransaction();
    
    try {
        // 獲取爭議詳情
        $disputeQuery = $db->prepare("
            SELECT 
                tde.*,
                t.creator_id,
                t.participant_id,
                t.status_id as current_task_status,
                t.reward_point,
                t.title as task_title
            FROM task_dispute_events tde
            JOIN tasks t ON tde.task_id = t.id
            WHERE tde.id = ? AND tde.status != 'resolved'
        ");
        $disputeQuery->execute([$disputeId]);
        $dispute = $disputeQuery->fetch(PDO::FETCH_ASSOC);
        
        if (!$dispute) {
            Response::notFound('Dispute not found or already resolved');
        }
        
        $taskId = $dispute['task_id'];
        $chatRoomId = $dispute['task_dispute_chat_room_id'];
        $creatorId = $dispute['creator_id'];
        $participantId = $dispute['participant_id'];
        $oldStatus = $dispute['status'];
        
        // 更新爭議狀態
        $updateDispute = $db->prepare("
            UPDATE task_dispute_events 
            SET 
                status = 'resolved',
                decision_result = ?,
                decision_note = ?,
                admin_id = ?,
                updated_at = NOW()
            WHERE id = ?
        ");
        $updateDispute->execute([$decisionResult, $decisionNote, $adminId, $disputeId]);
        
        // 根據決策結果處理任務狀態
        switch ($decisionResult) {
            case 'completed':
                // 判定任務完成 - 重用現有的點數轉移邏輯
                $this->processTaskCompletion($db, $taskId, $creatorId, $participantId, $dispute['reward_point']);
                
                // 更新任務狀態
                $updateTask = $db->prepare("UPDATE tasks SET status_id = 5, updated_at = NOW() WHERE id = ?");
                $updateTask->execute([$taskId]);
                
                // 更新應徵記錄
                $updateApplication = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'completed', updated_at = NOW() 
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplication->execute([$taskId, $participantId]);
                
                $systemMessageContent = "Admin Resolution Result: completed\nDescription: {$decisionNote}\n\nIssue Status: resolved\nLast Update Time: " . date('Y-m-d H:i:s');
                break;
                
            case 'back_to_progress':
                // 回歸進行中
                $updateTask = $db->prepare("UPDATE tasks SET status_id = 2, updated_at = NOW() WHERE id = ?");
                $updateTask->execute([$taskId]);
                
                $updateApplication = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'accepted', updated_at = NOW() 
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplication->execute([$taskId, $participantId]);
                
                $systemMessageContent = "Admin Resolution Result: back_to_progress\nDescription: {$decisionNote}\n\nIssue Status: resolved\nLast Update Time: " . date('Y-m-d H:i:s');
                break;
                
            case 'reset':
                // 重置任務
                $updateTask = $db->prepare("
                    UPDATE tasks 
                    SET status_id = 1, participant_id = NULL, updated_at = NOW() 
                    WHERE id = ?
                ");
                $updateTask->execute([$taskId]);
                
                // 原執行者標記為拒絕
                $updateApplication = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'rejected', updated_at = NOW() 
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplication->execute([$taskId, $participantId]);
                
                $systemMessageContent = "Admin Resolution Result: reset\nDescription: {$decisionNote}\n\nIssue Status: resolved\nLast Update Time: " . date('Y-m-d H:i:s');
                break;
        }
        
        // 記錄爭議事件日誌
        $logEvent = $db->prepare("
            INSERT INTO task_dispute_event_logs (
                event_id,
                admin_id,
                old_status,
                new_status,
                old_decision,
                new_decision,
                note,
                created_at
            ) VALUES (?, ?, ?, 'resolved', NULL, ?, ?, NOW())
        ");
        $logEvent->execute([
            $disputeId,
            $adminId,
            $oldStatus,
            $decisionResult,
            "Admin decision: {$decisionNote}"
        ]);
        
        // 記錄管理員操作
        UserActiveLogger::logAction(
            $db, 
            $adminId, 
            'dispute_resolved',
            'dispute_status', 
            $oldStatus, 
            'resolved',
            "Dispute resolved with decision: {$decisionResult}",
            'admin', 
            $adminId, 
            null, 
            null,
            [
                'dispute_id' => $disputeId,
                'task_id' => $taskId,
                'decision_result' => $decisionResult
            ]
        );
        
        // 發送系統訊息到聊天室
        $systemMessage = $db->prepare("
            INSERT INTO chat_messages (
                room_id,
                from_user_id,
                content,
                kind,
                created_at
            ) VALUES (?, ?, ?, 'system', NOW())
        ");
        
        $systemMessage->execute([
            $chatRoomId,
            $adminId, // 使用管理員ID作為發送者
            $systemMessageContent
        ]);
        
        $db->commit();
        
        Response::success([
            'dispute_id' => (int)$disputeId,
            'decision_result' => $decisionResult,
            'status' => 'resolved',
            'admin_username' => $admin['username'],
            'resolved_at' => date('Y-m-d H:i:s')
        ], 'Dispute resolved successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }

} catch (PDOException $e) {
    error_log("Database error in resolve dispute: " . $e->getMessage());
    Response::serverError('Database error occurred');
} catch (Exception $e) {
    error_log("Error in resolve dispute: " . $e->getMessage());
    Response::serverError('An error occurred while resolving dispute: ' . $e->getMessage());
}

/**
 * 處理任務完成的點數轉移 (重用現有邏輯)
 */
function processTaskCompletion($db, $taskId, $creatorId, $participantId, $rewardPoint) {
    // 這裡應該重用 backend/api/tasks/confirm_completion.php 的邏輯
    // 為了簡化，這裡提供基本實現，實際應該抽取共用函數
    
    // 獲取手續費設定
    $feeQuery = $db->prepare("SELECT fee_percentage FROM task_completion_points_fee_settings LIMIT 1");
    $feeQuery->execute();
    $feeSettings = $feeQuery->fetch(PDO::FETCH_ASSOC);
    $feePercentage = $feeSettings ? floatval($feeSettings['fee_percentage']) : 0.05; // 預設5%
    
    // 計算手續費和淨收入
    $feeAmount = floor($rewardPoint * $feePercentage);
    $netEarning = $rewardPoint - $feeAmount;
    
    // 更新用戶點數
    $updateCreatorPoints = $db->prepare("
        UPDATE users 
        SET points = points - ? - ?, updated_at = NOW() 
        WHERE id = ?
    ");
    $updateCreatorPoints->execute([$rewardPoint, $feeAmount, $creatorId]);
    
    $updateParticipantPoints = $db->prepare("
        UPDATE users 
        SET points = points + ?, updated_at = NOW() 
        WHERE id = ?
    ");
    $updateParticipantPoints->execute([$netEarning, $participantId]);
    
    // 記錄點數交易 (簡化版本)
    $logTransaction = $db->prepare("
        INSERT INTO point_transactions (
            user_id, type, amount, description, 
            related_task_id, created_at
        ) VALUES 
        (?, 'task_spending', ?, 'Task reward payment', ?, NOW()),
        (?, 'task_earning', ?, 'Task completion reward', ?, NOW()),
        (?, 'fee_payment', ?, 'Task completion fee', ?, NOW())
    ");
    
    $logTransaction->execute([
        $creatorId, -$rewardPoint, $taskId,
        $participantId, $netEarning, $taskId,
        $creatorId, -$feeAmount, $taskId
    ]);
    
    // 記錄手續費收入
    $logFeeRevenue = $db->prepare("
        INSERT INTO fee_revenue_ledger (
            task_id, creator_id, participant_id, 
            reward_amount, fee_amount, created_at
        ) VALUES (?, ?, ?, ?, ?, NOW())
    ");
    
    $logFeeRevenue->execute([
        $taskId, $creatorId, $participantId, 
        $rewardPoint, $feeAmount
    ]);
}
?>

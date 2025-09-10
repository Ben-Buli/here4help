<?php
/**
 * 管理員處理任務爭議
 * POST /api/admin/task-disputes/resolve
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $disputeId = $input['dispute_id'] ?? '';
    $decision = $input['decision'] ?? '';
    $note = trim($input['note'] ?? '');
    
    if (empty($disputeId)) {
        Response::error('Dispute ID is required', 400);
    }
    
    if (empty($decision)) {
        Response::error('Decision is required', 400);
    }
    
    // 驗證決定值
    $allowedDecisions = ['completed', 'reject', 'restart'];
    if (!in_array($decision, $allowedDecisions)) {
        Response::error('Invalid decision. Allowed values: ' . implode(', ', $allowedDecisions), 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 檢查爭議是否存在
        $disputeStmt = $db->prepare("
            SELECT tde.*, t.creator_id, t.participant_id, t.reward, t.title as task_title
            FROM task_dispute_events tde
            JOIN tasks t ON tde.task_id = t.id
            WHERE tde.id = ?
        ");
        $disputeStmt->execute([$disputeId]);
        $dispute = $disputeStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$dispute) {
            Response::error('Dispute not found', 404);
        }
        
        // 檢查爭議狀態
        if ($dispute['status'] === 'resolved') {
            Response::error('Dispute has already been resolved', 409);
        }
        
        $taskId = $dispute['task_id'];
        $creatorId = $dispute['creator_id'];
        $participantId = $dispute['participant_id'];
        $reward = $dispute['reward'];
        
        // 根據決定執行不同的邏輯
        switch ($decision) {
            case 'completed':
                // 任務判定完成，轉移點數
                
                // 1. 更新任務狀態為已完成
                $updateTaskStmt = $db->prepare("
                    UPDATE tasks 
                    SET status_id = (SELECT id FROM task_statuses WHERE code = 'completed'),
                        updated_at = NOW()
                    WHERE id = ?
                ");
                $updateTaskStmt->execute([$taskId]);
                
                // 2. 更新應徵者狀態為已完成
                $updateApplicationStmt = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'completed', updated_at = NOW()
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplicationStmt->execute([$taskId, $participantId]);
                
                // 3. 轉移點數：從創建者轉給參與者
                if ($participantId && $reward > 0) {
                    // 扣除創建者點數
                    $deductStmt = $db->prepare("
                        UPDATE users 
                        SET points = points - ? 
                        WHERE id = ? AND points >= ?
                    ");
                    $deductStmt->execute([$reward, $creatorId, $reward]);
                    
                    if ($deductStmt->rowCount() === 0) {
                        throw new Exception('創建者點數不足');
                    }
                    
                    // 增加參與者點數
                    $addStmt = $db->prepare("
                        UPDATE users 
                        SET points = points + ? 
                        WHERE id = ?
                    ");
                    $addStmt->execute([$reward, $participantId]);
                    
                    // 記錄點數交易
                    $transactionStmt = $db->prepare("
                        INSERT INTO point_transactions (
                            user_id, transaction_type, amount, description, 
                            related_user_id, admin_id, created_at
                        ) VALUES (?, 'task_reward', ?, ?, ?, ?, NOW())
                    ");
                    $transactionStmt->execute([
                        $participantId,
                        $reward,
                        "任務完成獎勵 - 任務ID: {$taskId}",
                        $creatorId,
                        $adminId
                    ]);
                    
                    // 記錄創建者的點數扣除
                    $deductTransactionStmt = $db->prepare("
                        INSERT INTO point_transactions (
                            user_id, transaction_type, amount, description, 
                            related_user_id, admin_id, created_at
                        ) VALUES (?, 'task_payment', ?, ?, ?, ?, NOW())
                    ");
                    $deductTransactionStmt->execute([
                        $creatorId,
                        -$reward,
                        "任務完成付款 - 任務ID: {$taskId}",
                        $participantId,
                        $adminId
                    ]);
                }
                break;
                
            case 'reject':
                // 駁回爭議，任務回到進行中
                
                // 更新任務狀態為進行中
                $updateTaskStmt = $db->prepare("
                    UPDATE tasks 
                    SET status_id = (SELECT id FROM task_statuses WHERE code = 'in_progress'),
                        updated_at = NOW()
                    WHERE id = ?
                ");
                $updateTaskStmt->execute([$taskId]);
                
                // 更新應徵者狀態為進行中
                $updateApplicationStmt = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'in_progress', updated_at = NOW()
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplicationStmt->execute([$taskId, $participantId]);
                break;
                
            case 'restart':
                // 重新開始，移除參與者
                
                // 1. 更新任務狀態為開放，移除參與者
                $updateTaskStmt = $db->prepare("
                    UPDATE tasks 
                    SET status_id = (SELECT id FROM task_statuses WHERE code = 'open'),
                        participant_id = NULL,
                        updated_at = NOW()
                    WHERE id = ?
                ");
                $updateTaskStmt->execute([$taskId]);
                
                // 2. 更新應徵者狀態為被拒絕
                $updateApplicationStmt = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'rejected', updated_at = NOW()
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplicationStmt->execute([$taskId, $participantId]);
                break;
        }
        
        // 更新爭議狀態為已解決
        $updateDisputeStmt = $db->prepare("
            UPDATE task_dispute_events 
            SET status = 'resolved',
                decision_result = ?,
                decision_note = ?,
                admin_id = ?,
                updated_at = NOW()
            WHERE id = ?
        ");
        $updateDisputeStmt->execute([$decision, $note, $adminId, $disputeId]);
        
        // 記錄管理員操作日誌
        $logStmt = $db->prepare("
            INSERT INTO admin_activity_logs (
                admin_id, action, target_type, target_id, description, created_at
            ) VALUES (?, 'resolve_task_dispute', 'task_dispute_event', ?, ?, NOW())
        ");
        $logStmt->execute([
            $adminId,
            $disputeId,
            "Admin resolved task dispute {$disputeId} with decision: {$decision}"
        ]);
        
        // 提交事務
        $db->commit();
        
        $actionMessages = [
            'completed' => '任務已標記為完成，點數轉移完成',
            'reject' => '爭議已駁回，任務回到進行中狀態',
            'restart' => '任務已重新開始，參與者已移除'
        ];
        
        Response::success([
            'dispute_id' => (int)$disputeId,
            'task_id' => $taskId,
            'decision' => $decision,
            'note' => $note,
            'resolved_by' => (int)$adminId,
            'message' => $actionMessages[$decision]
        ], 'Dispute resolved successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Admin Resolve Dispute API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
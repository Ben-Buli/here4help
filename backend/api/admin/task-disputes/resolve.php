<?php
/**
 * 管理員處理任務爭議
 * POST /api/admin/task-disputes/resolve
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../auth_helper.php';
require_once __DIR__ . '/../../../utils/SanctumTokenValidator.php';
require_once __DIR__ . '/../../../utils/PointTransactionLogger.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證 Sanctum Token（需要管理員權限）
    $tokenData = SanctumTokenValidator::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    $roleId = $tokenData['role_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    // 檢查管理員角色權限（super_admin, admin, developer）
    $allowedRoles = ['super_admin', 'admin', 'developer'];
    $roleName = $tokenData['role_name'] ?? '';
    if (!in_array($roleName, $allowedRoles)) {
        Response::error('Insufficient permissions to resolve disputes', 403);
    }
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $taskDisputeEventId = $input['dispute_id'] ?? '';
    $decision = $input['decision'] ?? '';
    $note = trim($input['note'] ?? '');
    
    if (empty($taskDisputeEventId)) {
        Response::error('Dispute ID is required', 400);
    }
    
    if (empty($decision)) {
        Response::error('Decision is required', 400);
    }
    
    if (empty($note)) {
        Response::error('Decision note is required', 400);
    }
    
    // 驗證決定值
    $allowedDecisions = ['completed', 'back_to_progress', 'reset'];
    if (!in_array($decision, $allowedDecisions)) {
        Response::error('Invalid decision. Allowed values: ' . implode(', ', $allowedDecisions), 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 檢查爭議是否存在並獲取相關資訊
        $disputeStmt = $db->prepare("
            SELECT 
                tde.*, 
                t.creator_id, 
                t.participant_id, 
                t.reward_point,
                t.title as task_title,
                t.status_id as current_task_status_id,
                ts.code as current_task_status_code
            FROM task_dispute_events tde
            JOIN tasks t ON tde.task_id = t.id
            LEFT JOIN task_statuses ts ON t.status_id = ts.id
            WHERE tde.id = ?
        ");
        $disputeStmt->execute([$taskDisputeEventId]);
        $dispute = $disputeStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$dispute) {
            Response::error('Dispute not found', 404);
        }
        
        // 檢查爭議狀態
        if ($dispute['status'] === 'resolved') {
            Response::error('Dispute has already been resolved', 409);
        }
        
        $taskId = $dispute['task_id']; // varchar 類型，保持字串格式
        $creatorId = (int)$dispute['creator_id'];
        $participantId = (int)$dispute['participant_id'];
        $rewardPoint = (float)($dispute['reward_point'] ?? 0);
        $taskTitle = $dispute['task_title'] ?? 'Unknown Task';
        $disputeUserId = (int)$dispute['user_id']; // 爭議申請人
        
        // 數據完整性檢查
        if (!$disputeUserId) {
            $disputeUserId = 1; // 使用系統用戶
            error_log("Warning: dispute user_id not found for task_dispute_event_id: $taskDisputeEventId, using system user");
        }
        
        // 獲取狀態 ID
        $statusIds = [];
        $statusQuery = $db->prepare("SELECT id, code FROM task_statuses WHERE code IN ('open', 'in_progress', 'completed')");
        $statusQuery->execute();
        while ($row = $statusQuery->fetch(PDO::FETCH_ASSOC)) {
            $statusIds[$row['code']] = $row['id'];
        }
        
        // 記錄舊狀態用於日誌
        $oldStatus = $dispute['status'];
        $oldDecision = $dispute['decision_result'];
        
        // 根據決定執行不同的邏輯
        switch ($decision) {
            case 'completed':
                // 任務判定完成，轉移點數
                
                // 1. 更新任務狀態為已完成
                $updateTaskStmt = $db->prepare("
                    UPDATE tasks 
                    SET status_id = ?, updated_at = NOW()
                    WHERE id = ?
                ");
                $updateTaskStmt->execute([$statusIds['completed'], $taskId]);
                
                // 2. 更新應徵者狀態為已完成
                $updateApplicationStmt = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'completed', updated_at = NOW()
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplicationStmt->execute([$taskId, $participantId]);
                
                // 3. 點數轉移邏輯（複製自 confirm_completion.php）
                if ($participantId && $rewardPoint > 0) {
                    // 讀取手續費設定
                    $feeRate = 0.0;
                    try {
                        $feeRow = $db->query("SELECT rate FROM task_completion_points_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1")->fetch(PDO::FETCH_ASSOC);
                        if ($feeRow && isset($feeRow['rate'])) {
                            $feeRate = (float)$feeRow['rate'];
                        }
                    } catch (Exception $e) {
                        $feeRate = 0.0;
                    }
                    
                    $amount = $rewardPoint;
                    $feeAmount = round($amount * $feeRate, 2);
                    // 修正：接案者獲得完整獎勵，手續費只向發布者額外收取
                    // $netAmount = max(0.0, $amount - $feeAmount); // 錯誤的舊邏輯
                    
                    // 創建者支出任務獎勵
                    $rewardTransactionId = PointTransactionLogger::logTaskSpending(
                        $creatorId,
                        (int)$amount,
                        $taskId,
                        $taskTitle
                    );
                    
                    // 接案者收入完整任務獎勵（不扣除手續費）
                    $earningTransactionId = PointTransactionLogger::logTaskEarning(
                        $participantId,
                        (int)$amount, // 修正：接案者獲得完整獎勵
                        $taskId,
                        $taskTitle
                    );
                    
                    // 創建者支出手續費
                    if ($feeAmount > 0) {
                        $feeTransactionId = PointTransactionLogger::logFee(
                            $creatorId,
                            (int)$feeAmount,
                            $taskId,
                            "Service fee for task: $taskTitle"
                        );
                        
                        // 記錄手續費收入 - 暫時註解，因為 fee_revenue_ledger.task_id 是 bigint 但 tasks.id 是 varchar
                        // TODO: 需要修改 fee_revenue_ledger 表的 task_id 欄位類型為 varchar(36) 以匹配 tasks.id
                        /*
                        $feeRecordSql = "
                            INSERT INTO fee_revenue_ledger (
                                fee_type, src_transaction_id, task_id, payer_user_id, 
                                amount_points, rate, note, created_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
                        ";
                        $db->prepare($feeRecordSql)->execute([
                            'task_completion',
                            $feeTransactionId ?? $rewardTransactionId,
                            $taskId,
                            $creatorId,
                            (int)$feeAmount,
                            $feeRate,
                            "Task completion fee: $taskTitle"
                        ]);
                        */
                    }
                    
                    // 更新用戶點數餘額
                    $db->prepare("UPDATE users SET points = points - ? WHERE id = ?")->execute([(int)$amount, $creatorId]);
                    $db->prepare("UPDATE users SET points = points + ? WHERE id = ?")->execute([(int)$amount, $participantId]); // 修正：接案者獲得完整獎勵
                    
                    // 創建者額外扣除手續費
                    if ($feeAmount > 0) {
                        $db->prepare("UPDATE users SET points = points - ? WHERE id = ?")->execute([(int)$feeAmount, $creatorId]);
                    }
                }
                break;
                
            case 'back_to_progress':
                // 駁回爭議，回到進行中
                
                // 1. 更新任務狀態為進行中
                $updateTaskStmt = $db->prepare("
                    UPDATE tasks 
                    SET status_id = ?, updated_at = NOW()
                    WHERE id = ?
                ");
                $updateTaskStmt->execute([$statusIds['in_progress'], $taskId]);
                
                // 2. 更新應徵者狀態為進行中
                $updateApplicationStmt = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'in_progress', updated_at = NOW()
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplicationStmt->execute([$taskId, $participantId]);
                break;
                
            case 'reset':
                // 重新開始，移除參與者
                
                // 1. 更新任務狀態為開放，移除參與者
                $updateTaskStmt = $db->prepare("
                    UPDATE tasks 
                    SET status_id = ?, participant_id = NULL, updated_at = NOW()
                    WHERE id = ?
                ");
                $updateTaskStmt->execute([$statusIds['open'], $taskId]);
                
                // 2. 更新應徵者狀態為被拒絕
                $updateApplicationStmt = $db->prepare("
                    UPDATE task_applications 
                    SET status = 'rejected', updated_at = NOW()
                    WHERE task_id = ? AND user_id = ?
                ");
                $updateApplicationStmt->execute([$taskId, $participantId]);
                break;
        }
        
        // 4. 更新爭議狀態為已解決
        $updateDisputeStmt = $db->prepare("
            UPDATE task_dispute_events 
            SET status = 'resolved',
                decision_result = ?,
                decision_note = ?,
                admin_id = ?,
                updated_at = NOW()
            WHERE id = ?
        ");
        $updateDisputeStmt->execute([$decision, $note, $adminId, $taskDisputeEventId]);
        
        // 5. 記錄到 task_dispute_event_logs
        $logStmt = $db->prepare("
            INSERT INTO task_dispute_event_logs (
                event_id, admin_id, old_status, new_status, 
                old_decision, new_decision, note, created_at
            ) VALUES (?, ?, ?, 'resolved', ?, ?, ?, NOW())
        ");
        $logStmt->execute([
            $taskDisputeEventId,
            $adminId,
            $oldStatus,
            $oldDecision,
            $decision,
            $note
        ]);
        
        // 6. 記錄管理員操作日誌
        $adminLogStmt = $db->prepare("
            INSERT INTO admin_activity_logs (
                admin_id, action, table_name, record_id, old_data, new_data, ip_address, user_agent, created_at
            ) VALUES (?, 'resolve_task_dispute', 'task_dispute_events', ?, ?, ?, ?, ?, NOW())
        ");
        $adminLogStmt->execute([
            $adminId,
            $taskDisputeEventId,
            json_encode(['status' => $oldStatus]),
            json_encode(['status' => 'resolved', 'decision_result' => $decision, 'decision_note' => $note]),
            $_SERVER['REMOTE_ADDR'] ?? null,
            $_SERVER['HTTP_USER_AGENT'] ?? null
        ]);
        
        // 7. 發送系統訊息到聊天室
        $systemMessage = "Dispute resolved: {$decision}\nAdmin note: {$note}";
        $messageId = null;
        
        try {
            // 查找聊天室
            $roomStmt = $db->prepare("SELECT id FROM chat_rooms WHERE task_id = ? ORDER BY id DESC LIMIT 1");
            $roomStmt->execute([$taskId]);
            $room = $roomStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($room) {
                // 插入系統訊息
                $messageStmt = $db->prepare("
                    INSERT INTO chat_messages (room_id, from_user_id, content, kind, created_at) 
                    VALUES (?, ?, ?, 'system', NOW())
                ");
                $messageStmt->execute([$room['id'], $disputeUserId, $systemMessage]);
                $messageId = $db->lastInsertId();
            } else {
                error_log("Warning: chat room not found for task_id: $taskId");
            }
        } catch (Exception $e) {
            error_log("Failed to send system message: " . $e->getMessage());
            // 不影響主流程
        }
        
        // 提交事務
        $db->commit();
        
        $actionMessages = [
            'completed' => 'Task marked as completed, points transferred',
            'back_to_progress' => 'Dispute rejected, task returned to in-progress status',
            'reset' => 'Task restarted, participant removed'
        ];
        
        $responseData = [
            'dispute_id' => (int)$taskDisputeEventId,
            'task_id' => $taskId,
            'decision' => $decision,
            'note' => $note,
            'resolved_by' => (int)$adminId,
            'message' => $actionMessages[$decision]
        ];
        
        if ($messageId) {
            $responseData['system_message_id'] = (int)$messageId;
        }
        
        // 8. Socket 通知（靜默失敗）
        try {
            if ($room && $messageId) {
                $socketData = [
                    'event' => 'dispute_resolved',
                    'data' => [
                        'room_id' => $room['id'],
                        'decision' => $decision,
                        'message_id' => $messageId,
                        'dispute_id' => $taskDisputeEventId
                    ]
                ];
                
                // 這裡可以調用 Socket 通知服務
                // sendSocketNotification($socketData);
            }
        } catch (Exception $e) {
            error_log("Socket notification failed: " . $e->getMessage());
            // 靜默失敗，不影響主流程
        }
        
        Response::success($responseData, 'Dispute resolved successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Admin Resolve Dispute API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>
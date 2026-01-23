<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * 建立任務爭議
 * POST /api/task-disputes/create.php
 */

// 開啟輸出緩衝，防止錯誤輸出干擾 JSON
ob_start();

// 設置錯誤處理
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/UserActiveLogger.php';

// 清除任何之前的輸出
ob_clean();

header('Content-Type: application/json');
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Only POST method is allowed');
}

try {
    // JWT 認證
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::unauthorized($tokenValidation['message']);
    }
    
    $tokenData = $tokenValidation['payload'];
    $userId = $tokenData['user_id'];
    
    // 獲取 POST 資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }
    
    $taskId = $input['task_id'] ?? null;
    $chatRoomId = $input['task_dispute_chat_room_id'] ?? null;
    $title = trim($input['title'] ?? '');
    $description = trim($input['description'] ?? '');
    
    // 驗證必要欄位
    if (!$taskId || !$chatRoomId || !$title || !$description) {
        Response::badRequest('Missing required fields: task_id, task_dispute_chat_room_id, title, description');
    }
    
    // 驗證字數限制
    if (strlen($title) > 255) {
        Response::badRequest('Title must not exceed 255 characters');
    }
    
    if (strlen($description) > 1000) {
        Response::badRequest('Description must not exceed 1000 characters');
    }
    
    // 資料庫連接
    $db = Database::getInstance()->getConnection();
    $db->beginTransaction();
    
    try {
        // 檢查任務是否存在且用戶有權限
        $taskCheck = $db->prepare("
            SELECT 
                id, 
                creator_id, 
                participant_id, 
                status_id,
                title as task_title
            FROM tasks 
            WHERE id = ?
        ");
        $taskCheck->execute([$taskId]);
        $task = $taskCheck->fetch(PDO::FETCH_ASSOC);
        
        if (!$task) {
            Response::notFound('Task not found');
        }
        
        // 檢查用戶是否為任務相關人員
        if ($userId != $task['creator_id'] && $userId != $task['participant_id']) {
            Response::forbidden('You do not have permission to dispute this task');
        }
        
        // 檢查任務狀態是否允許建立爭議 (只允許 in_progress=2, pending_confirmation=3)
        if (!in_array($task['status_id'], [2, 3])) {
            Response::badRequest('Task status does not allow dispute creation');
        }
        
        // 檢查聊天室是否存在且關聯正確
        $roomCheck = $db->prepare("
            SELECT id, task_id 
            FROM chat_rooms 
            WHERE id = ? AND task_id = ?
        ");
        $roomCheck->execute([$chatRoomId, $taskId]);
        $room = $roomCheck->fetch(PDO::FETCH_ASSOC);
        
        if (!$room) {
            Response::badRequest('Chat room not found or not associated with this task');
        }
        
        // 檢查是否已存在爭議 TODO: select 帶入creator_id 除了判斷task_dispute_chat_room_id 還要判斷creator_id是否是當前使用者重複申請
        $existingCheck = $db->prepare("
            SELECT id 
            FROM task_dispute_events 
            WHERE task_dispute_chat_room_id = ?
        ");
        $existingCheck->execute([$chatRoomId]);
        
        if ($existingCheck->fetch()) {
            Response::badRequest('A dispute already exists for this task');
        }
        
        // 建立爭議記錄
        $createDispute = $db->prepare("
            INSERT INTO task_dispute_events (
                task_id,
                task_dispute_chat_room_id,
                user_id,
                title,
                description,
                status,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, 'submitted', NOW(), NOW())
        ");
        
        $createDispute->execute([
            $taskId,
            $chatRoomId,
            $userId,
            $title,
            $description
        ]);
        
        $disputeId = $db->lastInsertId();
        
        // 更新任務狀態為爭議中 (status_id = 4)
        $oldStatus = $task['status_id'];
        $updateTask = $db->prepare("
            UPDATE tasks 
            SET status_id = 4, updated_at = NOW() 
            WHERE id = ?
        ");
        $updateTask->execute([$taskId]);
        
        // 更新對應的 task_applications 狀態
        $updateApplication = $db->prepare("
            UPDATE task_applications 
            SET status = 'dispute', updated_at = NOW() 
            WHERE task_id = ? AND user_id = ?
        ");
        $updateApplication->execute([$taskId, $task['participant_id']]);
        
        // 記錄爭議事件日誌
        $logEvent = $db->prepare("
            INSERT INTO task_dispute_event_logs (
                event_id,
                old_status,
                new_status,
                note,
                created_at
            ) VALUES (?, NULL, 'submitted', ?, NOW())
        ");
        $logEvent->execute([
            $disputeId,
            "Dispute created by user {$userId}: {$title}"
        ]);
        
        // 記錄使用者操作
        UserActiveLogger::logAction(
            $db, 
            $userId, 
            'task_dispute_created',
            'task_status', 
            $oldStatus, 
            '4',
            "Task dispute created: {$title}",
            'user', 
            $userId, 
            null, 
            null,
            [
                'task_id' => $taskId, 
                'dispute_id' => $disputeId,
                'chat_room_id' => $chatRoomId
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
        
        $messageContent = "A dispute has been submitted for this task.\nDispute ID: {$disputeId}\nTitle: {$title}\nStatus: Under Review";
        
        $systemMessage->execute([
            $chatRoomId,
            1, // 使用系統帳號 ID (1) 而不是操作者 ID
            $messageContent
        ]);
        
        $db->commit();
        
        Response::success([
            'dispute_id' => (int)$disputeId,
            'status' => 'submitted',
            'task_status_updated' => true
        ], 'Dispute created successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }

} catch (PDOException $e) {
    // 清除輸出緩衝區的任何錯誤輸出
    ob_clean();
    error_log("Database error in create dispute: " . $e->getMessage());
    Response::serverError('Database error occurred');
} catch (Exception $e) {
    // 清除輸出緩衝區的任何錯誤輸出
    ob_clean();
    error_log("Error in create dispute: " . $e->getMessage());
    Response::serverError('An error occurred while creating dispute');
} catch (Throwable $e) {
    // 捕獲所有可能的錯誤，包括 Fatal Error
    ob_clean();
    error_log("Fatal error in create dispute: " . $e->getMessage());
    Response::serverError('A critical error occurred');
}
?>

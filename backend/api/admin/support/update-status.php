<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * 管理員更新客服事件狀態 API
 * POST /api/admin/support/update-status
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
    
    $eventId = $input['event_id'] ?? '';
    $status = $input['status'] ?? '';
    
    if (empty($eventId)) {
        Response::error('Event ID is required', 400);
    }
    
    if (empty($status)) {
        Response::error('Status is required', 400);
    }
    
    // 驗證狀態值
    $allowedStatuses = ['submitted', 'in_progress', 'resolved'];
    if (!in_array($status, $allowedStatuses)) {
        Response::error('Invalid status. Allowed values: ' . implode(', ', $allowedStatuses), 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 檢查事件是否存在
        $eventStmt = $db->prepare("
            SELECT se.*, scr.admin_id 
            FROM support_events se
            JOIN support_chat_rooms scr ON se.id = scr.event_id
            WHERE se.id = ?
        ");
        $eventStmt->execute([$eventId]);
        $event = $eventStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$event) {
            Response::error('Support event not found', 404);
        }
        
        // 檢查是否有權限更新（必須是接手的管理員）
        if (empty($event['admin_id']) || $event['admin_id'] != $adminId) {
            Response::error('You do not have permission to update this event', 403);
        }
        
        // 記錄舊狀態用於日誌
        $oldStatus = $event['status'];
        
        // 更新事件狀態
        $updateStmt = $db->prepare("
            UPDATE support_events 
            SET status = ?, updated_at = NOW() 
            WHERE id = ?
        ");
        $updateStmt->execute([$status, $eventId]);
        
        // 如果狀態是已解決，記錄關閉時間
        if ($status === 'resolved') {
            $closeStmt = $db->prepare("
                UPDATE support_events 
                SET closed_at = NOW() 
                WHERE id = ?
            ");
            $closeStmt->execute([$eventId]);
        }
        
        // 記錄管理員操作日誌
        $logStmt = $db->prepare("
            INSERT INTO admin_activity_logs (
                admin_id, action, table_name, record_id, old_data, new_data, ip_address, user_agent, created_at
            ) VALUES (?, 'update_support_status', 'support_events', ?, ?, ?, ?, ?, NOW())
        ");
        $logStmt->execute([
            $adminId,
            $eventId,
            json_encode(['status' => $oldStatus]),
            json_encode(['status' => $status]),
            $_SERVER['REMOTE_ADDR'] ?? null,
            $_SERVER['HTTP_USER_AGENT'] ?? null
        ]);
        
        // 提交事務
        $db->commit();
        
        Response::success([
            'event_id' => (int)$eventId,
            'status' => $status,
            'updated_by' => (int)$adminId,
            'message' => 'Event status updated successfully'
        ], 'Event status updated successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Admin Update Support Status API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

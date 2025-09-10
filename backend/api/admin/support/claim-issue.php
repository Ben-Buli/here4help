<?php
/**
 * 管理員接手客服事件 API
 * POST /api/admin/support/claim-issue
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
    
    $roomId = $input['room_id'] ?? '';
    
    if (empty($roomId)) {
        Response::error('Room ID is required', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 開始事務
    $db->beginTransaction();
    
    try {
        // 檢查聊天室是否存在
        $roomStmt = $db->prepare("
            SELECT scr.*, se.status as event_status 
            FROM support_chat_rooms scr
            JOIN support_events se ON scr.event_id = se.id
            WHERE scr.id = ?
        ");
        $roomStmt->execute([$roomId]);
        $room = $roomStmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$room) {
            Response::error('Chat room not found', 404);
        }
        
        // 檢查是否已被其他管理員接手
        if (!empty($room['admin_id']) && $room['admin_id'] != $adminId) {
            Response::error('This issue has already been claimed by another admin', 409);
        }
        
        // 如果已經是當前管理員接手，直接返回成功
        if ($room['admin_id'] == $adminId) {
            $db->commit();
            Response::success([
                'room_id' => (int)$roomId,
                'admin_id' => (int)$adminId,
                'message' => 'Issue already claimed by you'
            ], 'Issue already claimed');
        }
        
        // 更新聊天室的管理員ID
        $updateRoomStmt = $db->prepare("
            UPDATE support_chat_rooms 
            SET admin_id = ?, updated_at = NOW() 
            WHERE id = ?
        ");
        $updateRoomStmt->execute([$adminId, $roomId]);
        
        // 更新相關事件狀態為處理中
        $updateEventStmt = $db->prepare("
            UPDATE support_events 
            SET status = 'in_progress', updated_at = NOW() 
            WHERE id = ? AND status = 'submitted'
        ");
        $updateEventStmt->execute([$room['event_id']]);
        
        // 記錄管理員操作日誌
        $logStmt = $db->prepare("
            INSERT INTO admin_activity_logs (
                admin_id, action, target_type, target_id, description, created_at
            ) VALUES (?, 'claim_support_issue', 'support_chat_room', ?, ?, NOW())
        ");
        $logStmt->execute([
            $adminId,
            $roomId,
            "Admin claimed support issue in room {$roomId}"
        ]);
        
        // 提交事務
        $db->commit();
        
        Response::success([
            'room_id' => (int)$roomId,
            'admin_id' => (int)$adminId,
            'message' => 'Issue claimed successfully'
        ], 'Issue claimed successfully');
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Admin Claim Issue API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

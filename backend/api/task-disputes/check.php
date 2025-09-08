<?php
/**
 * 檢查任務爭議是否已存在
 * GET /api/task-disputes/check.php?chat_room_id={chat_room_id}
 */

// 開啟輸出緩衝，防止錯誤輸出干擾 JSON
ob_start();

// 設置錯誤處理
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 清除任何之前的輸出
ob_clean();

header('Content-Type: application/json');
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Only GET method is allowed');
}

try {
    // JWT 認證
    $tokenValidation = JWTManager::validateRequest();
    if (!$tokenValidation['valid']) {
        Response::unauthorized($tokenValidation['message']);
    }
    
    $tokenData = $tokenValidation['payload'];
    $userId = $tokenData['user_id'];
    error_log('check.php: userId: ' . $userId);
    
    // 獲取參數
    $chatRoomId = $_GET['chat_room_id'] ?? null;
    
    if (!$chatRoomId) {
        Response::badRequest('chat_room_id parameter is required');
    }

    // 資料庫連接
    $db = Database::getInstance()->getConnection();
    
    // 檢查聊天室是否存在且用戶有權限
    // $roomCheck = $db->prepare("
    //     SELECT cr.id, cr.task_id, t.creator_id, t.participant_id
    //     FROM chat_rooms cr
    //     LEFT JOIN tasks t ON cr.task_id = t.id
    //     WHERE cr.id = ?
    // ");
    // $roomCheck->execute([$chatRoomId]);
    // $room = $roomCheck->fetch(PDO::FETCH_ASSOC);
    
    // if (!$room) {
    //     Response::notFound('Chat room not found');
    // }
    
    // 檢查用戶是否為任務相關人員
    // if ($userId != $room['creator_id'] && $userId != $room['participant_id']) {
    //     Response::forbidden('You do not have permission to access this chat room');
    // }
    
    // 檢查是否已存在爭議
    $disputeCheck = $db->prepare("
        SELECT 
            id,
            title,
            status,
            created_at,
            updated_at
        FROM task_dispute_events 
        WHERE task_dispute_chat_room_id = ?
        ORDER BY created_at DESC
        LIMIT 1
    ");
    $disputeCheck->execute([$chatRoomId]);
    $existingDispute = $disputeCheck->fetch(PDO::FETCH_ASSOC);
    
    if ($existingDispute) {
        // 存在爭議
        Response::success([
            'exists' => true,
            'dispute' => [
                'id' => (int)$existingDispute['id'],
                'title' => $existingDispute['title'],
                'status' => $existingDispute['status'],
                'created_at' => $existingDispute['created_at'],
                'updated_at' => $existingDispute['updated_at']
            ]
        ], 'Existing dispute found');
    } else {
        // 不存在爭議
        Response::success([
            'exists' => false,
            'dispute' => null
        ], 'No existing dispute found');
    }

} catch (PDOException $e) {
    // 清除輸出緩衝區的任何錯誤輸出
    ob_clean();
    error_log("Database error in check dispute: " . $e->getMessage());
    Response::serverError('Database error occurred');
} catch (Exception $e) {
    // 清除輸出緩衝區的任何錯誤輸出
    ob_clean();
    error_log("Error in check dispute: " . $e->getMessage());
    Response::serverError('An error occurred while checking dispute');
} catch (Throwable $e) {
    // 捕獲所有可能的錯誤，包括 Fatal Error
    ob_clean();
    error_log("Fatal error in check dispute: " . $e->getMessage());
    Response::serverError('A critical error occurred');
}
?>

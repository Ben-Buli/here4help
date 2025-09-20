<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

/**
 * 管理員查看爭議任務聊天記錄 API
 * GET /api/admin/dispute-chat-messages
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
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
    
    $disputeId = $_GET['dispute_id'] ?? '';
    
    if (empty($disputeId)) {
        Response::error('Dispute ID is required', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 首先獲取爭議信息和相關任務信息
    $disputeStmt = $db->prepare("
        SELECT 
            tde.*,
            t.id as task_id,
            t.title as task_title,
            t.description as task_description,
            t.reward_point,
            t.creator_id,
            t.participant_id,
            creator.name as creator_name,
            creator.email as creator_email,
            participant.name as participant_name,
            participant.email as participant_email,
            submitter.name as submitter_name,
            submitter.email as submitter_email
        FROM task_dispute_events tde
        JOIN tasks t ON tde.task_id = t.id
        LEFT JOIN users creator ON t.creator_id = creator.id
        LEFT JOIN users participant ON t.participant_id = participant.id
        LEFT JOIN users submitter ON tde.submitter_id = submitter.id
        WHERE tde.id = ?
    ");
    $disputeStmt->execute([$disputeId]);
    $dispute = $disputeStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$dispute) {
        Response::error('Dispute not found', 404);
    }
    
    // 獲取任務相關的聊天記錄
    // 這裡我們需要找到任務創建者和參與者之間的聊天記錄
    // 假設聊天記錄存儲在 chat_messages 表中，關聯到任務
    $messagesStmt = $db->prepare("
        SELECT 
            cm.*,
            sender.name as sender_name,
            sender.email as sender_email,
            receiver.name as receiver_name,
            receiver.email as receiver_email
        FROM chat_messages cm
        LEFT JOIN users sender ON cm.sender_id = sender.id
        LEFT JOIN users receiver ON cm.receiver_id = receiver.id
        WHERE cm.task_id = ?
        AND (
            (cm.sender_id = ? AND cm.receiver_id = ?) OR
            (cm.sender_id = ? AND cm.receiver_id = ?)
        )
        ORDER BY cm.created_at ASC
    ");
    
    $creatorId = $dispute['creator_id'];
    $participantId = $dispute['participant_id'];
    
    $messagesStmt->execute([
        $dispute['task_id'],
        $creatorId, $participantId,
        $participantId, $creatorId
    ]);
    $messages = $messagesStmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 格式化聊天記錄
    $formattedMessages = array_map(function($message) use ($creatorId, $participantId) {
        $senderRole = '';
        if ($message['sender_id'] == $creatorId) {
            $senderRole = 'creator';
        } elseif ($message['sender_id'] == $participantId) {
            $senderRole = 'participant';
        } else {
            $senderRole = 'other';
        }
        
        return [
            'id' => (int)$message['id'],
            'sender_id' => (int)$message['sender_id'],
            'sender_name' => $message['sender_name'],
            'sender_email' => $message['sender_email'],
            'sender_role' => $senderRole,
            'receiver_id' => (int)$message['receiver_id'],
            'receiver_name' => $message['receiver_name'],
            'receiver_email' => $message['receiver_email'],
            'content' => $message['content'],
            'message_type' => $message['message_type'] ?? 'text',
            'created_at' => $message['created_at'],
            'updated_at' => $message['updated_at']
        ];
    }, $messages);
    
    // 格式化爭議信息
    $disputeInfo = [
        'id' => (int)$dispute['id'],
        'task_id' => $dispute['task_id'],
        'dispute_title' => $dispute['dispute_title'],
        'description' => $dispute['description'],
        'status' => $dispute['status'],
        'decision_result' => $dispute['decision_result'],
        'decision_note' => $dispute['decision_note'],
        'created_at' => $dispute['created_at'],
        'updated_at' => $dispute['updated_at'],
        'task' => [
            'id' => $dispute['task_id'],
            'title' => $dispute['task_title'],
            'description' => $dispute['task_description'],
            'reward_point' => (int)$dispute['reward_point']
        ],
        'creator' => [
            'id' => (int)$dispute['creator_id'],
            'name' => $dispute['creator_name'],
            'email' => $dispute['creator_email']
        ],
        'participant' => [
            'id' => (int)$dispute['participant_id'],
            'name' => $dispute['participant_name'],
            'email' => $dispute['participant_email']
        ],
        'submitter' => [
            'id' => (int)$dispute['submitter_id'],
            'name' => $dispute['submitter_name'],
            'email' => $dispute['submitter_email']
        ]
    ];
    
    Response::success([
        'dispute' => $disputeInfo,
        'messages' => $formattedMessages,
        'message_count' => count($formattedMessages)
    ], 'Dispute chat messages retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin Dispute Chat Messages API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

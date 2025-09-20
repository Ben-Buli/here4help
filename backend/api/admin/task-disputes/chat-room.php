<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * 管理員查看爭議聊天室
 * GET /api/admin/task-disputes/{task_id}/chat-room.php
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../auth_helper.php';
require_once __DIR__ . '/../../../utils/SanctumTokenValidator.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/UserActiveLogger.php';

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
    // Sanctum Token 認證
    $tokenData = SanctumTokenValidator::validateRequest();
    if (!$tokenData['valid']) {
        Response::unauthorized($tokenData['message']);
    }
    

    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::forbidden('Admin access required');
    }
    
    // 獲取任務ID
    $taskId = $_GET['task_id'] ?? null;
    if (!$taskId) {
        Response::badRequest('Task ID is required');
    }
    
    // 資料庫連接
    $db = Database::getInstance()->getConnection();
    
    // 驗證管理員角色
    $adminCheck = $db->prepare("
        SELECT a.id, ar.name as role_name, a.username
        FROM admins a
        JOIN admin_roles ar ON a.role_id = ar.id
        WHERE a.id = ?
    ");
    $adminCheck->execute([$adminId]);
    $admin = $adminCheck->fetch(PDO::FETCH_ASSOC);
    
    if (!$admin || !in_array($admin['role_name'], ['admin', 'super_admin'])) {
        Response::forbidden('Insufficient permissions to view dispute chat rooms');
    }
    
    // 獲取爭議資訊
    $disputeQuery = $db->prepare("
        SELECT 
            tde.id,
            tde.task_id,
            tde.task_dispute_chat_room_id,
            tde.user_id as applicant_user_id,
            tde.title,
            tde.description,
            tde.status,
            tde.decision_result,
            tde.decision_note,
            tde.created_at,
            tde.updated_at,
            t.title as task_title,
            t.creator_id,
            t.participant_id,
            t.reward_point,
            ts.code as task_status_code,
            ts.display_name as task_status_display
        FROM task_dispute_events tde
        JOIN tasks t ON tde.task_id = t.id
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        WHERE tde.task_id = ?
    ");
    $disputeQuery->execute([$taskId]);
    $dispute = $disputeQuery->fetch(PDO::FETCH_ASSOC);
    
    if (!$dispute) {
        // 若以數字型 dispute_id 查無資料，嘗試以 task_id（字串）查找最新的爭議事件
        $fallbackQuery = $db->prepare("
            SELECT 
                tde.id,
                tde.task_id,
                tde.task_dispute_chat_room_id,
                tde.user_id as applicant_user_id,
                tde.title,
                tde.description,
                tde.status,
                tde.decision_result,
                tde.decision_note,
                tde.created_at,
                tde.updated_at,
                t.title as task_title,
                t.creator_id,
                t.participant_id,
                t.reward_point,
                ts.code as task_status_code,
                ts.display_name as task_status_display
            FROM task_dispute_events tde
            JOIN tasks t ON tde.task_id = t.id
            LEFT JOIN task_statuses ts ON t.status_id = ts.id
            WHERE tde.task_id = ?
            ORDER BY tde.created_at DESC
            LIMIT 1
        ");
        $fallbackQuery->execute([$taskId]);
        $dispute = $fallbackQuery->fetch(PDO::FETCH_ASSOC);
        
        if (!$dispute) {
            // 仍查無爭議事件，允許僅以 task_id 顯示聊天室內容
            $taskStmt = $db->prepare("SELECT id, title, creator_id, participant_id, reward_point, status_id FROM tasks WHERE id = ?");
            $taskStmt->execute([$taskId]);
            $taskRow = $taskStmt->fetch(PDO::FETCH_ASSOC);
            if (!$taskRow) {
                Response::notFound('Dispute or Task not found');
            }
            // 構造最小 dispute 結構（供後續統一輸出）
            $dispute = [
                'id' => null,
                'task_id' => $taskRow['id'],
                'task_dispute_chat_room_id' => null,
                'applicant_user_id' => null,
                'title' => null,
                'description' => null,
                'status' => null,
                'decision_result' => null,
                'decision_note' => null,
                'created_at' => null,
                'updated_at' => null,
                'task_title' => $taskRow['title'],
                'creator_id' => $taskRow['creator_id'],
                'participant_id' => $taskRow['participant_id'],
                'reward_point' => $taskRow['reward_point'],
                'task_status_code' => null,
                'task_status_display' => null
            ];
            if (!empty($taskRow['status_id'])) {
                $tsStmt = $db->prepare("SELECT code, display_name FROM task_statuses WHERE id = ?");
                $tsStmt->execute([$taskRow['status_id']]);
                $tsRow = $tsStmt->fetch(PDO::FETCH_ASSOC);
                if ($tsRow) {
                    $dispute['task_status_code'] = $tsRow['code'];
                    $dispute['task_status_display'] = $tsRow['display_name'];
                }
            }
        }
    }

    // 若前兩種查詢皆失敗（不會到這裡），或未來擴充：以任務標題 slug 比對
    // 這段僅在上述查詢均未找到時執行；目前為保留結構（不影響既有成功路徑）
    
    $chatRoomId = $dispute['task_dispute_chat_room_id'] ?? null;
    $taskId = $dispute['task_id'];
    
    $chatRoom = null;
    
    // 獲取聊天室資訊（先用事件上的 chat_room_id，失敗則以 task_id 查找最新房間）
    if ($chatRoomId) {
        $roomQuery = $db->prepare("
            SELECT 
                cr.id, cr.type, cr.task_id, cr.creator_id, cr.participant_id, cr.created_at,
                creator.name as creator_name, creator.avatar_url as creator_avatar,
                participant.name as participant_name, participant.avatar_url as participant_avatar,
                ta.status as participant_application_status
            FROM chat_rooms cr
            LEFT JOIN users creator ON cr.creator_id = creator.id
            LEFT JOIN users participant ON cr.participant_id = participant.id
            LEFT JOIN task_applications ta ON cr.task_id = ta.task_id AND cr.participant_id = ta.user_id
            WHERE cr.id = ?
        ");
        $roomQuery->execute([$chatRoomId]);
        $chatRoom = $roomQuery->fetch(PDO::FETCH_ASSOC);
    }
    
    if (!$chatRoom) {
        // 後備：以 task_id 尋找聊天室（取最新建立的一間）
        $fallbackRoomQuery = $db->prepare("
            SELECT 
                cr.id, cr.type, cr.task_id, cr.creator_id, cr.participant_id, cr.created_at,
                creator.name as creator_name, creator.avatar_url as creator_avatar,
                participant.name as participant_name, participant.avatar_url as participant_avatar,
                ta.status as participant_application_status
            FROM chat_rooms cr
            LEFT JOIN users creator ON cr.creator_id = creator.id
            LEFT JOIN users participant ON cr.participant_id = participant.id
            LEFT JOIN task_applications ta ON cr.task_id = ta.task_id AND cr.participant_id = ta.user_id
            WHERE cr.task_id = ?
            ORDER BY cr.created_at DESC
            LIMIT 1
        ");
        $fallbackRoomQuery->execute([$taskId]);
        $chatRoom = $fallbackRoomQuery->fetch(PDO::FETCH_ASSOC);
    }
    
    if (!$chatRoom) {
        Response::notFound('Chat room not found');
    }
    
    // 獲取聊天訊息 (完整歷史)
    $messagesQuery = $db->prepare("
        SELECT 
            cm.id,
            cm.room_id,
            cm.from_user_id,
            cm.content,
            cm.kind,
            cm.media_url,
            cm.mime_type,
            cm.created_at,
            u.name as user_name,
            u.avatar_url as user_avatar
        FROM chat_messages cm
        LEFT JOIN users u ON cm.from_user_id = u.id
        WHERE cm.room_id = ?
        ORDER BY cm.created_at ASC
    ");
    $messagesQuery->execute([$chatRoomId]);
    $messages = $messagesQuery->fetchAll(PDO::FETCH_ASSOC);
    
    // 獲取參與用戶資訊
    $userIds = array_unique(array_filter([
        $dispute['creator_id'],
        $dispute['participant_id'],
        $dispute['applicant_user_id'] ?? null
    ]));
    
    $users = [];
    if (!empty($userIds)) {
        $userPlaceholders = str_repeat('?,', count($userIds) - 1) . '?';
        $usersQuery = $db->prepare("
            SELECT 
                id,
                name,
                email,
                avatar_url
            FROM users
            WHERE id IN ({$userPlaceholders})
        ");
        $usersQuery->execute($userIds);
        $userResults = $usersQuery->fetchAll(PDO::FETCH_ASSOC);
        
        foreach ($userResults as $user) {
            $users[$user['id']] = [
                'id' => (int)$user['id'],
                'name' => $user['name'],
                'email' => $user['email'],
                'avatar_url' => $user['avatar_url']
            ];
        }
    }
    
    // 格式化訊息資料
    $formattedMessages = array_map(function($message) use ($users, $db, $taskId) {
        $messageData = [
            'id' => (int)$message['id'],
            'room_id' => $message['room_id'],
            'from_user_id' => $message['from_user_id'] ? (int)$message['from_user_id'] : null,
            'content' => $message['content'],
            'kind' => $message['kind'],
            'created_at' => $message['created_at'],
            'user_name' => $message['user_name'] ?? 'System',
            'user_avatar' => $message['user_avatar']
        ];
        
        // 添加特殊內容
        if ($message['media_url']) {
            $messageData['media_url'] = $message['media_url'];
            $messageData['mime_type'] = $message['mime_type'];
        }
        
        // 為 resume 訊息添加完整的申請資料
        if ($message['kind'] === 'resume' && $message['from_user_id']) {
            $resumeData = [];
            
            // 解析 content 中的現有資料
            if ($message['content']) {
                try {
                    $contentData = json_decode($message['content'], true);
                    if ($contentData) {
                        $resumeData = array_merge($resumeData, $contentData);
                    }
                } catch (Exception $e) {
                    // 忽略解析錯誤
                }
            }
            
            // 查詢 task_applications 資料
            try {
                $appQuery = $db->prepare("
                    SELECT answers_json, cover_letter 
                    FROM task_applications 
                    WHERE task_id = ? AND user_id = ?
                    LIMIT 1
                ");
                $appQuery->execute([$taskId, $message['from_user_id']]);
                $appData = $appQuery->fetch(PDO::FETCH_ASSOC);
                
                if ($appData) {
                    // 添加 cover_letter（自我推薦信）
                    if ($appData['cover_letter']) {
                        $resumeData['cover_letter'] = $appData['cover_letter'];
                    }
                    
                    // 添加 answers_json（問題和回答）
                    if ($appData['answers_json']) {
                        try {
                            $answers = json_decode($appData['answers_json'], true);
                            if ($answers) {
                                // 將 answers_json 轉換為 applyResponses 格式
                                $applyResponses = [];
                                foreach ($answers as $question => $answer) {
                                    $applyResponses[] = [
                                        'applyQuestion' => $question,
                                        'applyReply' => $answer
                                    ];
                                }
                                $resumeData['applyResponses'] = $applyResponses;
                            }
                        } catch (Exception $e) {
                            // 忽略解析錯誤
                        }
                    }
                    
                    // 如果沒有 applyIntroduction 但有 cover_letter，使用 cover_letter
                    if (empty($resumeData['applyIntroduction']) && !empty($resumeData['cover_letter'])) {
                        $resumeData['applyIntroduction'] = $resumeData['cover_letter'];
                    }
                }
            } catch (Exception $e) {
                // 忽略查詢錯誤
            }
            
            $messageData['resume_data'] = $resumeData;
        }
        
        return $messageData;
    }, $messages);
    
    // 記錄管理員查看操作
    UserActiveLogger::logAction(
        $db, 
        $adminId, 
        'dispute_chat_viewed',
        'dispute_management', 
        null, 
        null,
        "Admin viewed dispute chat room for task ID: {$taskId}",
        'admin', 
        $adminId, 
        null, 
        null,
        [
            'dispute_id' => $dispute['id'] ?? null,
            'chat_room_id' => $chatRoomId,
            'task_id' => $taskId
        ]
    );
    
    // 分析成員狀態：比對 tasks 和 chat_rooms 的成員
    $taskCreatorId = (int)$dispute['creator_id'];
    $taskParticipantId = $dispute['participant_id'] ? (int)$dispute['participant_id'] : null;
    $roomCreatorId = (int)$chatRoom['creator_id'];
    $roomParticipantId = (int)$chatRoom['participant_id'];
    $disputerId = $dispute['applicant_user_id'] ? (int)$dispute['applicant_user_id'] : null;
    
    // 判斷成員狀態
    $memberStatus = [
        'creator' => [
            'user_id' => $roomCreatorId,
            'name' => $chatRoom['creator_name'],
            'avatar_url' => $chatRoom['creator_avatar'],
            'is_active' => ($roomCreatorId === $taskCreatorId),
            'role' => 'Poster',
            'is_disputer' => ($roomCreatorId === $disputerId)
        ],
        'participant' => [
            'user_id' => $roomParticipantId,
            'name' => $chatRoom['participant_name'],
            'avatar_url' => $chatRoom['participant_avatar'],
            'is_active' => ($roomParticipantId === $taskParticipantId) && ($taskParticipantId !== null),
            'role' => 'Tasker',
            'is_disputer' => ($roomParticipantId === $disputerId),
            'application_status' => $chatRoom['participant_application_status']
        ]
    ];
    
    Response::success([
        'chat_room' => [
            'id' => $chatRoom['id'],
            'type' => $chatRoom['type'],
            'task_id' => $chatRoom['task_id'],
            'creator_id' => (int)$chatRoom['creator_id'],
            'participant_id' => (int)$chatRoom['participant_id'],
            'created_at' => $chatRoom['created_at']
        ],
        'task' => [
            'id' => $dispute['task_id'],
            'title' => $dispute['task_title'],
            'creator_id' => (int)$dispute['creator_id'],
            'participant_id' => $dispute['participant_id'] ? (int)$dispute['participant_id'] : null,
            'reward_point' => (int)$dispute['reward_point'],
            'status' => [
                'code' => $dispute['task_status_code'],
                'display_name' => $dispute['task_status_display']
            ]
        ],
        'member_status' => $memberStatus,
        'messages' => $formattedMessages,
        'users' => $users,
        'dispute_info' => [
            'id' => (int)$dispute['id'],
            'applicant_user_id' => isset($dispute['applicant_user_id']) ? (int)$dispute['applicant_user_id'] : null,
            'title' => $dispute['title'],
            'description' => $dispute['description'],
            'status' => $dispute['status'],
            'decision_result' => $dispute['decision_result'],
            'decision_note' => $dispute['decision_note'],
            'created_at' => $dispute['created_at'],
            'updated_at' => $dispute['updated_at']
        ],
        'meta' => [
            'total_messages' => count($formattedMessages),
            'viewed_by_admin' => $admin['username'],
            'admin_id' => (int)$admin['id'],
            'viewed_at' => date('Y-m-d H:i:s')
        ]
    ], 'Chat room data retrieved successfully');

} catch (PDOException $e) {
    error_log("Database error in admin chat room view: " . $e->getMessage());
    Response::serverError('Database error occurred');
} catch (Exception $e) {
    error_log("Error in admin chat room view: " . $e->getMessage());
    Response::serverError('An error occurred while retrieving chat room data');
}
?>

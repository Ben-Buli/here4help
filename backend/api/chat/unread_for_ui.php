<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::error('Method not allowed', 405);
    }

    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
        throw new Exception('Authorization header required');
    }
    $user_id = TokenValidator::validateAuthHeader($auth_header);
    if (!$user_id) { throw new Exception('Invalid or expired token'); }
    $user_id = (int)$user_id;
    
    $db = Database::getInstance();
    
    // 1. 獲取 Posted Tasks 的任務卡片數據
    $postedTasksSQL = "
        SELECT 
            t.id as task_id,
            t.title,
            t.status_id,
            t.creator_id,
            cr.id as room_id,
            cr.participant_id,
            CASE WHEN EXISTS (
                SELECT 1 FROM chat_messages cm 
                WHERE cm.room_id = cr.id 
                AND cm.from_user_id = cr.participant_id 
                AND cm.id > COALESCE(r.last_read_message_id, 0)
            ) THEN 1 ELSE 0 END as has_unread
        FROM tasks t
        JOIN chat_rooms cr ON cr.task_id = t.id
        LEFT JOIN chat_reads r ON r.room_id = cr.id AND r.user_id = ?
        WHERE t.creator_id = ?
        ORDER BY t.updated_at DESC
    ";
    
    $postedTasks = $db->fetchAll($postedTasksSQL, [$user_id, $user_id]);
    
    // 2. 獲取 Posted Tasks 的應徵者卡片數據
    $postedApplicantsSQL = "
        SELECT 
            t.id as task_id,
            cr.id as room_id,
            cr.participant_id,
            u.name as participant_name,
            u.avatar_url as participant_avatar,
            COALESCE(unread_counts.unread_count, 0) as unread_count
        FROM tasks t
        JOIN chat_rooms cr ON cr.task_id = t.id
        JOIN users u ON u.id = cr.participant_id
        LEFT JOIN (
            SELECT 
                cm.room_id,
                COUNT(DISTINCT cm.id) as unread_count
            FROM chat_messages cm
            LEFT JOIN chat_reads r ON r.room_id = cm.room_id AND r.user_id = ?
            LEFT JOIN chat_rooms cr_inner ON cr_inner.id = cm.room_id
            WHERE cm.from_user_id = cr_inner.participant_id
                AND cm.id > COALESCE(r.last_read_message_id, 0)
            GROUP BY cm.room_id
        ) unread_counts ON unread_counts.room_id = cr.id
        WHERE t.creator_id = ?
        HAVING unread_count > 0
        ORDER BY t.updated_at DESC, unread_count DESC
    ";
    
    $postedApplicants = $db->fetchAll($postedApplicantsSQL, [$user_id, $user_id]);
    
    // 3. 獲取 My Works 的任務卡片數據
    $myWorksTasksSQL = "
        SELECT 
            t.id as task_id,
            t.title,
            t.status_id,
            t.creator_id,
            u.name as creator_name,
            u.avatar_url as creator_avatar,
            cr.id as room_id,
            CASE WHEN EXISTS (
                SELECT 1 FROM chat_messages cm 
                WHERE cm.room_id = cr.id 
                AND cm.from_user_id = cr.creator_id 
                AND cm.id > COALESCE(r.last_read_message_id, 0)
            ) THEN 1 ELSE 0 END as has_unread
        FROM tasks t
        JOIN chat_rooms cr ON cr.task_id = t.id
        JOIN users u ON u.id = t.creator_id
        LEFT JOIN chat_reads r ON r.room_id = cr.id AND r.user_id = ?
        WHERE cr.participant_id = ?
        ORDER BY t.updated_at DESC
    ";
    
    $myWorksTasks = $db->fetchAll($myWorksTasksSQL, [$user_id, $user_id]);
    
    // 4. 獲取 My Works 的聊天夥伴數據
    $myWorksPartnersSQL = "
        SELECT 
            t.id as task_id,
            cr.id as room_id,
            t.creator_id,
            u.name as creator_name,
            u.avatar_url as creator_avatar,
            COALESCE(unread_counts.unread_count, 0) as unread_count
        FROM tasks t
        JOIN chat_rooms cr ON cr.task_id = t.id
        JOIN users u ON u.id = t.creator_id
        LEFT JOIN (
            SELECT 
                cm.room_id,
                COUNT(DISTINCT cm.id) as unread_count
            FROM chat_messages cm
            LEFT JOIN chat_reads r ON r.room_id = cm.room_id AND r.user_id = ?
            LEFT JOIN chat_rooms cr_inner ON cr_inner.id = cm.room_id
            WHERE cm.from_user_id = cr_inner.creator_id
                AND cm.id > COALESCE(r.last_read_message_id, 0)
            GROUP BY cm.room_id
        ) unread_counts ON unread_counts.room_id = cr.id
        WHERE cr.participant_id = ?
        HAVING unread_count > 0
        ORDER BY t.updated_at DESC, unread_count DESC
    ";
    
    $myWorksPartners = $db->fetchAll($myWorksPartnersSQL, [$user_id, $user_id]);
    
    // 5. 計算總未讀數（用於底部導航）
    $totalUnreadSQL = "
        SELECT 
            SUM(CASE WHEN cm.from_user_id != ? 
                      AND cm.id > COALESCE(r.last_read_message_id, 0)
                     THEN 1 ELSE 0 END) as total_unread
        FROM chat_messages cm
        JOIN chat_rooms cr ON cr.id = cm.room_id
        LEFT JOIN chat_reads r ON r.room_id = cm.room_id AND r.user_id = ?
        WHERE cr.creator_id = ? OR cr.participant_id = ?
    ";
    
    $totalUnread = $db->query($totalUnreadSQL, [$user_id, $user_id, $user_id, $user_id])->fetch();
    
    Response::success([
        'total_unread' => (int)($totalUnread['total_unread'] ?? 0),
        'posted_tasks' => [
            'tasks' => $postedTasks,
            'applicants' => $postedApplicants
        ],
        'my_works' => [
            'tasks' => $myWorksTasks,
            'partners' => $myWorksPartners
        ],
        'summary' => [
            'posted_tasks_count' => count($postedTasks),
            'posted_applicants_count' => count($postedApplicants),
            'my_works_tasks_count' => count($myWorksTasks),
            'my_works_partners_count' => count($myWorksPartners)
        ]
    ], 'UI-optimized unread data');

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

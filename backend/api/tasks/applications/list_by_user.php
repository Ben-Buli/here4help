<?php
require_once '../../../config/database.php';
require_once '../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    // 參數驗證和轉型
    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
    if ($userId <= 0) {
        Response::validationError(['user_id' => 'user_id is required and must be positive']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);

    // 檢查必要的表是否存在
    try {
        $db->query("SELECT 1 FROM task_applications LIMIT 1");
        $db->query("SELECT 1 FROM tasks LIMIT 1");
        $db->query("SELECT 1 FROM task_statuses LIMIT 1");
        $db->query("SELECT 1 FROM users LIMIT 1");
    } catch (Exception $e) {
        error_log("list_by_user.php table check failed: " . $e->getMessage());
        Response::error('Database table not found: ' . $e->getMessage(), 500);
    }

    // 根據規格文件更新的 SQL 查詢
    // - 使用 participant_id 而不是 participant_id
    // - 確保 status 欄位使用正確的 ENUM 值
    $sql = "
      SELECT
        ta.id                AS application_id,
        ta.status            AS application_status,
        ta.cover_letter,
        ta.created_at        AS application_created_at,
        ta.updated_at        AS application_updated_at,

        t.id                 AS task_id,
        t.title,
        t.description,
        t.location,
        t.reward_point,
        t.status_id,
        t.participant_id,    -- 根據規格：acceptor_id → participant_id
        t.created_at         AS task_created_at,
        t.updated_at         AS task_updated_at,
        
        s.code               AS status_code,
        s.display_name       AS status_display,

        -- 根據規格：使用 task_applications.status ENUM('applied','accepted','rejected','pending','completed','cancelled','dispute')
        CASE WHEN ta.status = 'accepted'
             THEN 'accepted_tasker'
             WHEN ta.status = 'rejected'
             THEN 'rejected_tasker'
             WHEN ta.status = 'applied'
             THEN 'applied_tasker'
             ELSE s.code
        END AS client_status_code,

        CASE WHEN ta.status = 'accepted'
             THEN 'In Progress (Tasker)' // 顯示進行中
             WHEN ta.status = 'rejected'
             THEN 'Rejected' // 顯示被拒絕
             WHEN ta.status = 'applied'
             THEN 'Open' // 顯示應徵中
             ELSE s.display_name
        END AS client_status_display,

        u.id                 AS creator_id,
        u.name               AS creator_name,
        u.avatar_url         AS creator_avatar,

        -- 簡化 chat_rooms 查詢，只檢查是否存在聊天室
        (SELECT cr.id FROM chat_rooms cr 
         WHERE cr.task_id = t.id 
         AND (cr.creator_id = t.creator_id OR cr.participant_id = ta.user_id)
         LIMIT 1) AS chat_room_id,
        
        -- 獲取最新聊天訊息片段
        COALESCE(
            (SELECT SUBSTRING(cm.content, 1, 100)
             FROM chat_messages cm 
             JOIN chat_rooms cr2 ON cm.room_id = cr2.id
             WHERE cr2.task_id = t.id 
             AND (cr2.creator_id = t.creator_id OR cr2.participant_id = ta.user_id)
             ORDER BY cm.created_at DESC 
             LIMIT 1),
            'No conversation yet'
        ) AS latest_message_snippet
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN task_statuses s ON s.id = t.status_id
      LEFT JOIN users u ON u.id = t.creator_id
      WHERE ta.user_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    // 執行查詢
    $rows = $db->fetchAll($sql, [$userId, $limit, $offset]);
    
    // 確保 rows 是陣列
    if (!is_array($rows)) {
        $rows = [];
    }

    // 提取任務 ID
    $taskIds = array_map(fn($r) => $r['task_id'], $rows);

    // 添加除錯資訊
    error_log("🔍 [My Works API] 查詢用戶 ID: $userId");
    error_log("🔍 [My Works API] 查詢結果數量: " . count($rows));
    error_log("🔍 [My Works API] 參數: " . json_encode([$userId, $limit, $offset]));

    Response::success([
      'applications' => $rows,
      'task_ids' => $taskIds,
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ],
      'debug_info' => [
        'user_id' => $userId,
        'result_count' => count($rows),
        'parameters' => [$userId, $limit, $offset],
        'database_schema' => 'updated_to_participant_id' // 標記已更新到新架構
      ]
    ], 'My applications retrieved');

} catch (Throwable $e) {
    // 使用 Throwable 捕獲所有錯誤，包括 Fatal errors
    error_log("list_by_user.php error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
    
    // 返回結構化錯誤而不是 500
    Response::success([
      'applications' => [],
      'task_ids' => [],
      'pagination' => [ 'limit' => $limit ?? 50, 'offset' => $offset ?? 0 ],
      'error' => 'db_error',
      'message' => $e->getMessage(),
      'debug_info' => [
        'user_id' => $userId ?? 0,
        'error_type' => get_class($e),
        'error_file' => $e->getFile(),
        'error_line' => $e->getLine(),
        'database_schema' => 'updated_to_participant_id'
      ]
    ], 'Error occurred while retrieving applications');
}
?>


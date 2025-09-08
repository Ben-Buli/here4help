  <?php
  require_once __DIR__ . '/../../../config/database.php';
  require_once __DIR__ . '/../../../utils/Response.php';

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
          error_log("my_work_applications.php table check failed: " . $e->getMessage());
          Response::error('Database table not found: ' . $e->getMessage(), 500);
      }

      // 根據規格文件更新的 SQL 查詢
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
          t.language_requirement,
          t.start_datetime     AS task_date,
          t.created_at         AS task_created_at,
          t.updated_at         AS task_updated_at,
          
          s.code               AS raw_status_code,
          s.display_name       AS raw_status_display,

          -- 根據規格：使用 task_applications.status ENUM('applied','accepted','pending_confirmation','dispute','completed','rejected','cancelled','withdrawn')
          CASE WHEN ta.status = 'accepted'
              THEN 'accepted_tasker'
              WHEN ta.status = 'rejected'
              THEN 'rejected_tasker'
              WHEN ta.status = 'applied'
              THEN 'applied_tasker'
              ELSE s.code
          END AS status_code,

          CASE WHEN ta.status = 'accepted'
              THEN 'In Progress' -- 顯示進行中
              WHEN ta.status = 'rejected'
              THEN 'Rejected' -- 顯示被拒絕
              WHEN ta.status = 'applied'
              THEN 'Open' -- 顯示應徵中
              ELSE s.display_name
          END AS status_display,

          u.id                 AS creator_id,
          u.name               AS creator_name,
          u.avatar_url         AS creator_avatar,

          -- 正確的 chat_rooms 查詢：確保 creator_id 和 participant_id 都匹配
          (SELECT cr.id FROM chat_rooms cr 
          WHERE cr.task_id = t.id 
          AND cr.creator_id = t.creator_id 
          AND cr.participant_id = ta.user_id
          LIMIT 1) AS chat_room_id,
          
          -- 獲取最新聊天訊息片段：確保使用正確的聊天室
          COALESCE(
              (SELECT SUBSTRING(cm.content, 1, 100)
              FROM chat_messages cm 
              JOIN chat_rooms cr2 ON cm.room_id = cr2.id
              WHERE cr2.task_id = t.id 
              AND cr2.creator_id = t.creator_id 
              AND cr2.participant_id = ta.user_id
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
      
      // 添加詳細的欄位調試資訊
      if (!empty($rows)) {
          $sampleRow = $rows[0];
          error_log("🔍 [My Works API] 樣本資料欄位:");
          error_log("  - application_id: " . ($sampleRow['application_id'] ?? 'NULL'));
          error_log("  - application_status: " . ($sampleRow['application_status'] ?? 'NULL'));
          error_log("  - task_id: " . ($sampleRow['task_id'] ?? 'NULL'));
          error_log("  - title: " . ($sampleRow['title'] ?? 'NULL'));
          error_log("  - raw_status_code: " . ($sampleRow['raw_status_code'] ?? 'NULL'));
          error_log("  - raw_status_display: " . ($sampleRow['raw_status_display'] ?? 'NULL'));
          error_log("  - status_code: " . ($sampleRow['status_code'] ?? 'NULL'));
          error_log("  - status_display: " . ($sampleRow['status_display'] ?? 'NULL'));
          error_log("  - creator_id: " . ($sampleRow['creator_id'] ?? 'NULL'));
          error_log("  - creator_name: " . ($sampleRow['creator_name'] ?? 'NULL'));
          error_log("  - chat_room_id: " . ($sampleRow['chat_room_id'] ?? 'NULL'));
      }

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
              error_log("my_work_applications.php error: " . $e->getMessage() . " in " . $e->getFile() . " on line " . $e->getLine());
      
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


<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * 聊天室聚合詳情 API
 * GET /backend/api/chat/get_chat_detail_data.php?room_id=xxx
 * 回傳：room 基本資訊、task 基本資訊、user_role、chat_partner_info
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';

// 確保環境變數已載入
EnvLoader::load();

// CORS
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
  Response::error('Method not allowed', 405);
}

try {
  $db = Database::getInstance();

  // 解析授權 - 支援 Authorization header 和查詢參數
  $user_id = false;
  
  // 1. 嘗試從 Authorization header 獲取
  $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? 
                $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 
                '';
  
  if (empty($authHeader)) {
    // 嘗試從其他來源獲取
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
  }
  
  if (!empty($authHeader)) {
    $user_id = TokenValidator::validateAuthHeader($authHeader);
  }
  
  // 2. 如果 header 失敗，嘗試從查詢參數獲取（MAMP 兼容性）
  if ($user_id === false && isset($_GET['token'])) {
    $token = trim((string)$_GET['token']);
    if (!empty($token)) {
      $user_id = TokenValidator::validateToken($token);
    }
  }
  
  if ($user_id === false) {
    Response::error('Invalid token', 401);
  }
  
  $user_id = (int)$user_id;

  // 檢查參數
  $room_id = isset($_GET['room_id']) ? trim((string)$_GET['room_id']) : '';
  if ($room_id === '') {
    Response::validationError(['room_id' => 'room_id is required']);
  }

  // 首先檢查是否為客服聊天室
  $roomTypeCheck = $db->fetch("
    SELECT 'support' as source, id, type, user_id, admin_id, created_at
    FROM support_chat_rooms 
    WHERE id = ? AND (user_id = ? OR admin_id = ?)
    UNION ALL
    SELECT 'regular' as source, id, type, creator_id, participant_id, created_at
    FROM chat_rooms 
    WHERE id = ? AND (creator_id = ? OR participant_id = ?)
    LIMIT 1
  ", [$room_id, $user_id, $user_id, $room_id, $user_id, $user_id]);

  if (!$roomTypeCheck) {
    Response::error('Room not found or access denied', 404);
  }

  if ($roomTypeCheck['source'] === 'support') {
    // 處理客服聊天室
    $sql = "
      SELECT 
        scr.id AS room_id,
        scr.user_id AS creator_id,
        scr.admin_id AS participant_id,
        scr.type,
        scr.created_at AS room_created_at,

        -- 客服事件資訊
        se.id AS support_event_id,
        se.title,
        se.description,
        se.status AS support_status,
        se.rating AS support_rating,
        se.review AS support_review,
        se.created_at AS support_created_at,
        se.updated_at AS support_updated_at,
        se.closed_at AS support_closed_at,

        -- 雙方使用者 (使用別名以保持相容性)
        user.id AS creator_id,
        user.name AS creator_name,
        user.avatar_url AS creator_avatar,
        admin.id AS participant_id,
        admin.full_name AS participant_name,
        NULL AS participant_avatar
      FROM support_chat_rooms scr
      LEFT JOIN support_events se ON se.support_chat_room_id = scr.id
      LEFT JOIN users user ON user.id = scr.user_id
      LEFT JOIN admins admin ON admin.id = scr.admin_id
      WHERE scr.id = ? AND (scr.user_id = ? OR scr.admin_id = ?)
      ORDER BY se.created_at DESC
      LIMIT 1
    ";
    $row = $db->fetch($sql, [$room_id, $user_id, $user_id]);
  } else {
    // 處理一般聊天室（原有邏輯）
    $sql = "
      SELECT 
        cr.id AS room_id,
        cr.task_id,
        cr.creator_id,
        cr.participant_id,
        cr.type,
        cr.created_at AS room_created_at,

        -- 任務
        t.title,
        t.description,
        t.location,
        t.reward_point,
        t.task_date,
        t.language_requirement,
        t.status_id,
        ts.code AS status_code,
        ts.display_name AS status_display,
        t.created_at AS task_created_at,
        t.updated_at AS task_updated_at,

        -- 應徵狀態（用於 participant 視角）
        ta.status AS application_status,
        ta.created_at AS application_created_at,
        ta.updated_at AS application_updated_at,

        -- 雙方使用者
        creator.id AS creator_id,
        creator.name AS creator_name,
        creator.avatar_url AS creator_avatar,
        participant.id AS participant_id,
        participant.name AS participant_name,
        participant.avatar_url AS participant_avatar,

        -- 應徵問題（如果存在）
        aq.application_question,

        -- 創建者評分統計
        creator_stats.avg_rating AS creator_avg_rating,
        creator_stats.total_reviews AS creator_total_reviews,
        
        -- 參與者評分統計
        participant_stats.avg_rating AS participant_avg_rating,
        participant_stats.total_reviews AS participant_total_reviews
      FROM chat_rooms cr
      LEFT JOIN tasks t ON t.id = cr.task_id
      LEFT JOIN task_statuses ts ON ts.id = t.status_id
      LEFT JOIN task_applications ta ON ta.task_id = t.id AND ta.user_id = ?
      LEFT JOIN users creator ON creator.id = cr.creator_id
      LEFT JOIN users participant ON participant.id = cr.participant_id
      LEFT JOIN application_questions aq ON aq.task_id = t.id
      LEFT JOIN (
        SELECT 
          tasker_id,
          ROUND(AVG(rating), 1) AS avg_rating,
          COUNT(*) AS total_reviews
        FROM task_ratings
        GROUP BY tasker_id
      ) creator_stats ON creator_stats.tasker_id = creator.id
      LEFT JOIN (
        SELECT 
          tasker_id,
          ROUND(AVG(rating), 1) AS avg_rating,
          COUNT(*) AS total_reviews
        FROM task_ratings
        GROUP BY tasker_id
      ) participant_stats ON participant_stats.tasker_id = participant.id
      WHERE cr.id = ? AND (cr.creator_id = ? OR cr.participant_id = ?)
      LIMIT 1
    ";
    $row = $db->fetch($sql, [$user_id, $room_id, $user_id, $user_id]);
  }
  if (!$row) {
    Response::error('Room not found or access denied', 404);
  }

  // 檢查封鎖狀態（詳細資訊）
  $creatorId = (int)$row['creator_id'];
  $participantId = (int)$row['participant_id'];
  $isBlocked = false;
  $isBlockedByMe = false;
  $isBlockedByTarget = false;
  
  // 檢查我是否封鎖了對方
  $myBlockCheck = $db->fetch(
    "SELECT COUNT(*) as block_count FROM user_blocks 
     WHERE user_id = ? AND target_user_id = ?",
    [$user_id, $user_id == $creatorId ? $participantId : $creatorId]
  );
  
  if ($myBlockCheck && $myBlockCheck['block_count'] > 0) {
    $isBlockedByMe = true;
    $isBlocked = true;
  }
  
  // 檢查對方是否封鎖了我
  $targetBlockCheck = $db->fetch(
    "SELECT COUNT(*) as block_count FROM user_blocks 
     WHERE user_id = ? AND target_user_id = ?",
    [$user_id == $creatorId ? $participantId : $creatorId, $user_id]
  );
  
  if ($targetBlockCheck && $targetBlockCheck['block_count'] > 0) {
    $isBlockedByTarget = true;
    $isBlocked = true;
  }

  // 決定當前使用者角色
  $user_role = ($row['creator_id'] == $user_id) ? 'creator' : 'participant';

  // 生成對方資訊
  if ($user_role === 'creator') {
    // 創建者視角：對方是參與者
    $partner = [
      'id' => $row['participant_id'] ? (int)$row['participant_id'] : null,
      'name' => $row['participant_name'],
      'avatar' => $row['participant_avatar'],
      'rating' => isset($row['participant_avg_rating']) && $row['participant_avg_rating'] ? (float)$row['participant_avg_rating'] : null,
      'reviewsCount' => isset($row['participant_total_reviews']) && $row['participant_total_reviews'] ? (int)$row['participant_total_reviews'] : null,
    ];
  } else {
    // 參與者視角：對方是創建者
    $partner = [
      'id' => (int)$row['creator_id'],
      'name' => $row['creator_name'],
      'avatar' => $row['creator_avatar'],
      'rating' => isset($row['creator_avg_rating']) && $row['creator_avg_rating'] ? (float)$row['creator_avg_rating'] : null,
      'reviewsCount' => isset($row['creator_total_reviews']) && $row['creator_total_reviews'] ? (int)$row['creator_total_reviews'] : null,
    ];
  }

  // 整理回傳資料
  $room = [
    'id' => (string)$row['room_id'],
    'task_id' => isset($row['task_id']) && $row['task_id'] ? (string)$row['task_id'] : null,
    'creator_id' => (int)$row['creator_id'],
    'participant_id' => $row['participant_id'] ? (int)$row['participant_id'] : null,
    'type' => $row['type'],
    'created_at' => $row['room_created_at'] ?? null,
  ];

  // 根據聊天室類型提供不同的資料結構
  if ($roomTypeCheck['source'] === 'support') {
    // 客服聊天室：提供客服事件資訊
    $supportEvent = [
      'id' => $row['support_event_id'] ? (string)$row['support_event_id'] : null,
      'title' => $row['title'],
      'description' => $row['description'],
      'status' => $row['support_status'],
      'rating' => $row['support_rating'] ? (int)$row['support_rating'] : null,
      'review' => $row['support_review'],
      'created_at' => $row['support_created_at'] ?? null,
      'updated_at' => $row['support_updated_at'] ?? null,
      'closed_at' => $row['support_closed_at'] ?? null,
    ];

    Response::success([
      'room' => $room,
      'support_event' => $supportEvent,
      'user_role' => $user_role,
      'chat_partner_info' => $partner,
      'is_blocked' => $isBlocked,
      'block_info' => [
        'blocked_by_me' => $isBlockedByMe,
        'blocked_by_target' => $isBlockedByTarget,
      ],
    ], 'Support chat detail loaded');
  } else {
    // 一般聊天室：提供任務資訊
    $task = [
      'id' => (string)$row['task_id'],
      'title' => $row['title'],
      'description' => $row['description'],
      'location' => $row['location'],
      'reward_point' => $row['reward_point'],
      'task_date' => $row['task_date'],
      'language_requirement' => $row['language_requirement'],
      'application_question' => $row['application_question'],
      'status' => [
        'id' => $row['status_id'],
        'code' => $row['status_code'],
        'display_name' => $row['status_display'],
      ],
      'application_status' => $row['application_status'] ?? null,
      'application_created_at' => $row['application_created_at'] ?? null,
      'application_updated_at' => $row['application_updated_at'] ?? null,
      'created_at' => $row['task_created_at'] ?? null,
      'updated_at' => $row['task_updated_at'] ?? null,
    ];

    Response::success([
      'room' => $room,
      'task' => $task,
      'user_role' => $user_role,
      'chat_partner_info' => $partner,
      'is_blocked' => $isBlocked,
      'block_info' => [
        'blocked_by_me' => $isBlockedByMe,
        'blocked_by_target' => $isBlockedByTarget,
      ],
    ], 'Chat detail loaded');
  }

} catch (Throwable $e) {
  error_log('[get_chat_detail_data] error: ' . $e->getMessage());
  error_log('[get_chat_detail_data] trace: ' . $e->getTraceAsString());
  Response::serverError('Failed to get chat detail: ' . $e->getMessage());
} 
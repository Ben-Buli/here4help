<?php
/**
 * 聊天室聚合詳情 API
 * GET /backend/api/chat/get_chat_detail_data.php?room_id=xxx
 * 回傳：room 基本資訊、task 基本資訊、user_role、chat_partner_info
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';

// 確保環境變數已載入
EnvLoader::load();

// CORS
Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
  Response::error('Method not allowed', 405);
}

try {
  $db = Database::getInstance();

  // 解析授權
  $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? 
                $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 
                '';
  
  if (empty($authHeader)) {
    // 嘗試從其他來源獲取
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
  }
  
  if (empty($authHeader)) {
    Response::error('Authorization header required', 401);
  }
  
  $user_id = TokenValidator::validateAuthHeader($authHeader);
  if ($user_id === false) {
    Response::error('Invalid token', 401);
  }
  
  $user_id = (int)$user_id;

  // 檢查參數
  $room_id = isset($_GET['room_id']) ? trim((string)$_GET['room_id']) : '';
  if ($room_id === '') {
    Response::validationError(['room_id' => 'room_id is required']);
  }

  // 讀取聊天室與任務、使用者資訊（並做訪問控制）
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
      t.status_id,
      ts.code AS status_code,
      ts.display_name AS status_display,
      t.created_at AS task_created_at,
      t.updated_at AS task_updated_at,

      -- 雙方使用者
      creator.id AS creator_id,
      creator.name AS creator_name,
      creator.avatar_url AS creator_avatar,
      participant.id AS participant_id,
      participant.name AS participant_name,
      participant.avatar_url AS participant_avatar
    FROM chat_rooms cr
    LEFT JOIN tasks t ON t.id = cr.task_id
    LEFT JOIN task_statuses ts ON ts.id = t.status_id
    LEFT JOIN users creator ON creator.id = cr.creator_id
    LEFT JOIN users participant ON participant.id = cr.participant_id
    WHERE cr.id = ? AND (cr.creator_id = ? OR cr.participant_id = ?)
    LIMIT 1
  ";

  $row = $db->fetch($sql, [$room_id, $user_id, $user_id]);
  if (!$row) {
    Response::error('Room not found or access denied', 404);
  }

  // 決定當前使用者角色
  $user_role = ($row['creator_id'] == $user_id) ? 'creator' : 'participant';

  // 生成對方資訊
  if ($user_role === 'creator') {
    $partner = [
      'id' => (int)$row['participant_id'],
      'name' => $row['participant_name'],
      'avatar' => $row['participant_avatar'],
    ];
  } else {
    $partner = [
      'id' => (int)$row['creator_id'],
      'name' => $row['creator_name'],
      'avatar' => $row['creator_avatar'],
    ];
  }

  // 整理回傳資料
  $room = [
    'id' => (string)$row['room_id'],
    'task_id' => (string)$row['task_id'],
    'creator_id' => (int)$row['creator_id'],
    'participant_id' => (int)$row['participant_id'],
    'type' => $row['type'],
    'created_at' => $row['room_created_at'] ?? null,
  ];

  $task = [
    'id' => (string)$row['task_id'],
    'title' => $row['title'],
    'description' => $row['description'],
    'location' => $row['location'],
    'reward_point' => $row['reward_point'],
    'status_id' => $row['status_id'],
    'status_code' => $row['status_code'],
    'status_display' => $row['status_display'],
    'created_at' => $row['task_created_at'] ?? null,
    'updated_at' => $row['task_updated_at'] ?? null,
  ];

  Response::success([
    'room' => $room,
    'task' => $task,
    'user_role' => $user_role,
    'chat_partner_info' => $partner,
  ], 'Chat detail loaded');

} catch (Throwable $e) {
  error_log('[get_chat_detail_data] error: ' . $e->getMessage());
  error_log('[get_chat_detail_data] trace: ' . $e->getTraceAsString());
  Response::serverError('Failed to get chat detail: ' . $e->getMessage());
} 
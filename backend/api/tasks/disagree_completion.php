<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  // Auth（取得操作者）
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    throw new Exception('Authorization header required');
  }
  $actor_id = TokenValidator::validateAuthHeader($auth_header);
  if (!$actor_id) { throw new Exception('Invalid or expired token'); }
  $actor_id = (int)$actor_id;

  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  $task_id = (string)($input['task_id'] ?? '');
  $reason = trim((string)($input['reason'] ?? ''));
  
  // 驗證輸入
  $errors = [];
  if ($task_id === '') {
    $errors['task_id'] = 'required';
  }
  if ($reason === '') {
    $errors['reason'] = 'required';
  } elseif (strlen($reason) > 300) {
    $errors['reason'] = 'max_length_exceeded';
  }
  
  if (!empty($errors)) {
    Response::validationError($errors);
  }
  
  // 清理理由內容（移除 HTML 標籤和敏感字）
  $reason = strip_tags($reason);
  $reason = htmlspecialchars($reason, ENT_QUOTES, 'UTF-8');

  $db = Database::getInstance();

  // 讀取現有任務與狀態
  $task = $db->fetch(
    "SELECT t.*, s.code AS status_code FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
    [$task_id]
  );
  if (!$task) {
    Response::error('Task not found', 404);
  }
  $oldStatusCode = isset($task['status_code']) ? (string)$task['status_code'] : null;

  // 將 pending_confirmation 改回 in_progress（以 task_statuses.code 查找 id）
  $statusRow = $db->fetch("SELECT id FROM task_statuses WHERE code = 'in_progress' LIMIT 1");
  if ($statusRow && isset($statusRow['id'])) {
    $db->query("UPDATE tasks SET status_id = ?, updated_at = NOW() WHERE id = ?", [(int)$statusRow['id'], $task_id]);
  } else {
    // 回退：若 task_statuses 不存在對應代碼，嘗試以文本欄位處理（不建議）
    try {
      $db->query("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS status VARCHAR(64) NULL");
    } catch (Exception $e) {}
    $db->query("UPDATE tasks SET status = 'In Progress', updated_at = NOW() WHERE id = ?", [$task_id]);
  }

  // 記錄使用者操作日誌（寫入 user_active_log）
  try {
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $db->query(
      "INSERT INTO user_active_log (user_id, actor_type, actor_id, action, field, old_value, new_value, reason, ip, created_at)
       VALUES (?, 'user', ?, 'disagree_completion', 'status', ?, ?, ?, ?, NOW())",
      [
        $actor_id, // 受影響的 user_id：此處以操作者本人記錄；若需記錄任務雙方可再擴充
        $actor_id,
        $oldStatusCode ?? null,
        'in_progress',
        ($reason !== '' ? $reason : null),
        $ip
      ]
    );
  } catch (Exception $e) {
    // 不影響主流程
  }

  // 僅在當前房間發送系統訊息（kind = system）。
  try {
    $room = $db->fetch(
      "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
      [$task_id, $actor_id, $actor_id]
    );
    if ($room && isset($room['id'])) {
      $content = 'Completion request was rejected.' . ($reason !== '' ? (' Reason: ' . $reason) : '');
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, 'system')",
        [(int)$room['id'], $actor_id, $content]
      );
    }
  } catch (Exception $e) {
    // 不阻斷
  }

  // 回傳最新任務
  $updated = $db->fetch(
    "SELECT t.*, s.code AS status_code, s.display_name AS status_display
       FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
    [$task_id]
  );

  Response::success([
    'task' => $updated,
    'message' => 'Completion request reverted to in_progress',
  ], 'Disagree processed');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

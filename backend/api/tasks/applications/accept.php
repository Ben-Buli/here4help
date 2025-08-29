<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/TokenValidator.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/socket_notifier.php';


const ACCEPT_MESSAGE = "Congratulations! You’ve been selected as the tasker for this task. Let’s get started!";
const REJECT_MESSAGE = "Unfortunately, you were not selected as the tasker for this task. Please try again!";

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
  $application_id = (string)($input['application_id'] ?? '');
  $user_id = (string)($input['user_id'] ?? '');
  $poster_id = (string)($input['poster_id'] ?? '');
  
  if ($task_id === '') Response::validationError(['task_id' => 'required']);
  if ($application_id === '' && $user_id === '') Response::validationError(['application_id or user_id' => 'required']);
  if ($poster_id === '') Response::validationError(['poster_id' => 'required']);

  $db = Database::getInstance();

  // 讀取任務資訊
  $task = $db->fetch(
    "SELECT t.*, s.code AS status_code FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
    [$task_id]
  );
  if (!$task) {
    Response::error('Task not found', 404);
  }

  // 驗證操作者是否為任務創建者
  if ((int)$task['creator_id'] !== (int)$poster_id) {
    Response::error('Only task creator can accept applications', 403);
  }

  // 驗證任務狀態必須為 open
  if ($task['status_code'] !== 'open') {
    Response::error('Task must be in open status to accept applications', 400);
  }

  // 確定要指派的用戶ID
  $target_user_id = null;
  if ($user_id !== '') {
    $target_user_id = $user_id;
  } else {
    // 從 application_id 取得 user_id
    $application = $db->fetch(
      "SELECT user_id FROM task_applications WHERE id = ? AND task_id = ?",
      [$application_id, $task_id]
    );
    if (!$application) {
      Response::error('Application not found', 404);
    }
    $target_user_id = $application['user_id'];
  }

  // 驗證目標用戶存在
  $targetUser = $db->fetch("SELECT id, name FROM users WHERE id = ?", [$target_user_id]);
  if (!$targetUser) {
    Response::error('Target user not found', 404);
  }

  // 開始資料庫交易
  $db->beginTransaction();

  try {
      // 1. 更新任務狀態為 in_progress 並設定 participant_id
    // task_statuses.id = 2 = in_progress
      try { 
        $db->query("UPDATE tasks SET status_id = ?, participant_id = ?, updated_at = NOW() WHERE id = ?", 
          [2, $target_user_id, $task_id]);
      } catch (Exception $e) {
        Response::error('Failed to update task status to in_progress(id: 2): ' . $e->getMessage(), 500);
      }
   

    // 2. 更新應徵者狀態
    // task_applications.status = 'accepted‘，落選則為'rejected'
    $rejectedApplicationIds = [];
    
    $assignedApplicationStatus = $db->fetch(
      "SELECT status FROM task_applications WHERE task_id = ? AND user_id = ? limit 1",
      [$task_id, $target_user_id]
    );

   $isApplied = false;
    $acceptFailedReason = null;
    switch ($assignedApplicationStatus['status']) {
      case 'applied':
        $isApplied = true;
        break;
      case 'withdrawn':
        $isApplied = false;
        $acceptFailedReason = 'Applicant is withdrawn from the task.'; // 使用者已經退出申請
        break;
      default:
        $isApplied = false;
        $acceptFailedReason = 'The applicant is on other application status.'; // 使用者狀態異常：應該為open才可以被指派
        break;
    }

    

    // 接受指定的應徵
    if ($application_id !== '' && $isApplied) {
      $db->query("UPDATE task_applications SET status = 'accepted', updated_at = NOW() WHERE id = ?", [$application_id]);
    } else {
      // 如果沒有指定 application_id，直接創建新的 accepted 應徵記錄
      // 依賴 (task_id, user_id) 唯一鍵避免重複記錄
      $db->query("
        INSERT INTO task_applications (task_id, user_id, status, created_at, updated_at) 
        VALUES (?, ?, 'accepted', NOW(), NOW())
        ON DUPLICATE KEY UPDATE status = 'accepted', updated_at = NOW()
      ", [$task_id, $target_user_id]);
    }
    
    // 手動拒絕其他已投遞（Applied）應徵（已移除觸發器）
    // 取得同任務但不同使用者的其他應徵 id
    $others = $db->fetchAll(
      "SELECT id FROM task_applications WHERE task_id = ? AND user_id <> ? AND status = 'applied'",
      [$task_id, $target_user_id]
    );
    $rejectedApplicationIds = array_map(fn($r) => (int)$r['id'], $others ?? []);

    // 將其他應徵設為 rejected
    if (!empty($rejectedApplicationIds)) {
      $db->query(
        "UPDATE task_applications SET status = 'rejected', updated_at = NOW() WHERE task_id = ? AND user_id <> ?",
        [$task_id, $target_user_id]
      );
    }

    // 3. 寫入 user_active_log
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $metadata = json_encode([
      'task_id' => $task_id,
      'application_id' => $application_id,
      'room_id' => null, // 可從 chat_rooms 查詢
      'rejected_application_ids' => $rejectedApplicationIds
    ]);
    
    $db->query("
      INSERT INTO user_active_log (
        user_id, actor_type, actor_id, action, field, old_value, new_value, 
        reason, metadata, ip, created_at
      ) VALUES (?, 'user', ?, 'Assign to only one participant, and reject other applications.', 'participant_id', NULL, ?, 
        NULL, ?, ?, NOW())
    ", [$actor_id, $actor_id, $target_user_id, $metadata, $ip]);

    // 4. 發送系統訊息到聊天室
    // #region 發送訊息給accepted的用戶
    try {
      $room = $db->fetch(
        "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
        [$task_id, $actor_id, $target_user_id]
      );
      
      // 發送系統訊息到任務被指派者的聊天室
      if ($room && isset($room['id'])) {
        $content = ACCEPT_MESSAGE;
        $db->query(
          "INSERT INTO chat_messages (room_id, from_user_id, content, kind, created_at) VALUES (?, ?, ?, 'system', NOW())",
          [(int)$room['id'], $actor_id, $content]
        );
      }
    } catch (Exception $e) {
      // 不阻斷主流程
      error_log("Failed to send system accepted message: " . $e->getMessage());
    }
    // #endregion

    // #region 發送訊息給rejected的用戶
    try {
      $rejected_users = $db->fetchAll(
        "SELECT user_id FROM task_applications WHERE task_id = ? AND user_id <> ? AND status = 'rejected'",
        [$task_id, $target_user_id]
      );
      foreach ($rejected_users as $rejected_user) {
        $room = $db->fetch(
          "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
          [$task_id, $actor_id, $rejected_user['user_id']]
        );
        if ($room && isset($room['id'])) {
          $content = REJECT_MESSAGE;
          $db->query(
            "INSERT INTO chat_messages (room_id, from_user_id, content, kind, created_at) VALUES (?, ?, ?, 'system', NOW())",
            [(int)$room['id'], $actor_id, $content]
          );
        }
      }
    } catch (Exception $e) {
      // 不阻斷主流程
      error_log("Failed to send system rejected message: " . $e->getMessage());
    }
    // #endregion

    // 提交交易
    $db->commit();

    // 發送 Socket 通知
    try {
      $socketNotifier = SocketNotifier::getInstance();
      $userIds = $socketNotifier->getTaskUserIds($task_id);
      $room = $db->fetch(
        "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
        [$task_id, $actor_id, $target_user_id]
      );
      $roomId = $room ? $room['id'] : null;
      
      // 通知任務狀態更新
      $statusData = [
        'code' => 'in_progress',
        'display_name' => 'In Progress',
        'progress_ratio' => 0.3
      ];
      $socketNotifier->notifyTaskStatusUpdate($task_id, $roomId, $statusData, $userIds);
      
      // 通知應徵狀態更新
      $socketNotifier->notifyApplicationStatusUpdate($task_id, $roomId, 'accepted', $userIds);
    } catch (Exception $e) {
      error_log("Socket notification failed: " . $e->getMessage());
    }

    // 回傳更新後的任務資訊
    $updated = $db->fetch(
      "SELECT t.*, s.code AS status_code, s.display_name AS status_display
         FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
      [$task_id]
    );

    Response::success([
      'task' => $updated,
      'assigned_user' => [
        'id' => $target_user_id,
        'name' => $targetUser['name']
      ],
      'rejected_count' => count($rejectedApplicationIds),
      'message' => 'Application accepted successfully'
    ], 'Application accepted');

  } catch (Exception $e) {
    $db->rollback();
    throw $e;
  }

} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>

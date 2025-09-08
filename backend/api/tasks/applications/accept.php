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
  error_log("[accept.php] 🔍 Request started");
  
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Method not allowed');
  }

  // Auth（取得操作者）
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  error_log("[accept.php] 🔍 Auth header: " . (empty($auth_header) ? 'empty' : 'found'));
  
  if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $m)) {
    error_log("[accept.php] ❌ Authorization header missing or invalid");
    throw new Exception('Authorization header required');
  }
  $actor_id = TokenValidator::validateAuthHeader($auth_header);
  error_log("[accept.php] 🔍 Token validation result: " . ($actor_id ? 'success' : 'failed'));
  
  if (!$actor_id) { 
    error_log("[accept.php] ❌ Invalid or expired token");
    throw new Exception('Invalid or expired token'); 
  }
  $actor_id = (int)$actor_id;
  error_log("[accept.php] 🔍 Actor ID: $actor_id");

  $raw = file_get_contents('php://input');
  error_log("[accept.php] 🔍 Raw input: " . $raw);
  
  $input = json_decode($raw, true) ?? [];
  error_log("[accept.php] 🔍 JSON decoded input: " . json_encode($input));
  
  $task_id = (string)($input['task_id'] ?? '');
  $application_id = (string)($input['application_id'] ?? '');
  $user_id = (string)($input['user_id'] ?? '');
  $poster_id = (string)($input['poster_id'] ?? '');
  
  error_log("[accept.php] 🔍 Parsed parameters:");
  error_log("[accept.php]   - task_id: '$task_id'");
  error_log("[accept.php]   - application_id: '$application_id'");
  error_log("[accept.php]   - user_id: '$user_id'");
  error_log("[accept.php]   - poster_id: '$poster_id'");
  
  if ($task_id === '') {
    error_log("[accept.php] ❌ Validation failed - task_id required");
    Response::validationError(['task_id' => 'required']);
  }
  if ($application_id === '' && $user_id === '') {
    error_log("[accept.php] ❌ Validation failed - application_id or user_id required");
    Response::validationError(['application_id or user_id' => 'required']);
  }
  if ($poster_id === '') {
    error_log("[accept.php] ❌ Validation failed - poster_id required");
    Response::validationError(['poster_id' => 'required']);
  }

  $db = Database::getInstance();

  // 讀取任務資訊
  error_log("[accept.php] 🔍 Fetching task information for task_id: $task_id");
  $task = $db->fetch(
    "SELECT t.*, s.code AS status_code FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
    [$task_id]
  );
  error_log("[accept.php] 🔍 Task query result: " . json_encode($task));
  
  if (!$task) {
    error_log("[accept.php] ❌ Task not found: $task_id");
    Response::notFound('Task not found');
  }

  // 驗證操作者是否為任務創建者
  error_log("[accept.php] 🔍 Checking permissions: actor_id=$actor_id, poster_id=$poster_id, task creator_id=" . $task['creator_id']);
  if ((int)$task['creator_id'] !== (int)$poster_id) {
    error_log("[accept.php] ❌ Permission denied: task creator=" . $task['creator_id'] . ", poster_id=$poster_id");
    Response::forbidden('Only task creator can accept applications');
  }

  // 確定要指派的用戶ID（先定義變數）
  $target_user_id = null;
  if ($user_id !== '') {
    $target_user_id = $user_id;
    error_log("[accept.php] 🔍 Using provided user_id: $user_id");
  } else {
    // 從 application_id 取得 user_id
    error_log("[accept.php] 🔍 Fetching user_id from application_id: $application_id");
    $application = $db->fetch(
      "SELECT user_id FROM task_applications WHERE id = ? AND task_id = ?",
      [$application_id, $task_id]
    );
    error_log("[accept.php] 🔍 Application query result: " . json_encode($application));
    
    if (!$application) {
      error_log("[accept.php] ❌ Application not found: application_id=$application_id, task_id=$task_id");
      Response::notFound('Application not found');
    }
    $target_user_id = $application['user_id'];
    error_log("[accept.php] 🔍 Resolved target_user_id: $target_user_id");
  }

  // 驗證任務狀態必須為 open
  if ($task['status_code'] !== 'open') {
    // 檢查是否已經有參與者
    if (!empty($task['participant_id'])) {
      $existingParticipant = $db->fetch("SELECT name FROM users WHERE id = ?", [$task['participant_id']]);
      $participantName = $existingParticipant ? $existingParticipant['name'] : 'Unknown User';
      
      if ((int)$task['participant_id'] === (int)$target_user_id) {
        Response::badRequest("This user has already been assigned as the tasker for this task. Current participant: $participantName");
      } else {
        Response::badRequest("This task already has an assigned tasker. Cannot accept another application. Current participant: $participantName");
      }
    } else {
      Response::badRequest('Task must be in open status to accept applications');
    }
  }

  // 驗證目標用戶存在
  $targetUser = $db->fetch("SELECT id, name FROM users WHERE id = ?", [$target_user_id]);
  if (!$targetUser) {
    Response::notFound('Target user not found');
  }

  // 開始資料庫交易
  error_log("[accept.php] 🔍 Starting transaction");
  $db->beginTransaction();

  try {
      // 1. 更新任務狀態為 in_progress 並設定 participant_id
    // task_statuses.id = 2 = in_progress
      error_log("[accept.php] 🔍 Updating task status to in_progress");
      try { 
        $result = $db->query("UPDATE tasks SET status_id = ?, participant_id = ?, updated_at = NOW() WHERE id = ?", 
          [2, $target_user_id, $task_id]);
        error_log("[accept.php] 🔍 Task update result: " . ($result ? 'success' : 'failed'));
      } catch (Exception $e) {
        error_log("[accept.php] ❌ Task update error: " . $e->getMessage());
        Response::serverError('Failed to update task status to in_progress(id: 2): ' . $e->getMessage());
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
      error_log("[accept.php] 🔍 Updating existing application to accepted: $application_id");
      $result = $db->query("UPDATE task_applications SET status = 'accepted', updated_at = NOW() WHERE id = ?", [$application_id]);
      error_log("[accept.php] 🔍 Application update result: " . ($result ? 'success' : 'failed'));
    } else {
      // 檢查該用戶是否已經有任何應徵記錄（不限於 accepted）
      error_log("[accept.php] 🔍 Checking for existing application record for user: $target_user_id");
      $existingApplication = $db->fetch(
        "SELECT id, status FROM task_applications WHERE task_id = ? AND user_id = ?",
        [$task_id, $target_user_id]
      );
      error_log("[accept.php] 🔍 Existing application query result: " . json_encode($existingApplication));
      
      if ($existingApplication) {
        // 用戶已經有應徵記錄，更新狀態為 accepted
        error_log("[accept.php] 🔍 Updating existing application status from '" . $existingApplication['status'] . "' to 'accepted'");
        $result = $db->query("
          UPDATE task_applications SET status = 'accepted', updated_at = NOW() 
          WHERE task_id = ? AND user_id = ?
        ", [$task_id, $target_user_id]);
        error_log("[accept.php] 🔍 Application status update result: " . ($result ? 'success' : 'failed'));
      } else {
        // 沒有應徵記錄，插入新記錄
        error_log("[accept.php] 🔍 Inserting new accepted application record");
        try {
          $result = $db->query("
            INSERT INTO task_applications (task_id, user_id, status, created_at, updated_at) 
            VALUES (?, ?, 'accepted', NOW(), NOW())
          ", [$task_id, $target_user_id]);
          error_log("[accept.php] 🔍 New application insert result: " . ($result ? 'success' : 'failed'));
        } catch (Exception $e) {
          error_log("[accept.php] ❌ Failed to insert new application: " . $e->getMessage());
          throw $e;
        }
      }
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
    error_log("[accept.php] 🔍 Preparing user_active_log entry");
    $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? ($_SERVER['REMOTE_ADDR'] ?? 'unknown');
    $metadata = json_encode([
      'task_id' => $task_id,
      'application_id' => $application_id,
      'room_id' => null, // 可從 chat_rooms 查詢
      'rejected_application_ids' => $rejectedApplicationIds
    ]);
    
    // 使用較短的 action 字符串
    $shortAction = "app_accepted:u{$target_user_id}";
    error_log("[accept.php] 🔍 Action string: '$shortAction' (length: " . strlen($shortAction) . ")");
    error_log("[accept.php] 🔍 Metadata: " . $metadata);
    error_log("[accept.php] 🔍 IP: $ip");
    
    try {
      $result = $db->query("
        INSERT INTO user_active_log (
          user_id, actor_type, actor_id, action, field, old_value, new_value, 
          reason, metadata, ip, created_at
        ) VALUES (?, 'user', ?, ?, 'participant_id', NULL, ?, 
          NULL, ?, ?, NOW())
      ", [$actor_id, $actor_id, $shortAction, $target_user_id, $metadata, $ip]);
      error_log("[accept.php] 🔍 User active log insert result: " . ($result ? 'success' : 'failed'));
    } catch (Exception $e) {
      error_log("[accept.php] ❌ User active log insert error: " . $e->getMessage());
      throw $e;
    }

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
          [(int)$room['id'], 1, $content] // 使用系統帳號 ID (1)
        );
      }
    } catch (Exception $e) {
      // 不阻斷主流程
      error_log("Failed to send system accepted message: " . $e->getMessage());
    }
    // #endregion


    // 發送 Socket 通知
    try {
      $socketNotifier = SocketNotifier::getInstance();
      $userIds = $socketNotifier->getTaskUserIds($task_id);
      
      // 🔧 獲取被接受者的聊天室acceptedRoom
      $acceptedRoom = $db->fetch(
        "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
        [$task_id, $actor_id, $target_user_id]
      );
      $acceptedRoomId = $acceptedRoom ? $acceptedRoom['id'] : null;
      
      // 通知任務狀態更新
      $statusData = [
        'code' => 'in_progress',
        'display_name' => 'In Progress',
        'progress_ratio' => 0.3
      ];
      $socketNotifier->notifyTaskStatusUpdate($task_id, $acceptedRoomId, $statusData, $userIds);
      
      // 通知被指派任務者的應徵狀態更新
      $socketNotifier->notifyApplicationStatusUpdate($task_id, $acceptedRoomId, 'accepted', [$target_user_id]);
      
      // 🔧 通知所有被拒絕的用戶（不包含被指派任務者target_user_id）
      $rejectedRooms = $db->fetchAll(
        "SELECT id, participant_id 
         FROM chat_rooms 
         WHERE task_id = ? AND participant_id != ?",
        [$task_id, $target_user_id]
      );
      
      error_log("[accept.php] 🔍 Found " . count($rejectedRooms) . " rejected rooms to notify");
      
      foreach ($rejectedRooms as $room) {
        $rejectedUserId = $room['participant_id'];
        $rejectedRoomId = $room['id'];
        error_log("[accept.php] 🔍 Processing rejected user: $rejectedUserId in room $rejectedRoomId");
        
        $socketNotifier->notifyApplicationStatusUpdate($task_id, $rejectedRoomId, 'rejected', [$rejectedUserId]);
        error_log("[accept.php] ✅ Socket notification sent to rejected user $rejectedUserId in room $rejectedRoomId");
        
        try {
          $db->query(
            "INSERT INTO chat_messages (room_id, from_user_id, content, kind, created_at) VALUES (?, ?, ?, 'system', NOW())",
            [$rejectedRoomId, 1, REJECT_MESSAGE] // 使用系統帳號 ID (1)
          );
          error_log("[accept.php] ✅ System message sent to rejected user $rejectedUserId in room $rejectedRoomId");
        } catch (Exception $e) {
          error_log("[accept.php] ❌ Failed to send system message to rejected user $rejectedUserId: " . $e->getMessage());
        }
      }
      
    } catch (Exception $e) {
      error_log("Socket notification failed: " . $e->getMessage());
    }

    // 提交事務
    error_log("[accept.php] 🔍 Committing transaction");
    $db->commit();
    error_log("[accept.php] ✅ Transaction committed successfully");

    // 回傳更新後的任務資訊
    error_log("[accept.php] 🔍 Fetching updated task information");
    $updated = $db->fetch(
      "SELECT t.*, s.code AS status_code, s.display_name AS status_display
         FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
      [$task_id]
    );

    error_log("[accept.php] ✅ Accept operation completed successfully");
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
    error_log("[accept.php] ❌ Transaction error: " . $e->getMessage());
    $db->rollback();
    throw $e;
  }

} catch (Exception $e) {
  error_log("[accept.php] ❌ Server error: " . $e->getMessage());
  error_log("[accept.php] ❌ Stack trace: " . $e->getTraceAsString());
  Response::serverError('Server error: ' . $e->getMessage());
}
?>

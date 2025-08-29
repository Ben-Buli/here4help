<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/socket_notifier.php';

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
  $preview = isset($input['preview']) ? (int)$input['preview'] : 0;
  if ($task_id === '') Response::validationError(['task_id' => 'required']);

  $db = Database::getInstance();

  // 讀取任務（取得金額與雙方、當前狀態）
  $task = $db->fetch(
    "SELECT t.*, s.code AS status_code, s.display_name AS status_display
       FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
    [$task_id]
  );
  if (!$task) { Response::error('Task not found', 404); }

  // 讀取手續費設定（isActive=1）
  // 若缺表，fallback 為 0% 手續費
  $feeRate = 0.0;
  try {
    $feeRow = $db->fetch("SELECT rate FROM task_completion_points_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1");
    if ($feeRow && isset($feeRow['rate'])) {
      $feeRate = (float)$feeRow['rate']; // 例如 0.02 表示 2%
    }
  } catch (Exception $e) {
    // 表不存在則以 0 手續費處理
    $feeRate = 0.0;
  }

  $amount = isset($task['reward_point']) ? (float)$task['reward_point'] : 0.0;
  $feeAmount = round($amount * $feeRate, 2);
  $netAmount = max(0.0, $amount - $feeAmount);

  // 僅試算：不更動任務狀態、不發送訊息、不寫交易
  if ($preview === 1) {
    Response::success([
      'task' => $task,
      'fee_rate' => $feeRate,
      'fee' => $feeAmount,
      'amount' => $amount,
      'net' => $netAmount,
      'preview' => true,
    ], 'Preview computed');
  }

  // 切換任務狀態至 completed（以 task_statuses.code）
  $statusRow = $db->fetch("SELECT id FROM task_statuses WHERE code = 'completed' LIMIT 1");
  if ($statusRow && isset($statusRow['id'])) {
    $db->query("UPDATE tasks SET status_id = ?, updated_at = NOW() WHERE id = ?", [(int)$statusRow['id'], $task_id]);
  } else {
    try { $db->query("ALTER TABLE tasks ADD COLUMN IF NOT EXISTS status VARCHAR(64) NULL"); } catch (Exception $e) {}
    $db->query("UPDATE tasks SET status = 'Completed', updated_at = NOW() WHERE id = ?", [$task_id]);
  }

  // 實作點數轉移與交易紀錄
  try {
    require_once __DIR__ . '/../../utils/PointTransactionLogger.php';
    require_once __DIR__ . '/../../utils/UserActiveLogEvent.php';
    
    $creatorId = (int)$task['creator_id'];
    $participantId = (int)$task['participant_id'];
    $taskTitle = $task['title'] ?? 'Unknown Task';
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
      // 1. 創建者支出任務獎勵（負數）
      $rewardTransactionId = PointTransactionLogger::logTaskSpending(
        $creatorId,
        (int)$amount,
        $task_id,
        $taskTitle
      );
      
      // 2. 接案者收入任務獎勵（正數）
      $earningTransactionId = PointTransactionLogger::logTaskEarning(
        $participantId,
        (int)$netAmount, // 接案者收到淨額（扣除手續費）
        $task_id,
        $taskTitle
      );
      
      // 3. 創建者支出手續費（負數）
      if ($feeAmount > 0) {
        $feeTransactionId = PointTransactionLogger::logFee(
          $creatorId,
          (int)$feeAmount,
          $task_id,
          "Service fee for task: $taskTitle"
        );
      }
      
      // 4. 記錄手續費收入到 fee_revenue_ledger
      if ($feeAmount > 0) {
        $feeRecordSql = "
          INSERT INTO fee_revenue_ledger (
            fee_type, src_transaction_id, task_id, payer_user_id, 
            amount_points, rate, note, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
        ";
        $db->execute($feeRecordSql, [
          'task_completion',
          $feeTransactionId ?? $rewardTransactionId,
          $task_id,
          $creatorId,
          (int)$feeAmount,
          $feeRate,
          "Task completion fee: $taskTitle"
        ]);
      }
      
      // 5. 寫入 user_active_log 兩筆支出紀錄
      $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
      $metadata = json_encode([
        'task_id' => $task_id,
        'amount' => $amount,
        'fee' => $feeAmount,
        'net' => $netAmount,
        'rate' => $feeRate,
        'reward_transaction_id' => $rewardTransactionId,
        'earning_transaction_id' => $earningTransactionId,
        'fee_transaction_id' => $feeTransactionId ?? null
      ]);
      
      // 支出獎勵記錄
      $db->execute("
        INSERT INTO user_active_log (
          user_id, actor_type, actor_id, action, field, old_value, new_value, 
          reason, metadata, ip, created_at
        ) VALUES (?, 'user', ?, 'task_completion_reward', 'points', NULL, NULL, 
          NULL, ?, ?, NOW())
      ", [$creatorId, $actor_id, $metadata, $ip]);
      
      // 支出手續費記錄
      if ($feeAmount > 0) {
        $db->execute("
          INSERT INTO user_active_log (
            user_id, actor_type, actor_id, action, field, old_value, new_value, 
            reason, metadata, ip, created_at
          ) VALUES (?, 'user', ?, 'task_completion_fee', 'points', NULL, NULL, 
            NULL, ?, ?, NOW())
        ", [$creatorId, $actor_id, $metadata, $ip]);
      }
      
      // 6. 更新用戶點數餘額
      $db->execute("
        UPDATE users 
        SET points = points - ? 
        WHERE id = ?
      ", [(int)$amount, $creatorId]);
      
      $db->execute("
        UPDATE users 
        SET points = points + ? 
        WHERE id = ?
      ", [(int)$netAmount, $participantId]);
      
      // 提交交易
      $db->commit();
      
    } catch (Exception $e) {
      $db->rollback();
      throw $e;
    }
    
  } catch (Exception $e) {
    // 如果點數轉移失敗，記錄錯誤但不阻斷主流程
    error_log("Task completion point transfer failed: " . $e->getMessage());
  }

  // 僅在當前房間發送系統訊息（顯示金額與手續費）
  try {
    $room = $db->fetch(
      "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
      [$task_id, $actor_id, $actor_id]
    );
    if ($room && isset($room['id'])) {
      $content = sprintf(
        'Task confirmed as completed. Amount: %.2f, Fee: %.2f (rate: %.2f%%), Net: %.2f',
        $amount, $feeAmount, $feeRate * 100.0, $netAmount
      );
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, 'system')",
        [(int)$room['id'], $actor_id, $content]
      );
    }
  } catch (Exception $e) {}

  // 發送 Socket 通知
  try {
    $socketNotifier = SocketNotifier::getInstance();
    $userIds = $socketNotifier->getTaskUserIds($task_id);
    $room = $db->fetch(
      "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
      [$task_id, $actor_id, $actor_id]
    );
    $roomId = $room ? $room['id'] : null;
    
    $statusData = [
      'code' => 'completed',
      'display_name' => 'Completed',
      'progress_ratio' => 1.0
    ];
    
    $socketNotifier->notifyTaskStatusUpdate($task_id, $roomId, $statusData, $userIds);
  } catch (Exception $e) {
    error_log("Socket notification failed: " . $e->getMessage());
  }

  // 回傳
  $updated = $db->fetch(
    "SELECT t.*, s.code AS status_code, s.display_name AS status_display
       FROM tasks t LEFT JOIN task_statuses s ON t.status_id = s.id WHERE t.id = ?",
    [$task_id]
  );

  Response::success([
    'task' => $updated,
    'fee_rate' => $feeRate,
    'fee' => $feeAmount,
    'amount' => $amount,
    'net' => $netAmount,
  ], 'Task confirmed and fees computed');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


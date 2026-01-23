<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/socket_notifier.php';
require_once __DIR__ . '/../../utils/TaskCompletionProcessor.php';

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  // Auth（取得操作者）- 支持 MAMP 兼容性
  $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
  $token = $_GET['token'] ?? $_POST['token'] ?? null;
  
  if (!$token && !empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
    $token = $matches[1];
  }
  
  if (!$token) {
    Response::unauthorized('No token provided');
  }
  
  $actor_id = TokenValidator::validateToken($token);
  if (!$actor_id) { 
    Response::unauthorized('Invalid or expired token'); 
  }
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

  // 權限檢查：只有任務創建者或管理員可以確認完成
  $creatorId = (int)$task['creator_id'];
  $isCreator = ($actor_id === $creatorId);
  
  // 檢查是否為管理員（permission = 99）
  $actorUser = $db->fetch("SELECT permission FROM users WHERE id = ?", [$actor_id]);
  $isAdmin = ($actorUser && (int)$actorUser['permission'] === 99);
  
  if (!$isCreator && !$isAdmin) {
    Response::error('Permission denied: Only task creator or admin can confirm completion', 403);
  }

  // 狀態檢查：只有 pending_confirmation 狀態的任務可以被確認完成
  if ($task['status_code'] !== 'pending_confirmation' && $task['status_code'] !== 'in_progress') {
    Response::error("Task status must be 'pending_confirmation' or 'in_progress' to confirm completion. Current status: " . ($task['status_code'] ?? 'unknown'), 400);
  }

  // 檢查任務是否有參與者
  $participantId = (int)($task['participant_id'] ?? 0);
  if ($participantId <= 0) {
    Response::error('Task has no participant assigned', 400);
  }

  // 僅試算：不更動任務狀態、不發送訊息、不寫交易
  if ($preview === 1) {
    try {
      $amountPreview = isset($task['reward_point']) ? (float)$task['reward_point'] : 0.0;
      $feeRatePreview = TaskCompletionProcessor::getPlatformFeeRate();
      $feePreview = round($amountPreview * $feeRatePreview, 2);
      $netPreview = max(0.0, $amountPreview - $feePreview);

      Response::success([
        'task' => $task,
        'fee_rate' => $feeRatePreview,
        'fee' => $feePreview,
        'amount' => $amountPreview,
        'net' => $netPreview,
        'preview' => true,
      ], 'Preview computed');
    } catch (Exception $e) {
      Response::error('Unable to load platform fee rate: ' . $e->getMessage(), 500);
    }
  }

  $taskResult = TaskCompletionProcessor::completeTask($task, [
    'actor_id' => $actor_id,
    'context' => 'chat_confirm',
  ]);

  $amount = (float)$taskResult['amount'];
  $feeAmount = (float)$taskResult['fee'];
  $feeRate = (float)$taskResult['fee_rate'];
  $netAmount = (float)$taskResult['net'];

  // 僅在當前房間發送系統訊息（顯示金額與手續費）
  try {
    $room = $db->fetch(
      "SELECT id FROM chat_rooms WHERE task_id = ? AND (creator_id = ? OR participant_id = ?) ORDER BY id DESC LIMIT 1",
      [$task_id, $actor_id, $actor_id]
    );
    if ($room && isset($room['id'])) {
      $content = sprintf(
        'Task confirmed as completed. Gross: %d pts, Fee (%.2f%%, paid by worker): %d pts, Net payout: %d pts',
        (int)$amount,
        $feeRate * 100,
        (int)$feeAmount,
        (int)$netAmount
      );
      $db->query(
        "INSERT INTO chat_messages (room_id, from_user_id, content, kind) VALUES (?, ?, ?, 'system')",
        [(int)$room['id'], 1, $content] // 使用系統帳號 ID (1)
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

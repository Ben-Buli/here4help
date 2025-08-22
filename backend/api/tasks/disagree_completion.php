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

  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  $task_id = (string)($input['task_id'] ?? '');
  $reason = trim((string)($input['reason'] ?? ''));
  if ($task_id === '') Response::validationError(['task_id' => 'required']);

  $db = Database::getInstance();
  // 建立紀錄表（最小可用）
  $db->query("CREATE TABLE IF NOT EXISTS task_disagreements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id VARCHAR(64) NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

  // 限制每任務最多 2 次
  $countRow = $db->fetch("SELECT COUNT(*) AS c FROM task_disagreements WHERE task_id = ?", [$task_id]);
  $c = isset($countRow['c']) ? (int)$countRow['c'] : 0;
  if ($c >= 2) {
    Response::error('Disagree limit reached (max 2).', 422);
  }

  $db->query("INSERT INTO task_disagreements (task_id, reason) VALUES (?, ?)", [$task_id, $reason]);

  Response::success(['task_id' => $task_id], 'Disagree recorded');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once '../../config/database.php';
require_once '../../utils/Response.php';

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  $task_id = (string)($input['task_id'] ?? '');
  if ($task_id === '') Response::validationError(['task_id' => 'required']);

  $db = Database::getInstance();
  // 最小可用：直接切換狀態至 Completed（後續補齊轉點/交易紀錄等邏輯）
  $db->query("UPDATE tasks SET status = 'Completed', updated_at = NOW() WHERE id = ?", [$task_id]);

  // 回傳最新任務物件（相容前端覆蓋）
  $task = $db->fetch("SELECT * FROM tasks WHERE id = ?", [$task_id]);
  Response::success($task, 'Task confirmed');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


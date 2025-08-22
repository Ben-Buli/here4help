<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
  }

  $task_id = isset($_GET['task_id']) ? (string)$_GET['task_id'] : '';
  if ($task_id === '') Response::validationError(['task_id' => 'required']);

  $db = Database::getInstance();
  $rating = $db->fetch("SELECT * FROM task_ratings WHERE task_id = ?", [$task_id]);
  if (!$rating) {
    Response::success(null, 'No review');
  }
  Response::success($rating, 'OK');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


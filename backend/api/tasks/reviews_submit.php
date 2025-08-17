<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit(0); }

require_once '../../config/database.php';
require_once '../../utils/TokenValidator.php';
require_once '../../utils/Response.php';

try {
  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
  }

  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  $task_id = (string)($input['task_id'] ?? '');
  $ratings = $input['ratings'] ?? [];
  $service = (int)($ratings['service'] ?? 0);
  $attitude = (int)($ratings['attitude'] ?? 0);
  $experience = (int)($ratings['experience'] ?? 0);
  $comment = isset($input['comment']) ? (string)$input['comment'] : null;
  if ($task_id === '') Response::validationError(['task_id' => 'required']);

  $db = Database::getInstance();
  $db->query("CREATE TABLE IF NOT EXISTS task_ratings (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id VARCHAR(64) NOT NULL,
    rating_service TINYINT NOT NULL,
    rating_attitude TINYINT NOT NULL,
    rating_experience TINYINT NOT NULL,
    comment VARCHAR(200) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_task (task_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

  $exists = $db->fetch("SELECT id FROM task_ratings WHERE task_id = ?", [$task_id]);
  if ($exists) {
    $db->query("UPDATE task_ratings SET rating_service=?, rating_attitude=?, rating_experience=?, comment=? WHERE task_id = ?",
      [$service, $attitude, $experience, $comment, $task_id]);
  } else {
    $db->query("INSERT INTO task_ratings (task_id, rating_service, rating_attitude, rating_experience, comment) VALUES (?, ?, ?, ?, ?)",
      [$task_id, $service, $attitude, $experience, $comment]);
  }

  $rating = $db->fetch("SELECT * FROM task_ratings WHERE task_id = ?", [$task_id]);
  Response::success($rating, 'Review saved');
} catch (Exception $e) {
  Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


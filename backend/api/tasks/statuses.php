<?php
/**
 * 任務狀態列表 API
 * GET /backend/api/tasks/statuses.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/Response.php';

// 設定 CORS 標頭
Response::setCorsHeaders();

// 僅允許 GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    $onlyActive = isset($_GET['active']) ? (int)$_GET['active'] : 1;

    $sql = "SELECT id, code, display_name, progress_ratio, sort_order, include_in_unread, is_active
            FROM task_statuses
            " . ($onlyActive ? "WHERE is_active = 1" : "") . "
            ORDER BY sort_order ASC, id ASC";

    $rows = $db->fetchAll($sql);

    Response::success($rows, 'Task statuses retrieved successfully');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


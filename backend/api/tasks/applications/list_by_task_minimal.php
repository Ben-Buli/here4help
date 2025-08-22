<?php
/**
 * 最簡化版本的 list_by_task.php
 * 只查詢基本的應徵記錄，不做複雜的 JOIN
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();

    $taskId = isset($_GET['task_id']) ? trim($_GET['task_id']) : '';
    if ($taskId === '') {
        Response::validationError(['task_id' => 'task_id is required']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);

    // 首先檢查任務是否存在
    $taskCheck = $db->fetch("SELECT id, title FROM tasks WHERE id = ?", [$taskId]);
    if (!$taskCheck) {
        Response::error("Task not found: $taskId", 404);
    }

    echo "<h1>調試: 最簡化版本</h1>\n";
    echo "<p>任務 ID: $taskId</p>\n";
    echo "<p>任務標題: {$taskCheck['title']}</p>\n";

    // 最簡化的查詢 - 只查詢 task_applications 表
    $sql = "
      SELECT
        ta.id                AS application_id,
        ta.user_id,
        ta.status            AS application_status,
        ta.cover_letter,
        ta.created_at,
        ta.updated_at
      FROM task_applications ta
      WHERE ta.task_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    echo "<h2>執行查詢</h2>\n";
    echo "<p>SQL: $sql</p>\n";
    echo "<p>參數: [$taskId, $limit, $offset]</p>\n";

    $rows = $db->fetchAll($sql, [$taskId, $limit, $offset]);
    
    echo "<p>查詢結果數量: " . count($rows) . "</p>\n";
    
    if (count($rows) > 0) {
        echo "<h3>查詢結果:</h3>\n";
        echo "<pre>" . print_r($rows, true) . "</pre>\n";
    } else {
        echo "<h3>沒有找到應徵記錄</h3>\n";
        
        // 檢查是否有其他數據
        $allApps = $db->fetchAll("SELECT COUNT(*) as count FROM task_applications");
        echo "<p>整個 task_applications 表的記錄數: {$allApps[0]['count']}</p>\n";
        
        if ($allApps[0]['count'] > 0) {
            $sampleApps = $db->fetchAll("SELECT task_id, user_id, status FROM task_applications LIMIT 3");
            echo "<p>示例記錄:</p>\n";
            echo "<pre>" . print_r($sampleApps, true) . "</pre>\n";
        }
    }

    // 如果是在瀏覽器中測試，顯示結果
    if (isset($_GET['debug'])) {
        echo "<h2>調試完成</h2>\n";
        echo "<p>✅ 查詢執行完成</p>\n";
    } else {
        // 正常 API 響應
        Response::success([
          'task_id' => $taskId,
          'applications' => $rows,
          'pagination' => [ 'limit' => $limit, 'offset' => $offset ],
          'debug_info' => [
            'query_type' => 'minimal',
            'result_count' => count($rows),
            'task_title' => $taskCheck['title']
          ]
        ], 'Applications by task retrieved (minimal)');
    }

} catch (Exception $e) {
    if (isset($_GET['debug'])) {
        echo "<h2>❌ 錯誤</h2>\n";
        echo "<p>錯誤信息: " . $e->getMessage() . "</p>\n";
        echo "<p>錯誤堆疊:</p>\n";
        echo "<pre>" . $e->getTraceAsString() . "</pre>\n>";
    } else {
        Response::error('Server error: ' . $e->getMessage(), 500);
    }
}
?>

<?php
/**
 * 調試版本的 list_by_task.php
 * 添加詳細的錯誤日誌和診斷信息
 */

// 啟用錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    echo "<h1>調試: list_by_task.php</h1>\n";
    
    // 檢查參數
    $taskId = isset($_GET['task_id']) ? trim($_GET['task_id']) : '';
    echo "<p>接收到的 task_id: '$taskId'</p>\n";
    
    if ($taskId === '') {
        Response::validationError(['task_id' => 'task_id is required']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);
    echo "<p>limit: $limit, offset: $offset</p>\n";

    echo "<h2>1. 測試數據庫連接</h2>\n";
    $db = Database::getInstance();
    echo "<p>✅ 數據庫連接成功</p>\n";

    echo "<h2>2. 檢查任務是否存在</h2>\n";
    $taskCheck = $db->fetch("SELECT id, title FROM tasks WHERE id = ?", [$taskId]);
    if ($taskCheck) {
        echo "<p>✅ 任務存在: {$taskCheck['title']}</p>\n";
    } else {
        echo "<p>❌ 任務不存在: $taskId</p>\n";
        Response::error("Task not found: $taskId", 404);
    }

    echo "<h2>3. 檢查表結構</h2>\n";
    
    // 檢查 task_applications 表
    try {
        $appCount = $db->fetch("SELECT COUNT(*) as count FROM task_applications WHERE task_id = ?", [$taskId]);
        echo "<p>✅ task_applications 表查詢成功，該任務的應徵數量: {$appCount['count']}</p>\n";
    } catch (Exception $e) {
        echo "<p>❌ task_applications 表查詢失敗: {$e->getMessage()}</p>\n";
    }

    // 檢查 task_statuses 表
    try {
        $statusCount = $db->fetch("SELECT COUNT(*) as count FROM task_statuses");
        echo "<p>✅ task_statuses 表查詢成功，總數: {$statusCount['count']}</p>\n";
    } catch (Exception $e) {
        echo "<p>❌ task_statuses 表查詢失敗: {$e->getMessage()}</p>\n";
    }

    // 檢查 users 表
    try {
        $userCount = $db->fetch("SELECT COUNT(*) as count FROM users");
        echo "<p>✅ users 表查詢成功，總數: {$userCount['count']}</p>\n";
    } catch (Exception $e) {
        echo "<p>❌ users 表查詢失敗: {$e->getMessage()}</p>\n";
    }

    echo "<h2>4. 執行完整查詢</h2>\n";
    
    $sql = "
      SELECT
        ta.id          AS application_id,
        ta.user_id,
        ta.status      AS application_status,
        ta.cover_letter,
        ta.answers_json,
        ta.created_at,
        ta.updated_at,
        u.name         AS applier_name,
        u.avatar_url   AS applier_avatar,
        t.id           AS task_id,
        t.creator_id,
        t.participant_id,
        s.code         AS task_status_code,
        s.display_name AS task_status_display
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN task_statuses s ON s.id = t.status_id
      LEFT JOIN users u ON u.id = ta.user_id
      WHERE ta.task_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    echo "<p>SQL 查詢:</p>\n";
    echo "<pre>$sql</pre>\n";
    echo "<p>參數: [$taskId, $limit, $offset]</p>\n";

    $rows = $db->fetchAll($sql, [$taskId, $limit, $offset]);
    echo "<p>✅ 查詢成功，結果數量: " . count($rows) . "</p>\n";

    if (count($rows) > 0) {
        echo "<p>📋 第一個結果:</p>\n";
        echo "<pre>" . print_r($rows[0], true) . "</pre>\n";
    }

    echo "<h2>5. 返回結果</h2>\n";
    
    $response = [
      'task_id' => $taskId,
      'applications' => $rows,
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ]
    ];
    
    echo "<p>響應數據:</p>\n";
    echo "<pre>" . print_r($response, true) . "</pre>\n";
    
    // 如果是在瀏覽器中測試，顯示結果
    if (isset($_GET['debug'])) {
        echo "<h2>6. 調試完成</h2>\n";
        echo "<p>✅ 所有測試通過</p>\n";
    } else {
        // 正常 API 響應
        Response::success($response, 'Applications by task retrieved');
    }

} catch (Exception $e) {
    echo "<h2>❌ 錯誤</h2>\n";
    echo "<p>錯誤類型: " . get_class($e) . "</p>\n";
    echo "<p>錯誤信息: " . $e->getMessage() . "</p>\n";
    echo "<p>錯誤文件: " . $e->getFile() . "</p>\n";
    echo "<p>錯誤行數: " . $e->getLine() . "</p>\n";
    echo "<p>錯誤堆疊:</p>\n";
    echo "<pre>" . $e->getTraceAsString() . "</pre>\n";
    
    // 如果是正常 API 調用，返回錯誤響應
    if (!isset($_GET['debug'])) {
        Response::error('Server error: ' . $e->getMessage(), 500);
    }
}
?>

<?php
/**
 * 調試版本的 list_by_user.php
 * 顯示詳細的診斷信息
 */

// 啟用錯誤報告
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once '../../../config/database.php';
require_once '../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    echo "<h1>調試: list_by_user.php</h1>\n";
    
    // 檢查參數
    $userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
    echo "<p>接收到的 user_id: '$userId'</p>\n";
    
    if ($userId <= 0) {
        Response::validationError(['user_id' => 'user_id is required and must be positive']);
    }

    $limit = (int)($_GET['limit'] ?? 50);
    $offset = (int)($_GET['offset'] ?? 0);
    echo "<p>limit: $limit, offset: $offset</p>\n";

    echo "<h2>1. 測試數據庫連接</h2>\n";
    $db = Database::getInstance();
    echo "<p>✅ 數據庫連接成功</p>\n";

    echo "<h2>2. 檢查用戶是否存在</h2>\n";
    $userCheck = $db->fetch("SELECT id, name, email FROM users WHERE id = ?", [$userId]);
    if ($userCheck) {
        echo "<p>✅ 用戶存在: {$userCheck['name']} ({$userCheck['email']})</p>\n";
    } else {
        echo "<p>❌ 用戶不存在: $userId</p>\n";
        Response::error("User not found: $userId", 404);
    }

    echo "<h2>3. 檢查表結構</h2>\n";
    
    // 檢查 task_applications 表
    try {
        $appCount = $db->fetch("SELECT COUNT(*) as count FROM task_applications WHERE user_id = ?", [$userId]);
        echo "<p>✅ task_applications 表查詢成功，該用戶的應徵數量: {$appCount['count']}</p>\n";
    } catch (Exception $e) {
        echo "<p>❌ task_applications 表查詢失敗: {$e->getMessage()}</p>\n";
    }

    // 檢查 tasks 表
    try {
        $taskCount = $db->fetch("SELECT COUNT(*) as count FROM tasks");
        echo "<p>✅ tasks 表查詢成功，總數: {$taskCount['count']}</p>\n";
    } catch (Exception $e) {
        echo "<p>❌ tasks 表查詢失敗: {$e->getMessage()}</p>\n";
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
        ta.id                AS application_id,
        ta.status            AS application_status,
        ta.cover_letter,
        ta.created_at,
        ta.updated_at,
        t.id                 AS task_id,
        t.title,
        t.description,
        t.location,
        t.reward_point,
        u.name               AS creator_name,
        u.avatar_url         AS creator_avatar
      FROM task_applications ta
      JOIN tasks t ON t.id = ta.task_id
      LEFT JOIN users u ON u.id = t.creator_id
      WHERE ta.user_id = ?
      ORDER BY ta.created_at DESC
      LIMIT ? OFFSET ?
    ";

    echo "<p>SQL 查詢:</p>\n";
    echo "<pre>$sql</pre>\n";
    echo "<p>參數: [$userId, $limit, $offset]</p>\n";

    $rows = $db->fetchAll($sql, [$userId, $limit, $offset]);
    echo "<p>✅ 查詢成功，結果數量: " . count($rows) . "</p>\n";

    if (count($rows) > 0) {
        echo "<p>📋 第一個結果:</p>\n";
        echo "<pre>" . print_r($rows[0], true) . "</pre>\n";
    }

    echo "<h2>5. 返回結果</h2>\n";
    
    $response = [
      'applications' => $rows,
      'count' => count($rows),
      'pagination' => [ 'limit' => $limit, 'offset' => $offset ],
      'debug_info' => [
        'user_id' => $userId,
        'result_count' => count($rows)
      ]
    ];
    
    echo "<p>響應數據:</p>\n";
    echo "<pre>" . print_r($response, true) . "</pre>\n";
    
    // 如果是在瀏覽器中測試，顯示結果
    if (isset($_GET['debug'])) {
        echo "<h2>6. 調試完成</h2>\n";
        echo "<p>✅ 所有測試通過</p>\n";
    } else {
        // 正常 API 響應
        Response::success($response, 'My applications retrieved (debug)');
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

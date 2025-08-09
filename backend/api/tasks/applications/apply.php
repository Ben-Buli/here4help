<?php
require_once '../../../config/database.php';
require_once '../../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    $conn = $db->getConnection();

    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (!is_array($body)) { $body = $_POST; }

    $taskId = isset($body['task_id']) ? trim($body['task_id']) : (isset($body['taskId']) ? trim($body['taskId']) : '');
    $userId = isset($body['user_id']) ? (int)$body['user_id'] : (isset($body['userId']) ? (int)$body['userId'] : 0);
    $coverLetter = isset($body['cover_letter']) ? trim($body['cover_letter']) : '';

    // 組合 answers_json
    $answers = [
        'q1' => isset($body['q1']) ? (string)$body['q1'] : null,
        'q2' => isset($body['q2']) ? (string)$body['q2'] : null,
        'q3' => isset($body['q3']) ? (string)$body['q3'] : null,
        'introduction' => isset($body['introduction']) ? (string)$body['introduction'] : ''
    ];

    // 若未提供 introduction，嘗試用 cover_letter 和 q1..q3 自動組合
    if (empty($answers['introduction'])) {
        $introParts = [];
        if (!empty($coverLetter)) { $introParts[] = $coverLetter; }
        foreach (['q1','q2','q3'] as $k) {
            if (!empty($answers[$k])) { $introParts[] = $answers[$k]; }
        }
        $answers['introduction'] = implode(' ', $introParts);
    }

    // 清掉為 null 的鍵
    foreach ($answers as $k => $v) {
        if ($v === null) { unset($answers[$k]); }
    }

    if ($taskId === '' || $userId <= 0) {
        Response::validationError([
            'task_id' => 'task_id is required',
            'user_id' => 'user_id is required'
        ]);
    }

    $answersJson = json_encode($answers, JSON_UNESCAPED_UNICODE);

    // UPSERT 至 task_applications
    $sql = "INSERT INTO task_applications (task_id, user_id, status, cover_letter, answers_json, created_at, updated_at)
            VALUES (:task_id, :user_id, 'applied', :cover_letter, :answers_json, NOW(), NOW())
            ON DUPLICATE KEY UPDATE status = VALUES(status), cover_letter = VALUES(cover_letter), answers_json = VALUES(answers_json), updated_at = NOW()";
    $stmt = $conn->prepare($sql);
    $stmt->execute([
        ':task_id' => $taskId,
        ':user_id' => $userId,
        ':cover_letter' => $coverLetter,
        ':answers_json' => $answersJson,
    ]);

    // 回傳應徵紀錄摘要
    $row = $db->fetch("SELECT ta.*, u.name AS user_name FROM task_applications ta JOIN users u ON u.id = ta.user_id WHERE ta.task_id = ? AND ta.user_id = ?", [$taskId, $userId]);

    Response::success($row, 'Application submitted');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>


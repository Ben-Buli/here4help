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
    // 統一 answers_json：以「問題原文」作為鍵，答案為值
    $answers = [];

    // 新格式：接收 { answers: { 'Question text': 'answer', ... } }
    if (isset($body['answers']) && is_array($body['answers'])) {
        foreach ($body['answers'] as $q => $a) {
            $qText = trim((string)$q);
            $aText = trim((string)$a);
            if ($qText !== '' && $aText !== '') {
                $answers[$qText] = $aText;
            }
        }
    }

    // 舊格式相容：若未傳 answers，則檢查 q1..q3，並以通用鍵名代入
    if (empty($answers)) {
        $legacy = [
            'q1' => isset($body['q1']) ? (string)$body['q1'] : null,
            'q2' => isset($body['q2']) ? (string)$body['q2'] : null,
            'q3' => isset($body['q3']) ? (string)$body['q3'] : null,
        ];
        foreach ($legacy as $k => $v) {
            if ($v !== null && trim($v) !== '') {
                $answers[strtoupper($k)] = trim($v);
            }
        }
    }

    // 不再於 answers_json 放 introduction，僅保留 cover_letter 作為自我推薦

    // 最後保險：清掉空值答案
    foreach ($answers as $k => $v) {
        if (!is_string($k) || trim($k) === '' || trim((string)$v) === '') {
            unset($answers[$k]);
        }
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


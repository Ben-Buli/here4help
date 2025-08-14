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
    $answers = [];
    if (isset($body['answers']) && is_array($body['answers'])) {
        foreach ($body['answers'] as $q => $a) {
            $qText = trim((string)$q);
            $aText = trim((string)$a);
            if ($qText !== '' && $aText !== '') {
                $answers[$qText] = $aText;
            }
        }
    }

    // 舊格式相容
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

    // 清理空值答案
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

    // 開始事務
    $conn->beginTransaction();

    try {
        // 1. 獲取任務信息
        $task = $db->fetch("SELECT id, creator_id, title FROM tasks WHERE id = ? LIMIT 1", [$taskId]);
        if (!$task) {
            throw new Exception('Task not found');
        }

        $creatorId = (int)$task['creator_id'];
        if ($creatorId === $userId) {
            throw new Exception('Cannot apply to your own task');
        }

        // 2. UPSERT 應徵記錄
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

        // 獲取應徵記錄 ID
        $application = $db->fetch("SELECT id FROM task_applications WHERE task_id = ? AND user_id = ?", [$taskId, $userId]);
        $applicationId = (int)$application['id'];

        // 3. 檢查或創建聊天室
        $room = $db->fetch(
            'SELECT id FROM chat_rooms WHERE task_id = ? AND creator_id = ? AND participant_id = ? AND type = ? LIMIT 1',
            [$taskId, $creatorId, $userId, 'application']
        );

        $roomId = null;
        if (!$room) {
            // 創建新聊天室
            $db->query(
                'INSERT INTO chat_rooms (task_id, creator_id, participant_id, type, created_at) VALUES (?, ?, ?, ?, NOW())',
                [$taskId, $creatorId, $userId, 'application']
            );
            $newIdRow = $db->fetch('SELECT LAST_INSERT_ID() AS id');
            $roomId = (int)$newIdRow['id'];
        } else {
            $roomId = (int)$room['id'];
        }

        // 4. 發送應徵訊息
        $messageContent = $coverLetter;
        if (!empty($answers)) {
            $messageContent .= "\n\n應徵者回答：\n";
            foreach ($answers as $question => $answer) {
                $messageContent .= "• $question: $answer\n";
            }
        }

        $db->query(
            'INSERT INTO chat_messages (room_id, from_user_id, message, created_at) VALUES (?, ?, ?, NOW())',
            [$roomId, $userId, $messageContent]
        );

        // 5. 更新應徵記錄的 room_id
        $db->query(
            'UPDATE task_applications SET room_id = ? WHERE id = ?',
            [$roomId, $applicationId]
        );

        // 提交事務
        $conn->commit();

        // 6. 獲取完整的應徵和聊天室信息
        $result = $db->fetch(
            "SELECT 
                ta.*,
                u.name AS user_name,
                u.avatar_url AS user_avatar,
                cr.id AS room_id,
                cr.type AS room_type,
                t.title AS task_title,
                t.creator_id,
                creator.name AS creator_name
             FROM task_applications ta 
             JOIN users u ON u.id = ta.user_id 
             JOIN chat_rooms cr ON cr.id = ta.room_id
             JOIN tasks t ON t.id = ta.task_id
             JOIN users creator ON creator.id = t.creator_id
             WHERE ta.id = ?",
            [$applicationId]
        );

        Response::success([
            'application' => $result,
            'room_id' => $roomId,
            'message' => 'Application submitted and chat room created successfully'
        ]);

    } catch (Exception $e) {
        // 回滾事務
        $conn->rollBack();
        throw $e;
    }

} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 
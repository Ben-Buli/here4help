<?php
require_once '../../config/env_loader.php';
require_once '../../config/database.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    // 獲取 Authorization header
    $auth_header = '';
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['HTTP_AUTHORIZATION'];
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
    } elseif (function_exists('getallheaders')) {
        $headers = getallheaders();
        if (isset($headers['Authorization'])) {
            $auth_header = $headers['Authorization'];
        }
    }

    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        throw new Exception('Authorization header required');
    }

    $token = $matches[1];
    $decoded = base64_decode($token);
    $payload = json_decode($decoded, true);

    if (!$payload || !isset($payload['user_id'])) {
        throw new Exception('Invalid token');
    }

    $currentUserId = $payload['user_id'];
    $chatRoomId = $_GET['room_id'] ?? null;

    if (!$chatRoomId) {
        throw new Exception('Room ID is required');
    }

    $db = Database::getInstance();
    $pdo = $db->getConnection();

    // 1. 權限驗證
    $stmt = $pdo->prepare("
        SELECT id, task_id, creator_id, participant_id 
        FROM chat_rooms 
        WHERE id = ?
    ");
    $stmt->execute([$chatRoomId]);
    $chatRoom = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$chatRoom) {
        http_response_code(404);
        echo json_encode(['error' => 'NOT_FOUND', 'message' => '聊天室不存在']);
        exit;
    }

    if ($chatRoom['creator_id'] != $currentUserId && $chatRoom['participant_id'] != $currentUserId) {
        http_response_code(403);
        echo json_encode(['error' => 'FORBIDDEN', 'message' => '您沒有權限訪問此聊天室']);
        exit;
    }

    // 2. 數據聚合
    $stmt = $pdo->prepare("
        SELECT 
            cr.*,
            t.id as task_id,
            t.title,
            t.description,
            t.reward_point,
            t.location,
            t.task_date,
            t.start_datetime,
            t.end_datetime,
            t.language_requirement,
            t.created_at as task_created_at,
            ts.id as status_id,
            ts.code as status_code,
            ts.display_name as status_display,
            ts.progress_ratio,
            ts.sort_order,
            creator.id as creator_id,
            creator.name as creator_name,
            creator.avatar_url as creator_avatar,
            creator.email as creator_email,
            participant.id as participant_id,
            participant.name as participant_name,
            participant.avatar_url as participant_avatar,
            participant.email as participant_email,
            ta.id as application_id,
            ta.cover_letter,
            ta.answers_json,
            ta.status as application_status,
            COALESCE(ta.created_at, NOW()) as application_created_at,
            COALESCE(ta.updated_at, NOW()) as application_updated_at
        FROM chat_rooms cr
        JOIN tasks t ON cr.task_id = t.id
        LEFT JOIN task_statuses ts ON t.status_id = ts.id
        JOIN users creator ON cr.creator_id = creator.id
        JOIN users participant ON cr.participant_id = participant.id
        LEFT JOIN task_applications ta ON (ta.task_id = t.id AND ta.user_id = cr.participant_id)
        WHERE cr.id = ?
    ");
    $stmt->execute([$chatRoomId]);
    $chatData = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$chatData) {
        throw new Exception('無法獲取聊天室數據');
    }

    // 3. 獲取申請問題（application_questions 不存在時以空陣列回傳）
    try {
        $stmt = $pdo->prepare("
            SELECT id, application_question, 'text' as question_type, 0 as sort_order
            FROM application_questions
            WHERE task_id = ?
            ORDER BY sort_order ASC
        ");
        $stmt->execute([$chatData['task_id']]);
        $applicationQuestions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $applicationQuestions = [];
    }

    // 4. 獲取聊天對象的評分
    $chatPartnerId = ($currentUserId == $chatData['creator_id']) ? $chatData['participant_id'] : $chatData['creator_id'];
    
    // 評分數據初始化
    $ratingData = ['average_rating' => 0, 'total_ratings' => 0];
    
    // 檢查 task_ratings 表是否存在以及其結構
    try {
        // 先檢查表是否存在
        $stmt = $pdo->prepare("SHOW TABLES LIKE 'task_ratings'");
        $stmt->execute();
        $tableExists = $stmt->fetch();
        
        if ($tableExists) {
            // 檢查表結構
            $stmt = $pdo->prepare("DESCRIBE task_ratings");
            $stmt->execute();
            $columns = $stmt->fetchAll(PDO::FETCH_COLUMN);
            
            if (in_array('rated_user_id', $columns)) {
                // 方案A：使用 rated_user_id 欄位
                $stmt = $pdo->prepare("
                    SELECT AVG(rating) as average_rating, COUNT(*) as total_ratings
                    FROM task_ratings
                    WHERE rated_user_id = ?
                ");
                $stmt->execute([$chatPartnerId]);
                $tmp = $stmt->fetch(PDO::FETCH_ASSOC);
                if ($tmp && isset($tmp['average_rating'])) {
                    $ratingData = $tmp;
                }
            } elseif (in_array('rating_service', $columns) && in_array('rating_attitude', $columns) && in_array('rating_experience', $columns)) {
                // 方案B：使用三欄位制
                $stmt = $pdo->prepare("
                    SELECT 
                        AVG((tr.rating_service + tr.rating_attitude + tr.rating_experience) / 3) AS average_rating,
                        COUNT(*) AS total_ratings
                    FROM task_ratings tr
                    JOIN tasks t2 ON tr.task_id = t2.id
                    WHERE t2.creator_id = ?
                ");
                $stmt->execute([$chatPartnerId]);
                $tmp = $stmt->fetch(PDO::FETCH_ASSOC);
                if ($tmp && isset($tmp['average_rating'])) {
                    $ratingData = $tmp;
                }
            } else {
                // 方案C：使用其他可能的欄位
                $stmt = $pdo->prepare("
                    SELECT AVG(rating) as average_rating, COUNT(*) as total_ratings
                    FROM task_ratings
                    WHERE user_id = ?
                ");
                $stmt->execute([$chatPartnerId]);
                $tmp = $stmt->fetch(PDO::FETCH_ASSOC);
                if ($tmp && isset($tmp['average_rating'])) {
                    $ratingData = $tmp;
                }
            }
        }
    } catch (Exception $e) {
        // 忽略所有評分查詢錯誤，維持預設值
        error_log("Rating query failed for user $chatPartnerId: " . $e->getMessage());
        $ratingData = ['average_rating' => 0, 'total_ratings' => 0];
    }

    // 5. 獲取聊天訊息（chat_messages 不存在時以空陣列回傳）
    try {
        $stmt = $pdo->prepare("
            SELECT 
                cm.*,
                u.name as sender_name,
                u.avatar_url as sender_avatar
            FROM chat_messages cm
            LEFT JOIN users u ON cm.from_user_id = u.id
            WHERE cm.room_id = ?
            ORDER BY cm.created_at ASC
        ");
        $stmt->execute([$chatRoomId]);
        $chatMessages = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $chatMessages = [];
    }

    // 6. 檢查是否需要生成 View Resume 訊息
    $hasViewResumeMessage = false;
    foreach ($chatMessages as $message) {
        if (strpos($message['content'] ?? '', '申請已提交') !== false) {
            $hasViewResumeMessage = true;
            break;
        }
    }

    // 如果沒有 View Resume 訊息，則生成一個
    if (!$hasViewResumeMessage && $chatData['application_id']) {
        $viewResumeContent = "申請已提交";
        $viewResumeMessage = "申請已提交";
        
        // 構建 metadata
        $metadata = [
            'task_id' => $chatData['task_id'],
            'applicant_id' => $chatData['participant_id'],
            'cover_letter' => $chatData['cover_letter'],
            'answers_json' => $chatData['answers_json'],
            'application_created_at' => $chatData['application_created_at']
        ];

        // 嘗試寫入 View Resume 訊息（若表結構不符則忽略錯誤）
        try {
            $stmt = $pdo->prepare("
                INSERT INTO chat_messages (room_id, from_user_id, content, created_at)
                VALUES (?, ?, ?, ?)
            ");
            $stmt->execute([
                $chatRoomId,
                $chatData['participant_id'],
                $viewResumeMessage,
                $chatData['application_created_at'] ?? date('Y-m-d H:i:s')
            ]);
        } catch (Exception $e) {
            // 忽略插入失敗，繼續回傳其餘資料
        }

        // 重新獲取訊息列表
        try {
            $stmt = $pdo->prepare("
                SELECT 
                    cm.*,
                    u.name as sender_name,
                    u.avatar_url as sender_avatar
                FROM chat_messages cm
                LEFT JOIN users u ON cm.from_user_id = u.id
                WHERE cm.room_id = ?
                ORDER BY cm.created_at ASC
            ");
            $stmt->execute([$chatRoomId]);
            $chatMessages = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            $chatMessages = [];
        }
    }

    // 7. 構建響應數據
    $response = [
        'success' => true,
        'data' => [
            'room' => [
                'id' => $chatData['id'],
                'task_id' => $chatData['task_id'],
                'creator_id' => $chatData['creator_id'],
                'participant_id' => $chatData['participant_id'],
                'created_at' => $chatData['created_at'] ?? null
            ],
            'task' => [
                'id' => $chatData['task_id'],
                'title' => $chatData['title'],
                'description' => $chatData['description'],
                'reward_point' => $chatData['reward_point'],
                'location' => $chatData['location'],
                'task_date' => $chatData['task_date'],
                'start_datetime' => $chatData['start_datetime'] ?? null,
                'end_datetime' => $chatData['end_datetime'] ?? null,
                'language_requirement' => $chatData['language_requirement'],
                'created_at' => $chatData['task_created_at'],
                'status' => [
                    'id' => $chatData['status_id'],
                    'code' => $chatData['status_code'],
                    'display_name' => $chatData['status_display'],
                    'progress_ratio' => $chatData['progress_ratio'],
                    'sort_order' => $chatData['sort_order']
                ]
            ],
            'application_questions' => $applicationQuestions,
            'users' => [
                'creator' => [
                    'id' => $chatData['creator_id'],
                    'name' => $chatData['creator_name'],
                    'avatar_url' => $chatData['creator_avatar'],
                    'email' => $chatData['creator_email']
                ],
                'participant' => [
                    'id' => $chatData['participant_id'],
                    'name' => $chatData['participant_name'],
                    'avatar_url' => $chatData['participant_avatar'],
                    'email' => $chatData['participant_email']
                ]
            ],
            'application' => $chatData['application_id'] ? [
                'id' => $chatData['application_id'],
                'cover_letter' => $chatData['cover_letter'],
                'answers_json' => $chatData['answers_json'],
                'status' => $chatData['application_status'],
                'created_at' => $chatData['application_created_at'],
                'updated_at' => $chatData['application_updated_at']
            ] : null,
            'chat_partner_info' => [
                'id' => $chatPartnerId,
                'name' => ($currentUserId == $chatData['creator_id']) ? $chatData['participant_name'] : $chatData['creator_name'],
                'avatar_url' => ($currentUserId == $chatData['creator_id']) ? $chatData['participant_avatar'] : $chatData['creator_avatar'],
                'average_rating' => round($ratingData['average_rating'] ?? 0, 1),
                'total_ratings' => $ratingData['total_ratings'] ?? 0
            ],
            'user_role' => ($currentUserId == $chatData['creator_id']) ? 'creator' : 'participant',
            'messages' => $chatMessages
        ]
    ];

    echo json_encode($response);

} catch (Exception $e) {
    error_log("Chat detail error: " . $e->getMessage());
    
    if (strpos($e->getMessage(), 'Authorization') !== false) {
        http_response_code(401);
        echo json_encode(['error' => 'UNAUTHORIZED', 'message' => $e->getMessage()]);
    } elseif (strpos($e->getMessage(), 'Room ID') !== false) {
        http_response_code(400);
        echo json_encode(['error' => 'BAD_REQUEST', 'message' => $e->getMessage()]);
    } else {
        http_response_code(500);
        // 在開發環境回傳更詳盡錯誤，方便除錯
        $isDev = method_exists('EnvLoader', 'isDevelopment') ? EnvLoader::isDevelopment() : true;
        echo json_encode([
            'error' => 'INTERNAL_ERROR',
            'message' => $isDev ? $e->getMessage() : '系統錯誤'
        ]);
    }
}
?> 
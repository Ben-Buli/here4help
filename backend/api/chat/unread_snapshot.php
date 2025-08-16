<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../../config/database.php';
require_once '../../utils/Response.php';

function base64url_decode_robust($data) {
    $data = strtr($data, '-_', '+/');
    $pad = strlen($data) % 4;
    if ($pad > 0) { $data .= str_repeat('=', 4 - $pad); }
    return base64_decode($data);
}

function validateToken($token) {
    try {
        // 1) 嘗試直接 base64 decode（允許含換行）
        $decoded = base64_decode($token);
        $payload = $decoded !== false ? json_decode($decoded, true) : null;

        // 2) 若失敗，嘗試 base64url（JWT 的 payload 也會用到）
        if (!$payload) {
            $decodedUrl = base64url_decode_robust($token);
            if ($decodedUrl !== false) {
                $payload = json_decode($decodedUrl, true);
            }
        }

        // 3) 若仍失敗，嘗試當作 JWT：取第二段 payload
        if (!$payload && substr_count($token, '.') === 2) {
            $parts = explode('.', $token);
            $pl = base64url_decode_robust($parts[1]);
            if ($pl !== false) {
                $payload = json_decode($pl, true);
            }
        }

        if (!$payload) return null;
        if (!isset($payload['user_id']) || !isset($payload['exp'])) return null;
        if ((int)$payload['exp'] < time()) return null;
        return $payload;
    } catch (Exception $e) {
        return null;
    }
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::error('Method not allowed', 405);
    }

    // 調試 header 讀取（改為逐步補齊，而非 else-if 鏈）
    error_log("Debug: 開始讀取 Authorization header");
    error_log("Debug: HTTP_AUTHORIZATION = " . ($_SERVER['HTTP_AUTHORIZATION'] ?? 'not set'));
    error_log("Debug: REDIRECT_HTTP_AUTHORIZATION = " . ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 'not set'));

    $auth_header = '';

    // 方法 1: 直接從 $_SERVER 讀取
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['HTTP_AUTHORIZATION'];
        error_log("Debug: 從 HTTP_AUTHORIZATION 讀取: $auth_header");
    }

    // 方法 2: 從 REDIRECT_HTTP_AUTHORIZATION 讀取
    if (empty($auth_header) && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        error_log("Debug: 從 REDIRECT_HTTP_AUTHORIZATION 讀取: $auth_header");
    }

    // 方法 3: 使用 getallheaders() 函數
    if (empty($auth_header) && function_exists('getallheaders')) {
        $headers = getallheaders();
        error_log("Debug: getallheaders() 結果: " . print_r($headers, true));
        if (isset($headers['Authorization'])) {
            $auth_header = $headers['Authorization'];
            error_log("Debug: 從 getallheaders() 讀取: $auth_header");
        } elseif (isset($headers['authorization'])) {
            $auth_header = $headers['authorization'];
            error_log("Debug: 從 getallheaders().authorization 讀取: $auth_header");
        }
    }

    // 方法 4: 從 $_GET 讀取（作為最終備用方案）
    if (empty($auth_header) && isset($_GET['token'])) {
        $auth_header = 'Bearer ' . $_GET['token'];
        error_log("Debug: 從 GET 參數讀取 token: $auth_header");
    }

    // 方法 5: 從 POST/JSON 讀取（最後備援）
    if (empty($auth_header)) {
        $raw = file_get_contents('php://input');
        if (!empty($raw)) {
            $json = json_decode($raw, true);
            if ($json && isset($json['token'])) {
                $auth_header = 'Bearer ' . $json['token'];
                error_log("Debug: 從 request body 讀取 token: $auth_header");
            }
        }
    }

    error_log("Debug: Final Authorization header = $auth_header");

    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        error_log("Debug: Authorization header is empty or invalid format");
        throw new Exception('Authorization header required');
    }

    $token = $matches[1];
    $payload = validateToken(trim($token));
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    $user_id = (int)$payload['user_id'];

    $db = Database::getInstance();

    // SQL: 未讀 = 該房總訊息數 - 我最後讀到的 message_id 序號（只計算他人訊息）
    $unreadByRoom = [];
    $total = 0;
    
    // Debug: force clear and log
    error_log("Debug: Starting unread calculation for user_id=$user_id");

    // 修正版：使用子查詢獲取每個房間我的已讀進度，避免重複
    $sql = "
      SELECT m.room_id,
             SUM(CASE WHEN m.from_user_id <> ? AND m.id > COALESCE(my_reads.last_read_id, 0)
                      THEN 1 ELSE 0 END) AS unread_cnt
      FROM chat_messages m
      JOIN chat_rooms cr ON cr.id = m.room_id
      LEFT JOIN (
        SELECT room_id, last_read_message_id AS last_read_id
        FROM chat_reads 
        WHERE user_id = ?
      ) my_reads ON my_reads.room_id = m.room_id
      WHERE (cr.creator_id = ? OR cr.participant_id = ?)
      GROUP BY m.room_id
    ";
    $rows = $db->fetchAll($sql, [$user_id, $user_id, $user_id, $user_id]);
    $debugInfo = [];
    foreach ($rows as $row) {
        $rid = (string)$row['room_id'];
        $cnt = (int)$row['unread_cnt'];
        
        // Debug info
        $debugInfo[$rid] = [
            'unread_cnt' => $cnt
        ];
        
        if ($cnt > 0) {
            $unreadByRoom[$rid] = $cnt;
            $total += $cnt;
            error_log("Debug: Room $rid has $cnt unread messages");
        } else {
            error_log("Debug: Room $rid has 0 unread messages, skipping");
        }
    }

    $response = [
        'total' => $total,
        'by_room' => $unreadByRoom,
    ];
    
    // Add debug info if requested
    if (isset($_GET['debug']) && $_GET['debug']) {
        $response['debug'] = $debugInfo;
    }
    
    Response::success($response, 'Unread snapshot');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>



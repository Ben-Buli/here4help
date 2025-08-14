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

function validateToken($token) {
    try {
        $decoded = base64_decode($token);
        if ($decoded === false) {
            return null;
        }
        $payload = json_decode($decoded, true);
        if (!$payload) return null;
        if (!isset($payload['user_id']) || !isset($payload['exp'])) return null;
        if ($payload['exp'] < time()) return null;
        return $payload;
    } catch (Exception $e) {
        return null;
    }
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        Response::error('Method not allowed', 405);
    }

    // 調試 header 讀取
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
    elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        error_log("Debug: 從 REDIRECT_HTTP_AUTHORIZATION 讀取: $auth_header");
    }
    // 方法 3: 使用 getallheaders() 函數
    elseif (function_exists('getallheaders')) {
        $headers = getallheaders();
        error_log("Debug: getallheaders() 結果: " . print_r($headers, true));
        if (isset($headers['Authorization'])) {
            $auth_header = $headers['Authorization'];
            error_log("Debug: 從 getallheaders() 讀取: $auth_header");
        }
    }
    // 方法 4: 從 $_GET 讀取（作為備用方案）
    elseif (isset($_GET['token'])) {
        $auth_header = 'Bearer ' . $_GET['token'];
        error_log("Debug: 從 GET 參數讀取 token: $auth_header");
    }
    
    error_log("Debug: Final Authorization header = $auth_header");

    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        error_log("Debug: Authorization header is empty or invalid format");
        throw new Exception('Authorization header required');
    }

    $token = $matches[1];
    $payload = validateToken($token);
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    $user_id = (int)$payload['user_id'];

    $db = Database::getInstance();

    // SQL: 未讀 = 該房總訊息數 - 我最後讀到的 message_id 序號（只計算他人訊息）
    $unreadByRoom = [];
    $total = 0;

    $sql = "
      SELECT m.room_id,
             SUM(CASE WHEN m.from_user_id <> ? AND m.id > COALESCE(r.last_read_message_id, 0)
                      THEN 1 ELSE 0 END) AS unread_cnt
      FROM chat_messages m
      LEFT JOIN chat_reads r ON r.room_id = m.room_id AND r.user_id = ?
      GROUP BY m.room_id
    ";
    $rows = $db->fetchAll($sql, [$user_id, $user_id]);
    foreach ($rows as $row) {
        $rid = (string)$row['room_id'];
        $cnt = (int)$row['unread_cnt'];
        if ($cnt > 0) {
            $unreadByRoom[$rid] = $cnt;
            $total += $cnt;
        }
    }

    Response::success([
        'total' => $total,
        'by_room' => $unreadByRoom,
    ], 'Unread snapshot');
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?>



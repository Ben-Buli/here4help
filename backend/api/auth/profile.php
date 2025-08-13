<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 引入資料庫配置
require_once '../../config/database.php';

// 簡單的 token 驗證函數（使用 base64 編碼的 JSON）
function validateToken($token) {
    try {
        error_log("Debug: Validating token = " . $token);
        
        // 嘗試 base64 解碼
        $decoded = base64_decode($token);
        if ($decoded === false) {
            error_log("Debug: Failed to base64 decode token");
            return null;
        }
        
        error_log("Debug: Decoded token = " . $decoded);
        
        $payload = json_decode($decoded, true);
        if (!$payload) {
            error_log("Debug: Failed to JSON decode payload");
            return null;
        }
        
        error_log("Debug: Decoded payload = " . print_r($payload, true));
        
        // 檢查必要欄位
        if (!isset($payload['user_id']) || !isset($payload['exp'])) {
            error_log("Debug: Missing required fields in payload");
            return null;
        }
        
        // 檢查是否過期
        if ($payload['exp'] < time()) {
            error_log("Debug: Token expired");
            return null;
        }
        
        error_log("Debug: Token validation successful - user_id = " . $payload['user_id']);
        return $payload;
    } catch (Exception $e) {
        error_log("Debug: Token validation exception = " . $e->getMessage());
        return null;
    }
}

try {
    $db = Database::getInstance();
    
    // 獲取 Authorization header - 使用多種方法
    $auth_header = '';
    
    // 方法1: 檢查 $_SERVER['HTTP_AUTHORIZATION']
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['HTTP_AUTHORIZATION'];
        error_log("Debug: Found Authorization header in HTTP_AUTHORIZATION: " . $auth_header);
    }
    // 方法2: 檢查 $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
    elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth_header = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        error_log("Debug: Found Authorization header in REDIRECT_HTTP_AUTHORIZATION: " . $auth_header);
    }
    // 方法3: 使用 getallheaders()
    elseif (function_exists('getallheaders')) {
        $headers = getallheaders();
        // 檢查不同的大小寫組合
        foreach (['Authorization', 'authorization', 'AUTHORIZATION'] as $auth_key) {
            if (isset($headers[$auth_key])) {
                $auth_header = $headers[$auth_key];
                error_log("Debug: Found Authorization header in getallheaders() with key '$auth_key': " . $auth_header);
                break;
            }
        }
        if (empty($auth_header)) {
            error_log("Debug: Authorization header not found in getallheaders()");
            error_log("Debug: Available headers: " . print_r($headers, true));
        }
    }
    // 方法4: 使用 apache_request_headers()
    elseif (function_exists('apache_request_headers')) {
        $apache_headers = apache_request_headers();
        foreach (['Authorization', 'authorization', 'AUTHORIZATION'] as $auth_key) {
            if (isset($apache_headers[$auth_key])) {
                $auth_header = $apache_headers[$auth_key];
                error_log("Debug: Found Authorization header in apache_request_headers() with key '$auth_key': " . $auth_header);
                break;
            }
        }
        if (empty($auth_header)) {
            error_log("Debug: Authorization header not found in apache_request_headers()");
            error_log("Debug: Available apache headers: " . print_r($apache_headers, true));
        }
    }
    
    // 方法5: 檢查 $_SERVER 中的所有可能的 header
    if (empty($auth_header)) {
        error_log("Debug: Checking all \$_SERVER variables for Authorization header");
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') === 0) {
                error_log("Debug: $key = " . (is_string($value) ? $value : print_r($value, true)));
                if (strtoupper($key) === 'HTTP_AUTHORIZATION') {
                    $auth_header = $value;
                    error_log("Debug: Found Authorization header in \$_SERVER['$key']: " . $auth_header);
                    break;
                }
            }
        }
    }
    
    // 調試信息
    error_log("Debug: Final Authorization header = " . $auth_header);
    error_log("Debug: HTTP_AUTHORIZATION = " . ($_SERVER['HTTP_AUTHORIZATION'] ?? 'not set'));
    error_log("Debug: REDIRECT_HTTP_AUTHORIZATION = " . ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 'not set'));
    
    // 如果沒有找到授權標頭，嘗試從其他地方獲取 token
    $token = null;
    
    if (!empty($auth_header) && preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        $token = $matches[1];
        error_log("Debug: Token extracted from Authorization header");
    }
    // 備用方案：從 GET 參數獲取 token (僅用於測試)
    elseif (isset($_GET['token'])) {
        $token = $_GET['token'];
        error_log("Debug: Token extracted from GET parameter");
    }
    // 備用方案：從 POST 數據獲取 token
    elseif (isset($_POST['token'])) {
        $token = $_POST['token'];
        error_log("Debug: Token extracted from POST data");
    }
    // 備用方案：從 JSON 輸入獲取 token
    else {
        $input = json_decode(file_get_contents('php://input'), true);
        if (isset($input['token'])) {
            $token = $input['token'];
            error_log("Debug: Token extracted from JSON input");
        }
    }
    
    if (empty($token)) {
        error_log("Debug: No token found in any location");
        throw new Exception('Authorization header required');
    }
    error_log("Debug: Extracted token: " . substr($token, 0, 20) . "...");
    $payload = validateToken($token);
    
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $user_id = $payload['user_id'];
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET' || $_SERVER['REQUEST_METHOD'] === 'POST') {
        // 獲取用戶資料
        $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$user_id]);
        $user = $stmt->fetch();
        
        if (!$user) {
            throw new Exception('User not found');
        }
        
        // 調試信息
        error_log("Debug: User found - ID: {$user['id']}, Name: {$user['name']}, Avatar: {$user['avatar_url']}");
        
        $userData = [
            'id' => $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'phone' => $user['phone'],
            'nickname' => $user['nickname'],
            'google_id' => $user['google_id'],
            'avatar_url' => $user['avatar_url'] ?? '', // 確保avatar_url不為null
            'points' => (int)$user['points'],
            'status' => $user['status'],
            'provider' => $user['provider'],
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
            'referral_code' => $user['referral_code'],
            'primary_language' => $user['primary_language'] ?? 'English',
            'permission' => (int)($user['permission'] ?? 0)
        ];
        
        error_log("Debug: Returning user data - avatar_url: {$userData['avatar_url']}");
        
        echo json_encode([
            'success' => true,
            'data' => $userData
        ]);
        
    } elseif ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        // 更新用戶資料
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            throw new Exception('Invalid JSON input');
        }
        
        $updates = [];
        $params = [];
        
        // 允許更新的欄位
        $allowed_fields = ['name', 'phone', 'avatar_url'];
        
        foreach ($allowed_fields as $field) {
            if (isset($input[$field])) {
                $updates[] = "$field = ?";
                $params[] = $input[$field];
            }
        }
        
        if (empty($updates)) {
            throw new Exception('No valid fields to update');
        }
        
        $params[] = $user_id;
        $sql = "UPDATE users SET " . implode(', ', $updates) . " WHERE id = ?";
        
        $db->query($sql, $params);
        
        // 重新查詢更新後的資料
        $stmt = $db->query("SELECT * FROM users WHERE id = ?", [$user_id]);
        $user = $stmt->fetch();
        
        $userData = [
            'id' => $user['id'],
            'name' => $user['name'],
            'email' => $user['email'],
            'phone' => $user['phone'],
            'nickname' => $user['nickname'],
            'google_id' => $user['google_id'],
            'avatar_url' => $user['avatar_url'],
            'points' => (int)$user['points'],
            'status' => $user['status'],
            'provider' => $user['provider'],
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
            'referral_code' => $user['referral_code'],
            'primary_language' => $user['primary_language'] ?? 'English',
            'permission' => (int)($user['permission'] ?? 0)
        ];
        
        echo json_encode([
            'success' => true,
            'message' => 'Profile updated successfully',
            'data' => $userData
        ]);
        
    } else {
        http_response_code(405);
        echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    }
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
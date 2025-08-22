<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 引入資料庫配置
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/JWTManager.php';


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
        if (isset($headers['Authorization'])) {
            $auth_header = $headers['Authorization'];
            error_log("Debug: Found Authorization header in getallheaders(): " . $auth_header);
        } else {
            error_log("Debug: Authorization header not found in getallheaders()");
            error_log("Debug: Available headers: " . print_r($headers, true));
        }
    }
    // 方法4: 使用 apache_request_headers()
    elseif (function_exists('apache_request_headers')) {
        $apache_headers = apache_request_headers();
        if (isset($apache_headers['Authorization'])) {
            $auth_header = $apache_headers['Authorization'];
            error_log("Debug: Found Authorization header in apache_request_headers(): " . $auth_header);
        } else {
            error_log("Debug: Authorization header not found in apache_request_headers()");
        }
    }
    // 方法5: 檢查 $_SERVER 中的所有可能的 header
    else {
        error_log("Debug: Checking all $_SERVER variables for Authorization header");
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') === 0) {
                error_log("Debug: $key = $value");
            }
        }
    }
    
    // 調試信息
    error_log("Debug: Final Authorization header = " . $auth_header);
    error_log("Debug: HTTP_AUTHORIZATION = " . ($_SERVER['HTTP_AUTHORIZATION'] ?? 'not set'));
    error_log("Debug: REDIRECT_HTTP_AUTHORIZATION = " . ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 'not set'));
    
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        error_log("Debug: Authorization header is empty or invalid format");
        throw new Exception('Authorization header required');
    }
    
    $token = $matches[1];
    error_log("Debug: Extracted token: " . substr($token, 0, 20) . "...");
    $payload = JWTManager::validateToken($token);
    
    if (!$payload) {
        throw new Exception('Invalid or expired token');
    }
    
    $user_id = $payload['user_id'];
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
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
            'google_id' => null, // 已棄用，設為 null
            'avatar_url' => $user['avatar_url'] ?? '', // 確保avatar_url不為null
            'points' => (int)$user['points'],
            'status' => $user['status'],
            'provider' => null, // 傳統登入，provider 為 null
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
            'google_id' => null, // 已棄用，設為 null
            'avatar_url' => $user['avatar_url'],
            'points' => (int)$user['points'],
            'status' => $user['status'],
            'provider' => null, // 傳統登入，provider 為 null
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
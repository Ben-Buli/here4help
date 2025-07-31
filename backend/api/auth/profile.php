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
require_once '../../config/database.php';

// 簡單的 token 驗證函數（實際應該使用 JWT 庫）
function validateToken($token) {
    try {
        $payload = json_decode(base64_decode($token), true);
        if (!$payload || !isset($payload['user_id']) || $payload['exp'] < time()) {
            return null;
        }
        return $payload;
    } catch (Exception $e) {
        return null;
    }
}

try {
    $db = Database::getInstance();
    
    // 獲取 Authorization header
    $headers = getallheaders();
    $auth_header = $headers['Authorization'] ?? '';
    
    if (empty($auth_header) || !preg_match('/Bearer\s+(.*)$/i', $auth_header, $matches)) {
        throw new Exception('Authorization header required');
    }
    
    $token = $matches[1];
    $payload = validateToken($token);
    
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
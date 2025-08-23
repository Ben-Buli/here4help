<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/UserActiveLogger.php';
require_once __DIR__ . '/../../utils/ErrorCodes.php';
require_once __DIR__ . '/../../auth_helper.php';

// CORS headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

try {
    // 驗證 JWT token - 支持多源讀取（Authorization header 和查詢參數）
    $jwtManager = new JWTManager();
    $authHeader = getAuthorizationHeader();
    $token = null;
    
    if ($authHeader && strpos($authHeader, 'Bearer ') === 0) {
        $token = trim(substr($authHeader, 7));
    }
    
    // 如果 header 中沒有 token，嘗試從查詢參數讀取（MAMP 兼容性）
    if (!$token) {
        $token = $_GET['token'] ?? $_POST['token'] ?? '';
    }
    
    if (!$token) {
        Response::unauthorized('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        Response::unauthorized('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 建立資料庫連線
    $dbHost = EnvLoader::get('DB_HOST');
    if ($dbHost === 'localhost') { $dbHost = '127.0.0.1'; }
    $dbPort = EnvLoader::get('DB_PORT') ?: '3306';
    $dsn = "mysql:host={$dbHost};port={$dbPort};dbname=" . EnvLoader::get('DB_NAME') . ";charset=utf8mb4";

    $pdo = new PDO(
        $dsn,
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // 獲取用戶個人資料
        $stmt = $pdo->prepare("
            SELECT id, name, email, phone, nickname, avatar_url, points, status, 
                   created_at, updated_at, referral_code, primary_language, permission,
                   date_of_birth, gender, country, address, is_permanent_address,
                   language_requirement, school, about_me
            FROM users 
            WHERE id = ?
        ");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();
        
        if (!$user) {
            Response::notFound('User not found');
        }
        
        // 構建用戶資料回應
        $userData = [
            'id' => (int)$user['id'],
            'name' => $user['name'] ?? '',
            'email' => $user['email'] ?? '',
            'phone' => $user['phone'] ?? '',
            'nickname' => $user['nickname'] ?? '',
            'avatar_url' => $user['avatar_url'] ?? '',
            'points' => (int)($user['points'] ?? 0),
            'status' => $user['status'] ?? 'active',
            'permission' => (int)($user['permission'] ?? 0),
            'created_at' => $user['created_at'],
            'updated_at' => $user['updated_at'],
            'referral_code' => $user['referral_code'] ?? '',
            'primary_language' => $user['primary_language'] ?? 'English',
            'date_of_birth' => $user['date_of_birth'] ?? '',
            'gender' => $user['gender'] ?? '',
            'country' => $user['country'] ?? '',
            'address' => $user['address'] ?? '',
            'is_permanent_address' => (bool)($user['is_permanent_address'] ?? false),
            'language_requirement' => $user['language_requirement'] ?? '',
            'school' => $user['school'] ?? '',
            'about_me' => $user['about_me'] ?? ''
        ];
        
        Response::success($userData, 'Profile retrieved successfully');
        
    } elseif ($_SERVER['REQUEST_METHOD'] === 'PUT') {
        // 更新用戶個人資料
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!$input) {
            Response::badRequest('Invalid JSON input');
        }
        
        // 可更新的欄位及其驗證
        $allowedFields = [
            'name' => ['required' => false, 'max_length' => 100],
            'nickname' => ['required' => false, 'max_length' => 50],
            'phone' => ['required' => false, 'pattern' => '/^[\+]?[0-9\-\(\)\s]+$/'],
            'date_of_birth' => ['required' => false, 'pattern' => '/^\d{4}-\d{2}-\d{2}$/'],
            'gender' => ['required' => false, 'enum' => ['Male', 'Female', 'Non-binary', 'Genderfluid', 'Agender', 'Bigender', 'Genderqueer', 'Two-spirit', 'Other', 'Prefer not to disclose']],
            'country' => ['required' => false, 'max_length' => 100],
            'address' => ['required' => false, 'max_length' => 255],
            'is_permanent_address' => ['required' => false, 'type' => 'boolean'],
            'primary_language' => ['required' => false, 'max_length' => 50],
            'about_me' => ['required' => false, 'max_length' => 1000],
            'school' => ['required' => false, 'max_length' => 20]
        ];
        
        $updates = [];
        $params = [];
        $errors = [];
        
        // 驗證和準備更新欄位
        foreach ($allowedFields as $field => $rules) {
            if (!isset($input[$field])) continue;
            
            $value = $input[$field];
            
            // 類型檢查
            if (isset($rules['type']) && $rules['type'] === 'boolean') {
                $value = (bool)$value;
            }

            // ✅ 在 push 前轉換布林值成 int (0/1)
            if ($field === 'is_permanent_address') {
                 $value = $value ? 1 : 0;
                }
            
            // 長度檢查
            if (isset($rules['max_length']) && is_string($value) && strlen($value) > $rules['max_length']) {
                $errors[] = "Field '{$field}' exceeds maximum length of {$rules['max_length']}";
                continue;
            }
            
            // 格式檢查
            if (isset($rules['pattern']) && is_string($value) && !preg_match($rules['pattern'], $value)) {
                $errors[] = "Field '{$field}' has invalid format";
                continue;
            }
            
            // 枚舉檢查
            if (isset($rules['enum']) && !in_array($value, $rules['enum'])) {
                $errors[] = "Field '{$field}' has invalid value";
                continue;
            }
            
            $updates[] = "{$field} = ?";
            $params[] = $value;
        }
        
        if (!empty($errors)) {
            Response::validationError('Validation failed: ' . implode(', ', $errors));
        }
        
        if (empty($updates)) {
            Response::badRequest('No valid fields to update');
        }
        
        // 執行更新
        $params[] = $userId;
        $sql = "UPDATE users SET " . implode(', ', $updates) . ", updated_at = NOW() WHERE id = ?";
        
        $pdo->beginTransaction();
        
        try {
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            
            // 記錄操作日誌
            $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
            $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
            $rid = $_SERVER['HTTP_X_REQUEST_ID'] ?? null;
            $tid = $_SERVER['HTTP_X_TRACE_ID'] ?? null;
            
          try {
            $logger = new UserActiveLogger();
            $logger->logAction(
                $userId,
                'user',
                $userId,
                'profile_update',
                null,
                null,
                null,
                'User updated profile',
                $ip,
                $ua,
                $rid,
                $tid,
                [
                    'updated_fields' => array_keys($input),
                    'updated_at' => date('Y-m-d H:i:s'),
                ]
            );
          } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
          }


            $pdo->commit();
            
            // 重新查詢更新後的資料
            $stmt = $pdo->prepare("
                SELECT id, name, email, phone, nickname, avatar_url, points, status, 
                       created_at, updated_at, referral_code, primary_language, permission,
                       date_of_birth, gender, country, address, is_permanent_address,
                       language_requirement, school, about_me
                FROM users 
                WHERE id = ?
            ");
            $stmt->execute([$userId]);
            $user = $stmt->fetch();
            
            $userData = [
                'id' => (int)$user['id'],
                'name' => $user['name'] ?? '',
                'email' => $user['email'] ?? '',
                'phone' => $user['phone'] ?? '',
                'nickname' => $user['nickname'] ?? '',
                'avatar_url' => $user['avatar_url'] ?? '',
                'points' => (int)($user['points'] ?? 0),
                'status' => $user['status'] ?? 'active',
                'permission' => (int)($user['permission'] ?? 0),
                'created_at' => $user['created_at'],
                'updated_at' => $user['updated_at'],
                'referral_code' => $user['referral_code'] ?? '',
                'primary_language' => $user['primary_language'] ?? 'English',
                'date_of_birth' => $user['date_of_birth'] ?? '',
                'gender' => $user['gender'] ?? '',
                'country' => $user['country'] ?? '',
                'address' => $user['address'] ?? '',
                'is_permanent_address' => (bool)($user['is_permanent_address'] ?? false),
                'language_requirement' => $user['language_requirement'] ?? '',
                'school' => $user['school'] ?? '',
                'about_me' => $user['about_me'] ?? ''
            ];
            
            Response::success($userData, 'Profile updated successfully');
            
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
        
    } else {
        Response::error(ErrorCodes::METHOD_NOT_ALLOWED);
    }
    
} catch (Exception $e) {
    Response::badRequest($e->getMessage());
}
?>

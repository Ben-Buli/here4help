<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 引入必要的檔案
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 載入環境配置
require_once __DIR__ . '/../../config/env_loader.php';

// 啟動 session 管理
session_start();

try {
    // Apple 回調可能是 POST 或 GET
    if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'])) {
        throw new Exception('Invalid request method');
    }
    
    // 獲取回調參數（Apple 通常使用 POST）
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $code = $_POST['code'] ?? '';
        $state = $_POST['state'] ?? '';
        $error = $_POST['error'] ?? '';
        $idToken = $_POST['id_token'] ?? '';
        $user = $_POST['user'] ?? '';
    } else {
        $code = $_GET['code'] ?? '';
        $state = $_GET['state'] ?? '';
        $error = $_GET['error'] ?? '';
        $idToken = $_GET['id_token'] ?? '';
        $user = $_GET['user'] ?? '';
    }
    
    error_log("Apple OAuth Callback - 開始處理回調");
    error_log("Code: $code");
    error_log("State: $state");
    
    // 檢查是否有錯誤
    if (!empty($error)) {
        throw new Exception("OAuth error: $error");
    }
    
    // 驗證必要參數
    if (empty($code)) {
        throw new Exception('Authorization code is required');
    }
    
    if (empty($state)) {
        throw new Exception('State parameter is required');
    }
    
    // 驗證 state 參數（防止 CSRF 攻擊）
    if (!preg_match('/^web_apple_\d+$/', $state)) {
        throw new Exception('Invalid state parameter');
    }
    
    // 從環境配置獲取 Apple OAuth 設定
    $serviceId = EnvLoader::get('APPLE_SERVICE_ID', '');
    $teamId = EnvLoader::get('APPLE_TEAM_ID', '');
    $keyId = EnvLoader::get('APPLE_KEY_ID', '');
    $redirectUri = EnvLoader::get('APPLE_REDIRECT_URI', 'http://localhost:8888/here4help/backend/api/auth/apple-callback.php');
    
    if (empty($serviceId) || empty($teamId) || empty($keyId)) {
        throw new Exception('Apple OAuth configuration is incomplete');
    }
    
    error_log("Apple OAuth Callback - 配置驗證通過");
    
    // Apple 登入通常會直接提供 id_token，我們可以解析它來獲取用戶資訊
    if (!empty($idToken)) {
        // 解析 JWT token（簡化版本，生產環境需要驗證簽名）
        $tokenParts = explode('.', $idToken);
        if (count($tokenParts) !== 3) {
            throw new Exception('Invalid ID token format');
        }
        
        $payload = json_decode(base64_decode($tokenParts[1]), true);
        if (!$payload) {
            throw new Exception('Invalid ID token payload');
        }
        
        $appleId = $payload['sub'] ?? '';
        $email = $payload['email'] ?? '';
        
        // 如果有 user 參數，解析用戶姓名
        $name = 'Apple User';
        if (!empty($user)) {
            $userInfo = json_decode($user, true);
            if ($userInfo && isset($userInfo['name'])) {
                $firstName = $userInfo['name']['firstName'] ?? '';
                $lastName = $userInfo['name']['lastName'] ?? '';
                $name = trim("$firstName $lastName") ?: 'Apple User';
            }
        }
        
        error_log("Apple OAuth Callback - 用戶資料解析成功");
        
        // 建立資料庫連線
        $db = Database::getInstance();
        
        // 檢查是否已存在對應的 user_identity
        $stmt = $db->query(
            "SELECT ui.*, u.* FROM user_identities ui 
             INNER JOIN users u ON ui.user_id = u.id 
             WHERE ui.provider = 'apple' AND ui.provider_user_id = ?",
            [$appleId]
        );
        
        $existingIdentity = $stmt->fetch();
        $isNewUser = false;
        
        if ($existingIdentity) {
            // 現有用戶，更新最後登入時間
            $db->query(
                "UPDATE users SET updated_at = NOW() WHERE id = ?",
                [$existingIdentity['user_id']]
            );
            
            $user = $existingIdentity;
            error_log("Apple OAuth Callback - 現有用戶登入成功");
        } else {
            // 新用戶，需要導向註冊頁面
            $isNewUser = true;
            
            // 建立臨時用戶記錄
            $oauthToken = bin2hex(random_bytes(32));
            $expiredAt = date('Y-m-d H:i:s', time() + 3600); // 1小時後過期
            
            $rawData = [
                'apple_id' => $appleId,
                'email' => $email,
                'name' => $name,
                'id_token' => $idToken,
                'payload' => $payload
            ];
            
            $db->query(
                "INSERT INTO oauth_temp_users (
                    token, provider, provider_user_id, email, name, avatar_url, 
                    raw_data, expired_at, created_at
                ) VALUES (?, 'apple', ?, ?, ?, ?, ?, ?, NOW())",
                [
                    $oauthToken, $appleId, $email, $name, '',
                    json_encode($rawData), $expiredAt
                ]
            );
            
            error_log("Apple OAuth Callback - 新用戶，建立臨時記錄");
        }
        
        // 準備重定向 URL
        $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
        
        if ($isNewUser) {
            // 新用戶：重定向到註冊頁面
            $redirectUrl = $frontendUrl . '/auth/callback?success=true&provider=apple&oauth_token=' . urlencode($oauthToken);
        } else {
            // 現有用戶：生成 JWT 並重定向到主頁
            $payload = [
                'user_id' => $user['id'],
                'email' => $user['email'] ?? '',
                'name' => $user['name'],
                'iat' => time(),
                'exp' => time() + (60 * 60 * 24 * 7) // 7 天過期
            ];
            
            $token = JWTManager::generateToken($payload);
            
            $userData = [
                'id' => $user['id'],
                'name' => $user['name'] ?? '',
                'email' => $user['email'] ?? '',
                'provider' => 'apple',
            ];
            
            $redirectUrl = $frontendUrl . '/auth/callback?success=true&provider=apple&token=' . urlencode($token) . '&user_data=' . urlencode(json_encode($userData));
        }
        
        error_log("Apple OAuth Callback - 重定向到: $redirectUrl");
        
        // 重定向到前端
        header('Location: ' . $redirectUrl);
        exit;
        
    } else {
        throw new Exception('ID token is required for Apple login');
    }
    
} catch (Exception $e) {
    error_log("Apple OAuth Callback Error: " . $e->getMessage());
    
    // 重定向到錯誤頁面
    $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
    $errorUrl = $frontendUrl . '/auth/callback?success=false&provider=apple&error=' . urlencode($e->getMessage());
    
    header('Location: ' . $errorUrl);
    exit;
}
?>

<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

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

try {
    // Apple 回調可能是 POST 或 GET
    if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'])) {
        throw new Exception('Invalid request method');
    }
    
    // 檢查是否為 popup 模式
    $isPopup = false;
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $isPopup = isset($_POST['popup']) && $_POST['popup'] === 'true';
    } else {
        $isPopup = isset($_GET['popup']) && $_GET['popup'] === 'true';
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
                ) VALUES (?, 'apple', ?, ?, ?, ?, ?, ?, NOW())
                ON DUPLICATE KEY UPDATE
                    token = VALUES(token),
                    email = VALUES(email),
                    name = VALUES(name),
                    avatar_url = VALUES(avatar_url),
                    raw_data = VALUES(raw_data),
                    expired_at = VALUES(expired_at),
                    updated_at = NOW()",
                [
                    $oauthToken, $appleId, $email, $name, '',
                    json_encode($rawData), $expiredAt
                ]
            );
            
            error_log("Apple OAuth Callback - 新用戶，建立臨時記錄");
        }
        
        // 準備結果數據和重定向 URL
        $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
        
        $token = null;
        $tokenPair = null;
        $userData = null;
        if ($isNewUser) {
            // 新用戶：準備註冊數據
            $result = [
                'success' => true,
                'provider' => 'apple',
                'is_new_user' => true,
                'oauth_token' => $oauthToken
            ];
            $redirectUrl = $frontendUrl . '/#/signup?token=' . urlencode($oauthToken) . '&provider=apple&is_new_user=true';
        } else {
            // 現有用戶：生成 Access/Refresh Tokens
            $payload = [
                'user_id' => $user['id'],
                'email' => $user['email'] ?? '',
                'name' => $user['name'],
            ];
            
            $tokenPair = JWTManager::generateTokenPair($payload);
            $token = $tokenPair['access_token'];
            
            $userData = [
                'id' => $user['id'],
                'name' => $user['name'] ?? '',
                'email' => $user['email'] ?? '',
                'provider' => 'apple',
                'token' => $token,
                'access_token' => $token,
                'refresh_token' => $tokenPair['refresh_token'],
                'token_type' => $tokenPair['token_type'],
                'expires_in' => $tokenPair['expires_in'],
                'refresh_expires_in' => $tokenPair['refresh_expires_in'],
            ];
            
            $result = [
                'success' => true,
                'provider' => 'apple',
                'is_new_user' => false,
                'token' => $token,
                'refresh_token' => $tokenPair['refresh_token'],
                'user_data' => $userData
            ];
            $redirectUrl = $frontendUrl . '/#/home';
        }
        
        error_log("Apple OAuth Callback - 結果: " . json_encode($result));
        
        // 根據是否為 popup 模式決定處理方式
        if ($isPopup) {
            // Popup 模式：使用 postMessage 傳送結果到主頁面
            error_log("🔍 Apple Popup 模式 - 使用 postMessage");
            
            // 設置 CORS 和 COOP 標頭（與 Google/Facebook 一致）
            header('Cross-Origin-Opener-Policy: unsafe-none');
            header('Cross-Origin-Embedder-Policy: unsafe-none');
            header('Cross-Origin-Resource-Policy: cross-origin');
            header('Access-Control-Allow-Origin: *');
            header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
            header('Access-Control-Allow-Headers: Content-Type, Authorization');
            header('Access-Control-Allow-Credentials: true');
            header('Access-Control-Max-Age: 86400');
            header('Content-Type: text/html; charset=utf-8');
            
            echo "<!DOCTYPE html>
<html>
<head>
    <title>Apple OAuth Result</title>
    <meta charset=\"utf-8\">
</head>
<body>
    <script>
        console.log('🔍 Apple Popup 視窗載入完成');
        console.log('🔍 window.opener 存在:', !!window.opener);
        console.log('🔍 當前 origin:', window.location.origin);
        
        // 使用 postMessage 傳送結果到主頁面
        if (window.opener) {
            console.log('🔍 傳送 Apple postMessage 到主頁面');
            
            // 嘗試多個可能的 origin（優先使用正確的 origin）
            const possibleOrigins = [
                'http://localhost:3000',  // 主要 origin
                'http://127.0.0.1:3000', // 備用 origin
                '*'  // 最後備用：允許所有 origin
            ];
            
            // 發送到所有可能的 origin
            possibleOrigins.forEach(origin => {
                try {
                    window.opener.postMessage({
                        type: 'oauth_result',
                        data: " . json_encode($result) . "
                    }, origin);
                    console.log('🔍 Apple 結果已發送到 origin:', origin);
                } catch (e) {
                    console.log('⚠️ Apple 結果發送到 origin 失敗:', origin, e);
                }
            });
            
            // 嘗試關閉 popup，但不強求成功
            try {
                console.log('🔍 嘗試關閉 Apple popup 視窗');
                window.close();
            } catch (e) {
                console.log('⚠️ 無法關閉 Apple popup，交給主頁處理:', e);
            }
        } else {
            console.log('🔍 window.opener 不存在，重定向到主頁面');
            // 如果無法關閉 popup，重定向到主頁面（使用 hash 路由）
            window.location.href = '$redirectUrl';
        }
    </script>
    <p>正在處理 Apple 登入結果...</p>
</body>
</html>";
            exit;
        } else {
            // 正常重定向到前端
            header('Location: ' . $redirectUrl);
            exit;
        }
        
    } else {
        throw new Exception('ID token is required for Apple login');
    }
    
} catch (Exception $e) {
    error_log("Apple OAuth Callback Error: " . $e->getMessage());
    
    $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
    
    // 檢查是否為 popup 模式（錯誤處理）
    $isPopupError = false;
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $isPopupError = isset($_POST['popup']) && $_POST['popup'] === 'true';
    } else {
        $isPopupError = isset($_GET['popup']) && $_GET['popup'] === 'true';
    }
    
    if ($isPopupError) {
        // Popup 模式：使用 postMessage 傳送錯誤結果到主頁面
        $result = [
            'success' => false,
            'provider' => 'apple',
            'error' => $e->getMessage()
        ];
        
        error_log("🔍 Apple Popup 錯誤結果: " . json_encode($result));
        
        // 設置 CORS 和 COOP 標頭
        header('Cross-Origin-Opener-Policy: unsafe-none');
        header('Cross-Origin-Embedder-Policy: unsafe-none');
        header('Cross-Origin-Resource-Policy: cross-origin');
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization');
        header('Access-Control-Allow-Credentials: true');
        header('Access-Control-Max-Age: 86400');
        header('Content-Type: text/html; charset=utf-8');
        
        echo "<!DOCTYPE html>
<html>
<head>
    <title>Apple OAuth Error</title>
    <meta charset=\"utf-8\">
</head>
<body>
    <script>
        console.log('🔍 Apple Popup 錯誤視窗載入完成');
        console.log('🔍 window.opener 存在:', !!window.opener);
        console.log('🔍 當前 origin:', window.location.origin);
        
        // 使用 postMessage 傳送錯誤結果到主頁面
        if (window.opener) {
            console.log('🔍 傳送 Apple 錯誤 postMessage 到主頁面');
            
            // 嘗試多個可能的 origin（優先使用正確的 origin）
            const possibleOrigins = [
                'http://localhost:3000',  // 主要 origin
                'http://127.0.0.1:3000', // 備用 origin
                '*'  // 最後備用：允許所有 origin
            ];
            
            // 發送到所有可能的 origin
            possibleOrigins.forEach(origin => {
                try {
                    window.opener.postMessage({
                        type: 'oauth_result',
                        data: " . json_encode($result) . "
                    }, origin);
                    console.log('🔍 Apple 錯誤已發送到 origin:', origin);
                } catch (e) {
                    console.log('⚠️ Apple 錯誤發送到 origin 失敗:', origin, e);
                }
            });
            
            // 嘗試關閉 popup，但不強求成功
            try {
                console.log('🔍 嘗試關閉 Apple popup 視窗');
                window.close();
            } catch (e) {
                console.log('⚠️ 無法關閉 Apple popup，交給主頁處理:', e);
            }
        } else {
            console.log('🔍 window.opener 不存在，重定向到錯誤頁面');
            // 如果無法關閉 popup，重定向到錯誤頁面（使用 hash 路由）
            window.location.href = '" . $frontendUrl . "/#/auth/callback?success=false&provider=apple&error=" . urlencode($e->getMessage()) . "';
        }
    </script>
    <p>Apple 登入失敗，正在關閉視窗...</p>
</body>
</html>";
        exit;
    } else {
        // 正常重定向到錯誤頁面
        $errorUrl = $frontendUrl . '/#/auth/callback?success=false&provider=apple&error=' . urlencode($e->getMessage());
        header('Location: ' . $errorUrl);
        exit;
    }
}
?>

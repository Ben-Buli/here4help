<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../config/php84_compatibility.php';

// 添加 CORS 和 COOP 標頭
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, HEAD');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Origin, Accept');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Max-Age: 86400');

// 添加 COOP/COEP/CORP 標頭
header("Cross-Origin-Opener-Policy: unsafe-none");
header("Cross-Origin-Embedder-Policy: unsafe-none");
header("Cross-Origin-Resource-Policy: cross-origin");

// 針對 popup 頁面，使用 text/html 而不是 application/json
if (isset($_GET['popup']) && $_GET['popup'] === 'true') {
    header('Content-Type: text/html; charset=utf-8');
} else {
    header('Content-Type: application/json');
}

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

// 引入必要的檔案
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 載入環境配置
require_once __DIR__ . '/../../config/env_loader.php';

try {
    // 檢查是否為 GET 請求（OAuth 回調通常是 GET）
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        throw new Exception('Invalid request method');
    }
    
    // 檢查是否為 popup 模式
    $isPopup = isset($_GET['popup']) && $_GET['popup'] === 'true';
    
    // 獲取回調參數
    $code = $_GET['code'] ?? '';
    $state = $_GET['state'] ?? '';
    $error = $_GET['error'] ?? '';
    
    error_log("Facebook OAuth Callback - 開始處理回調");
    error_log("Code: $code");
    error_log("State: $state");
    error_log("Popup mode: " . ($isPopup ? 'true' : 'false'));
    
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
    if (!preg_match('/^web_facebook_\d+$/', $state)) {
        throw new Exception('Invalid state parameter');
    }
    
    // 從環境配置獲取 Facebook OAuth 設定
    $appId = EnvLoader::get('FACEBOOK_APP_ID', '');
    $appSecret = EnvLoader::get('FACEBOOK_APP_SECRET', '');
    $redirectUri = EnvLoader::get('FACEBOOK_REDIRECT_URI', 'http://localhost:8888/here4help/backend/api/auth/facebook-callback.php');
    
    // 檢查是否在 popup 視窗中，如果是則調整 redirect_uri
    // 調整 redirect_uri 以匹配 token 交換（如果有 popup 參數）
    if ($isPopup) {
        $redirectUri = $redirectUri . '?popup=true';
        error_log("Facebook OAuth Callback - 調整後的 redirect_uri: $redirectUri");
    }
    
    if (empty($appId) || empty($appSecret)) {
        throw new Exception('Facebook OAuth configuration is incomplete');
    }
    
    error_log("Facebook OAuth Callback - 配置驗證通過");
    
    // 第一步：使用授權碼交換 access token
    error_log("Facebook OAuth Callback - 開始交換 access token");
    
    $tokenUrl = 'https://graph.facebook.com/v18.0/oauth/access_token';
    $tokenData = [
        'client_id' => $appId,
        'client_secret' => $appSecret,
        'code' => $code,
        'redirect_uri' => $redirectUri,
    ];
    
    // 使用 file_get_contents 替代 cURL
    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => 'Content-Type: application/x-www-form-urlencoded',
            'content' => http_build_query($tokenData)
        ]
    ]);
    
    $tokenResponse = file_get_contents($tokenUrl, false, $context);
    if ($tokenResponse === false) {
        throw new Exception('Failed to exchange authorization code for access token');
    }
    
    $tokenResult = json_decode($tokenResponse, true);
    if (!$tokenResult || !isset($tokenResult['access_token'])) {
        throw new Exception('Invalid token response from Facebook');
    }
    
    $accessToken = $tokenResult['access_token'];
    
    error_log("Facebook OAuth Callback - Access token 獲取成功");
    
    // 第二步：使用 access token 獲取用戶資料
    error_log("Facebook OAuth Callback - 開始獲取用戶資料");
    
    $userInfoUrl = 'https://graph.facebook.com/me?fields=id,name,email,picture&access_token=' . urlencode($accessToken);
    $userInfoResponse = file_get_contents($userInfoUrl);
    if ($userInfoResponse === false) {
        throw new Exception('Failed to fetch user information from Facebook');
    }
    
    $userInfo = json_decode($userInfoResponse, true);
    if (!$userInfo || !isset($userInfo['id'])) {
        throw new Exception('Invalid user information from Facebook');
    }
    
    error_log("Facebook OAuth Callback - 用戶資料獲取成功");
    
    // 第三步：處理用戶登入邏輯（類似 facebook-login.php）
    $facebookId = $userInfo['id'];
    $email = trim($userInfo['email'] ?? '');
    $name = trim($userInfo['name'] ?? '');
    $avatarUrl = $userInfo['picture']['data']['url'] ?? '';
    
    // 建立資料庫連線
    $db = Database::getInstance();
    
    // 檢查是否已存在對應的 user_identity
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'facebook' AND ui.provider_user_id = ?",
        [$facebookId]
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
        error_log("Facebook OAuth Callback - 現有用戶登入成功");
    } else {
        // 新用戶，需要導向註冊頁面
        $isNewUser = true;
        
        // 建立臨時用戶記錄
        $oauthToken = bin2hex(random_bytes(32));
        $expiredAt = date('Y-m-d H:i:s', time() + 3600); // 1小時後過期
        
        $db->query(
            "INSERT INTO oauth_temp_users (
                token, provider, provider_user_id, email, name, avatar_url, 
                raw_data, expired_at, created_at
            ) VALUES (?, 'facebook', ?, ?, ?, ?, ?, ?, NOW())
            ON DUPLICATE KEY UPDATE
                token = VALUES(token),
                email = VALUES(email),
                name = VALUES(name),
                avatar_url = VALUES(avatar_url),
                raw_data = VALUES(raw_data),
                expired_at = VALUES(expired_at),
                updated_at = NOW()",
            [
                $oauthToken, $facebookId, $email, $name, $avatarUrl,
                json_encode($userInfo), $expiredAt
            ]
        );
        
        error_log("Facebook OAuth Callback - 新用戶，建立臨時記錄");
    }
    
    // 準備重定向 URL
    $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
    
    if ($isNewUser) {
        // 新用戶：重定向到註冊頁面
        $redirectUrl = $frontendUrl . '/#/signup?token=' . urlencode($oauthToken) . '&provider=facebook&is_new_user=true';
        $result = [
            'success' => true,
            'provider' => 'facebook',
            'is_new_user' => true,
            'oauth_token' => $oauthToken,
            'redirect_url' => $redirectUrl
        ];
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
            'provider' => 'facebook',
        ];
        
        $redirectUrl = $frontendUrl . '/#/home';
        $result = [
            'success' => true,
            'provider' => 'facebook',
            'is_new_user' => false,
            'token' => $token,
            'user_data' => $userData,
            'redirect_url' => $redirectUrl
        ];
    }
    
    error_log("Facebook OAuth Callback - 重定向到: $redirectUrl");
    
    // 如果是 popup 模式，使用 postMessage 而不是重定向
    if ($isPopup) {
        // 準備 popup 結果數據
        $result = [
            'success' => true,
            'provider' => 'facebook',
            'is_new_user' => $isNewUser,
            'oauth_token' => $isNewUser ? $oauthToken : null,
            'token' => $isNewUser ? null : $token,
            'user_data' => $isNewUser ? null : $userData,
            'redirect_url' => $redirectUrl
        ];
        
        error_log("🔍 Facebook Popup 結果: " . json_encode($result));
        
        // 設置 CORS 和 COOP 標頭（與 Google 一致）
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
    <meta charset='utf-8'>
    <title>Facebook 登入處理中...</title>
</head>
<body>
    <script>
        console.log('🔍 Facebook Popup 視窗載入完成');
        console.log('🔍 window.opener 存在:', !!window.opener);
        console.log('🔍 當前 origin:', window.location.origin);
        console.log('🔍 當前 URL:', window.location.href);
        console.log('🔍 是否 HTTPS:', window.location.protocol === 'https:');
        
        // 檢查 opener 的 origin (如果可能)
        try {
            console.log('🔍 Opener origin:', window.opener.location.origin);
        } catch (e) {
            console.log('⚠️ 無法讀取 opener origin (跨域限制):', e.message);
        }
        
        // 使用 postMessage 傳送結果到主頁面
        if (window.opener) {
            console.log('🔍 傳送 Facebook postMessage 到主頁面');
            
            // 嘗試多個可能的 origin（包含 HTTPS 變體）
            const possibleOrigins = [
                'http://localhost:3000',  // 主要 origin
                'http://127.0.0.1:3000', // 備用 origin
                'https://localhost:3000', // HTTPS localhost
                'https://127.0.0.1:3000', // HTTPS 127.0.0.1
                '*'  // 最後備用：允許所有 origin
            ];
            
            // 首先嘗試不限制 origin 的 postMessage
            try {
                window.opener.postMessage({
                    type: 'oauth_result',
                    data: " . json_encode($result) . "
                }, '*');
                console.log('✅ Facebook 結果已發送 (無限制 origin)');
            } catch (e) {
                console.log('⚠️ 無限制 origin 發送失敗:', e);
                
                // 備用方案：嘗試特定 origins
                possibleOrigins.forEach(origin => {
                    try {
                        window.opener.postMessage({
                            type: 'oauth_result',
                            data: " . json_encode($result) . "
                        }, origin);
                        console.log('🔍 Facebook 結果已發送到 origin:', origin);
                    } catch (e) {
                        console.log('⚠️ Facebook 結果發送到 origin 失敗:', origin, e);
                    }
                });
            }
            
            // 備用方案：如果 postMessage 失敗，嘗試使用 localStorage
            try {
                const resultData = {
                    type: 'oauth_result',
                    data: " . json_encode($result) . ",
                    timestamp: Date.now()
                };
                localStorage.setItem('facebook_oauth_result', JSON.stringify(resultData));
                console.log('📦 Facebook 結果已存儲到 localStorage');
            } catch (e) {
                console.log('⚠️ localStorage 存儲失敗:', e);
            }
            
            // 延遲關閉 popup，確保 postMessage 有時間傳送
            setTimeout(() => {
                try {
                    console.log('🔍 嘗試關閉 Facebook popup 視窗');
                    window.close();
                } catch (e) {
                    console.log('⚠️ 無法關閉 Facebook popup，交給主頁處理:', e);
                }
            }, 1500); // 延遲 1.5 秒
        } else {
            console.log('🔍 window.opener 不存在，重定向到主頁面');
            // 如果無法關閉 popup，重定向到主頁面（使用 hash 路由）
            window.location.href = '$redirectUrl';
        }
    </script>
    <p>正在處理 Facebook 登入結果...</p>
</body>
</html>";
        exit;
    } else {
        // 正常重定向到前端
        header('Location: ' . $redirectUrl);
        exit;
    }
    
} catch (Exception $e) {
    error_log("Facebook OAuth Callback Error: " . $e->getMessage());
    
    // 檢查是否在 popup 視窗中
    $isPopup = isset($_GET['popup']) && $_GET['popup'] === 'true';
    
    // 準備錯誤結果
    $result = [
        'success' => false,
        'provider' => 'facebook',
        'error' => $e->getMessage()
    ];
    
    // 如果是 popup 模式，使用 postMessage 而不是重定向
    if ($isPopup) {
        // 設置 CORS 和 COOP 標頭（與 Google 一致）
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
    <meta charset='utf-8'>
    <title>Facebook 登入錯誤</title>
</head>
<body>
    <script>
        console.log('🔍 Facebook Popup 錯誤視窗載入完成');
        console.log('🔍 window.opener 存在:', !!window.opener);
        console.log('🔍 當前 origin:', window.location.origin);
        
        // 使用 postMessage 傳送錯誤結果到主頁面
        if (window.opener) {
            console.log('🔍 傳送 Facebook 錯誤 postMessage 到主頁面');
            
            // 嘗試多個可能的 origin（包含 HTTPS 變體）
            const possibleOrigins = [
                'http://localhost:3000',  // 主要 origin
                'http://127.0.0.1:3000', // 備用 origin
                'https://localhost:3000', // HTTPS localhost
                'https://127.0.0.1:3000', // HTTPS 127.0.0.1
                '*'  // 最後備用：允許所有 origin
            ];
            
            // 首先嘗試不限制 origin 的 postMessage
            try {
                window.opener.postMessage({
                    type: 'oauth_result',
                    data: " . json_encode($result) . "
                }, '*');
                console.log('✅ Facebook 錯誤已發送 (無限制 origin)');
            } catch (e) {
                console.log('⚠️ 無限制 origin 錯誤發送失敗:', e);
                
                // 備用方案：嘗試特定 origins
                possibleOrigins.forEach(origin => {
                    try {
                        window.opener.postMessage({
                            type: 'oauth_result',
                            data: " . json_encode($result) . "
                        }, origin);
                        console.log('🔍 Facebook 錯誤已發送到 origin:', origin);
                    } catch (e) {
                        console.log('⚠️ Facebook 錯誤發送到 origin 失敗:', origin, e);
                    }
                });
            }
            
            // 延遲關閉 popup，確保 postMessage 有時間傳送
            setTimeout(() => {
                try {
                    console.log('🔍 嘗試關閉 Facebook popup 視窗');
                    window.close();
                } catch (e) {
                    console.log('⚠️ 無法關閉 Facebook popup，交給主頁處理:', e);
                }
            }, 1000); // 延遲 1 秒
        } else {
            console.log('🔍 window.opener 不存在，重定向到錯誤頁面');
            // 如果無法關閉 popup，重定向到錯誤頁面（使用 hash 路由）
            window.location.href = '" . EnvLoader::get('FRONTEND_URL', 'http://localhost:3000') . "/#/auth/callback?success=false&provider=facebook&error=" . urlencode($e->getMessage()) . "';
        }
    </script>
    <p>Facebook 登入失敗，正在關閉視窗...</p>
</body>
</html>";
        exit;
    } else {
        // 正常重定向到前端應用，並傳遞錯誤資訊（使用 hash 路由）
        $frontendUrl = EnvLoader::get('FRONTEND_URL', 'http://localhost:3000');
        $errorRedirectUrl = $frontendUrl . '/#/auth/callback?' . http_build_query([
            'success' => false,
            'provider' => 'facebook',
            'error' => $e->getMessage()
        ]);
        
        header('Location: ' . $errorRedirectUrl);
        exit;
    }
}
?>

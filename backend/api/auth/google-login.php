<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/AccountBlocker.php';
require_once __DIR__ . '/../../config/env_loader.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::methodNotAllowed('Only POST is allowed');
    }

    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        Response::badRequest('Invalid JSON body');
    }

    $idToken = trim($data['id_token'] ?? $data['idToken'] ?? '');
    $accessToken = trim($data['access_token'] ?? $data['accessToken'] ?? '');
    $platform = strtolower(trim($data['platform'] ?? ''));
    $serverAuthCode = trim($data['server_auth_code'] ?? $data['serverAuthCode'] ?? '');

    // 若有提供 server_auth_code，優先嘗試交換取得 id_token
    if ($idToken === '' && $serverAuthCode !== '') {
        $clientId = EnvLoader::get('GOOGLE_CLIENT_ID', '');
        $clientSecret = EnvLoader::get('GOOGLE_CLIENT_SECRET', '');
        if (empty($clientId) || empty($clientSecret)) {
            throw new Exception('Google client id/secret not configured');
        }

        $tokenUrl = 'https://oauth2.googleapis.com/token';
        $postData = [
            'code' => $serverAuthCode,
            'client_id' => $clientId,
            'client_secret' => $clientSecret,
            'grant_type' => 'authorization_code',
            // 使用 postmessage 作為 redirect_uri 以支援行動與 Web 的 server auth code
            'redirect_uri' => 'postmessage',
        ];
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => 'Content-Type: application/x-www-form-urlencoded',
                'content' => http_build_query($postData)
            ]
        ]);
        $exchangeResp = @file_get_contents($tokenUrl, false, $context);
        if ($exchangeResp === false) {
            throw new Exception('Failed to exchange server_auth_code');
        }
        $exchange = json_decode($exchangeResp, true);
        if (!is_array($exchange) || empty($exchange['id_token'])) {
            throw new Exception('Invalid exchange response');
        }
        $idToken = $exchange['id_token'];
        // 補上 access_token（若有）
        $accessToken = $exchange['access_token'] ?? $accessToken;
    }

    if ($idToken === '') {
        Response::badRequest('id_token or server_auth_code is required');
    }

    // 從環境載入允許的 Google Client IDs（至少需有一個）
    $webClientId = EnvLoader::get('GOOGLE_CLIENT_ID', '');
    $androidClientId = EnvLoader::get('GOOGLE_ANDROID_CLIENT_ID', '');
    $iosClientId = EnvLoader::get('GOOGLE_IOS_CLIENT_ID', '');

    $allowedAudiences = array_values(array_filter([
        $webClientId,
        $androidClientId,
        $iosClientId,
    ]));

    if (empty($allowedAudiences)) {
        throw new Exception('Google client id not configured');
    }

    // 使用 Google tokeninfo 端點驗證 id_token
    $tokenInfoUrl = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($idToken);
    $tokenInfoResponse = @file_get_contents($tokenInfoUrl);
    if ($tokenInfoResponse === false) {
        throw new Exception('Failed to verify id_token with Google');
    }
    $tokenInfo = json_decode($tokenInfoResponse, true);
    if (!is_array($tokenInfo) || !isset($tokenInfo['aud'])) {
        throw new Exception('Invalid id_token response from Google');
    }

    // 基本驗證：aud/iss/exp
    $aud = $tokenInfo['aud'];
    $iss = $tokenInfo['iss'] ?? '';
    $exp = isset($tokenInfo['exp']) ? intval($tokenInfo['exp']) : 0;

    if (!in_array($aud, $allowedAudiences, true)) {
        throw new Exception('Audience mismatch');
    }
    if ($iss !== 'https://accounts.google.com' && $iss !== 'accounts.google.com') {
        throw new Exception('Invalid issuer');
    }
    if ($exp > 0 && $exp < time()) {
        throw new Exception('id_token expired');
    }

    // 提取使用者資訊
    $googleId = $tokenInfo['sub'] ?? '';
    $email = $tokenInfo['email'] ?? '';
    $emailVerified = ($tokenInfo['email_verified'] ?? 'false') === 'true' || ($tokenInfo['email_verified'] ?? false) === true;
    $name = $tokenInfo['name'] ?? ($data['name'] ?? '');
    $avatarUrl = $tokenInfo['picture'] ?? ($data['avatar_url'] ?? '');

    if (empty($googleId)) {
        throw new Exception('Missing Google user id');
    }

    // 資料庫處理
    $db = Database::getInstance();
    $pdo = $db->getConnection();

    if (AccountBlocker::isEmailBlocked($pdo, $email)) {
        Response::forbidden('ACCOUNT_DELETED_BY_ADMIN');
    }

    if (AccountBlocker::isIdentityBlocked($pdo, 'google', $googleId)) {
        Response::forbidden('ACCOUNT_DELETED_BY_ADMIN');
    }

    // 情況1：既有 user_identities + users
    $stmt = $db->query(
        "SELECT ui.*, u.* FROM user_identities ui 
         INNER JOIN users u ON ui.user_id = u.id 
         WHERE ui.provider = 'google' AND (ui.email = ? OR ui.provider_user_id = ?)",
        [$email, $googleId]
    );
    $existing = $stmt->fetch();

    $isNewUser = false;
    $redirectToSignup = false;
    $existingUserId = null;
    $user = null;

    if ($existing) {
        // 更新最後登入時間與 access_token
        $db->query("UPDATE users SET updated_at = NOW() WHERE id = ?", [$existing['user_id']]);
        $db->query(
            "UPDATE user_identities SET access_token = ?, id_token = ?, updated_at = NOW() WHERE id = ?",
            [$accessToken ?: null, $idToken, $existing['id']]
        );
        $user = $existing;
    } else {
        // 檢查 email 存在但 user 失聯
        $stmt = $db->query(
            "SELECT ui.* FROM user_identities ui 
             LEFT JOIN users u ON ui.user_id = u.id 
             WHERE ui.provider = 'google' AND ui.email = ? AND u.id IS NULL",
            [$email]
        );
        $dangling = $stmt->fetch();
        if ($dangling) {
            $isNewUser = true;
            $redirectToSignup = true;
            $existingUserId = $dangling['user_id'];
        } else {
            // 完全新用戶
            $isNewUser = true;
            $redirectToSignup = true;
        }
    }

    if ($user !== null) {
        // 檢查帳號權限（與傳統登入一致）
        $userPermission = (int)($user['permission'] ?? 0);
        if ($userPermission < 0 && $userPermission != -1) {
            if ($userPermission == -2) {
                Response::forbidden('ACCOUNT_DELETED_BY_ADMIN');
            } elseif ($userPermission == -3) {
                Response::forbidden('ACCOUNT_DISABLED_BY_USER');
            } elseif ($userPermission == -4) {
                Response::forbidden('ACCOUNT_DELETED_BY_USER');
            } else {
                Response::forbidden('Account is not allowed to login (permission).');
            }
        }

        // 建立 Access/Refresh Tokens
        $payload = [
            'user_id' => (int)($user['id'] ?? $user['user_id']),
            'email' => $user['email'] ?? $email,
            'name' => $user['name'] ?? $name,
        ];
        $tokenPair = JWTManager::generateTokenPair($payload);

        $userData = [
            'id' => (int)($user['id'] ?? $user['user_id']),
            'name' => $user['name'] ?? $name,
            'email' => $user['email'] ?? $email,
            'phone' => $user['phone'] ?? '',
            'nickname' => $user['nickname'] ?? ($user['name'] ?? $name),
            'avatar_url' => $user['avatar_url'] ?? $avatarUrl,
            'points' => (int)($user['points'] ?? 0),
            'status' => $user['status'] ?? 'active',
            'provider' => 'google',
            'created_at' => $user['created_at'] ?? '',
            'updated_at' => $user['updated_at'] ?? '',
            'referral_code' => $user['referral_code'] ?? '',
            'primary_language' => $user['primary_language'] ?? 'English',
            'permission' => (int)($user['permission'] ?? 0),
            'is_new_user' => false,
            'provider_user_id' => $googleId,
            'google_id' => $googleId,
            'token' => $tokenPair['access_token'],
            'access_token' => $tokenPair['access_token'],
            'refresh_token' => $tokenPair['refresh_token'],
            'token_type' => $tokenPair['token_type'],
            'expires_in' => $tokenPair['expires_in'],
            'refresh_expires_in' => $tokenPair['refresh_expires_in'],
        ];

        Response::success($userData, 'Login success');
    } else {
        // 新用戶：記錄暫存，回傳 temp token 由前端導註冊
        $tempToken = bin2hex(openssl_random_pseudo_bytes(24));
        $expiresAt = date('Y-m-d H:i:s', time() + 3600);

        $db->query(
            "INSERT INTO oauth_temp_users (provider, provider_user_id, email, name, avatar_url, raw_data, token, expired_at, created_at)
             VALUES ('google', ?, ?, ?, ?, ?, ?, ?, NOW())
             ON DUPLICATE KEY UPDATE
               email = VALUES(email),
               name = VALUES(name),
               avatar_url = VALUES(avatar_url),
               raw_data = VALUES(raw_data),
               token = VALUES(token),
               expired_at = VALUES(expired_at)",
            [
                $googleId,
                $email ?: null,
                $name ?: null,
                $avatarUrl ?: null,
                json_encode([
                    'token_info' => $tokenInfo,
                    'platform' => $platform,
                ], JSON_UNESCAPED_UNICODE),
                $tempToken,
                $expiresAt
            ]
        );

        $resp = [
            'is_new_user' => true,
            'provider' => 'google',
            'provider_user_id' => $googleId,
            'email' => $email,
            'name' => $name,
            'avatar_url' => $avatarUrl,
            'temp_token' => $tempToken,
            'temp_expires_at' => $expiresAt,
            'email_verified' => $emailVerified,
        ];
        if ($existingUserId !== null) {
            $resp['existing_user_id'] = (int)$existingUserId;
        }

        Response::success($resp, 'Signup required');
    }
} catch (Exception $e) {
    error_log('google-login.php error: ' . $e->getMessage());
    Response::serverError($e->getMessage());
}
?>

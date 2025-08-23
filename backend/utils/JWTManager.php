<?php
/**
 * JWT (JSON Web Token) 管理工具類
 * 實作 RFC 7519 標準，提供安全的 token 生成和驗證
 * 
 * @author Here4Help Team
 * @version 2.0.0
 * @since 2025-01-11
 */

class JWTManager {
    /**
     * JWT 演算法，鎖定為 HS256 防止 alg:none 攻擊
     */
    private static $algorithm = 'HS256';
    
    /**
     * Access Token 過期時間（秒）
     */
    private static $accessTokenExpiration = 3600; // 1 小時
    
    /**
     * Refresh Token 過期時間（秒）
     */
    private static $refreshTokenExpiration = 604800; // 7 天
    
    /**
     * 獲取 JWT 密鑰
     * 
     * @return string
     * @throws Exception
     */
    private static function getSecret() {
        // 從環境變數獲取密鑰
        $secret = getenv('JWT_SECRET');
        if (!$secret) {
            // 嘗試從項目根目錄的 .env 檔案載入
            $envPath = __DIR__ . '/../../.env';
            if (file_exists($envPath)) {
                $envContent = file_get_contents($envPath);
                preg_match('/JWT_SECRET=([^\s]+)/', $envContent, $matches);
                if (isset($matches[1])) {
                    $secret = trim($matches[1]);
                    error_log("JWT_SECRET loaded from .env file");
                }
            }
        }
        
        if (!$secret) {
            throw new Exception('JWT_SECRET not configured. Please check your .env file.');
        }
        
        return $secret;
    }
    
    /**
     * 生成 JWT Token
     * 
     * @param array $payload 載荷資料
     * @param int|null $expiration 過期時間（秒），null 使用預設值
     * @return string
     * @throws Exception
     */
    public static function generateToken($payload, $expiration = null) {
        try {
            $secret = self::getSecret();
            
            // 準備 header
            $header = [
                'alg' => self::$algorithm,
                'typ' => 'JWT'
            ];
            
            // 準備 payload
            $payload['iat'] = time(); // 簽發時間
            $payload['exp'] = time() + ($expiration ?? self::$accessTokenExpiration); // 過期時間
            $payload['nbf'] = time(); // 生效時間（現在）
            
            // 編碼 header 和 payload
            $headerEncoded = self::base64UrlEncode(json_encode($header));
            $payloadEncoded = self::base64UrlEncode(json_encode($payload));
            
            // 生成簽名
            $signature = hash_hmac('sha256', 
                $headerEncoded . '.' . $payloadEncoded, 
                $secret, 
                true
            );
            $signatureEncoded = self::base64UrlEncode($signature);
            
            // 組合 JWT
            $token = $headerEncoded . '.' . $payloadEncoded . '.' . $signatureEncoded;
            error_log("JWTManager generated token (first 50): " . substr($token, 0, 50) . "...");
            error_log("JWTManager using secret hash: " . hash('sha256', $secret));
            
            // 驗證生成的 token（使用內部驗證，避免循環調用）
            if (!self::internalValidateToken($token)) {
                throw new Exception('Generated token validation failed');
            }
            
            return $token;
            
        } catch (Exception $e) {
            error_log("JWT generation failed: " . $e->getMessage());
            throw new Exception('Token generation failed: ' . $e->getMessage());
        }
    }
    
    /**
     * 驗證 JWT Token
     * 
     * @param string $token JWT token
     * @return array|false 成功返回 payload，失敗返回 false
     */
    public static function validateToken($token) {
        try {
            $secret = self::getSecret();
            error_log("JWTManager validateToken secret hash: " . hash('sha256', $secret));
            
            // 檢查 token 格式
            $parts = explode('.', $token);
            if (count($parts) !== 3) {
                error_log("JWT validation failed: Invalid token format");
                return false;
            }
            
            list($headerEncoded, $payloadEncoded, $signatureEncoded) = $parts;
            
            // 解碼 header
            $header = json_decode(self::base64UrlDecode($headerEncoded), true);
            if (!$header || !isset($header['alg']) || $header['alg'] !== self::$algorithm) {
                error_log("JWT validation failed: Invalid algorithm or header");
                return false;
            }
            
            // 解碼 payload
            $payload = json_decode(self::base64UrlDecode($payloadEncoded), true);
            if (!$payload) {
                error_log("JWT validation failed: Invalid payload");
                return false;
            }
            
            // 驗證簽名
            $expectedSignature = hash_hmac('sha256', 
                $headerEncoded . '.' . $payloadEncoded, 
                $secret, 
                true
            );
            $expectedSignatureEncoded = self::base64UrlEncode($expectedSignature);
            error_log("JWTManager expected signature: " . substr($expectedSignatureEncoded, 0, 20) . "...");
            error_log("JWTManager provided signature: " . substr($signatureEncoded, 0, 20) . "...");
            
            if (!hash_equals($signatureEncoded, $expectedSignatureEncoded)) {
                error_log("JWT validation failed: Invalid signature");
                return false;
            }
            
            // 驗證時間
            $now = time();
            
            // 檢查是否過期
            if (isset($payload['exp']) && $payload['exp'] < $now) {
                error_log("JWT validation failed: Token expired");
                return false;
            }
            
            // 檢查是否生效
            if (isset($payload['nbf']) && $payload['nbf'] > $now) {
                error_log("JWT validation failed: Token not yet valid");
                return false;
            }
            
            // 檢查必要欄位
            if (!isset($payload['user_id'])) {
                error_log("JWT validation failed: Missing user_id");
                return false;
            }
            
            return $payload;
            
        } catch (Exception $e) {
            error_log("JWT validation exception: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * 內部驗證方法（避免循環調用）
     * 
     * @param string $token JWT token
     * @return bool
     */
    private static function internalValidateToken($token) {
        try {
            $secret = self::getSecret();
            
            // 檢查 token 格式
            $parts = explode('.', $token);
            if (count($parts) !== 3) {
                return false;
            }
            
            list($headerEncoded, $payloadEncoded, $signatureEncoded) = $parts;
            
            // 解碼 header
            $header = json_decode(self::base64UrlDecode($headerEncoded), true);
            if (!$header || !isset($header['alg']) || $header['alg'] !== self::$algorithm) {
                return false;
            }
            
            // 解碼 payload
            $payload = json_decode(self::base64UrlDecode($payloadEncoded), true);
            if (!$payload) {
                return false;
            }
            
            // 驗證簽名
            $expectedSignature = hash_hmac('sha256', 
                $headerEncoded . '.' . $payloadEncoded, 
                $secret, 
                true
            );
            $expectedSignatureEncoded = self::base64UrlEncode($expectedSignature);
            
            if (!hash_equals($signatureEncoded, $expectedSignatureEncoded)) {
                return false;
            }
            
            // 驗證時間
            $now = time();
            
            // 檢查是否過期
            if (isset($payload['exp']) && $payload['exp'] < $now) {
                return false;
            }
            
            // 檢查是否生效
            if (isset($payload['nbf']) && $payload['nbf'] > $now) {
                return false;
            }
            
            // 檢查必要欄位
            if (!isset($payload['user_id'])) {
                return false;
            }
            
            return true;
            
        } catch (Exception $e) {
            return false;
        }
    }
    
    /**
     * 從 token 中提取用戶 ID
     * 
     * @param string $token JWT token
     * @return int|false 成功返回用戶 ID，失敗返回 false
     */
    public static function getUserId($token) {
        $payload = self::validateToken($token);
        return $payload ? $payload['user_id'] : false;
    }
    
    /**
     * 檢查 token 是否即將過期（提前 1 小時）
     * 
     * @param string $token JWT token
     * @return bool
     */
    public static function isExpiringSoon($token) {
        $payload = self::validateToken($token);
        if (!$payload || !isset($payload['exp'])) {
            return false;
        }
        
        $expirationTime = $payload['exp'];
        $currentTime = time();
        $oneHour = 3600; // 1 小時
        
        return ($expirationTime - $currentTime) <= $oneHour;
    }
    
    /**
     * 刷新 token（延長過期時間）
     * 
     * @param string $token 原始 token
     * @param int|null $newExpiration 新的過期時間（秒）
     * @return string|false 成功返回新 token，失敗返回 false
     */
    public static function refreshToken($token, $newExpiration = null) {
        $payload = self::validateToken($token);
        if (!$payload) {
            return false;
        }
        
        // 移除時間相關欄位，讓 generateToken 重新生成
        unset($payload['iat'], $payload['exp'], $payload['nbf']);
        
        try {
            return self::generateToken($payload, $newExpiration);
        } catch (Exception $e) {
            error_log("Token refresh failed: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * Base64 URL 安全編碼
     * 
     * @param string $data 要編碼的資料
     * @return string
     */
    private static function base64UrlEncode($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    /**
     * Base64 URL 安全解碼
     * 
     * @param string $data 要解碼的資料
     * @return string
     */
    private static function base64UrlDecode($data) {
        $data = strtr($data, '-_', '+/');
        $remainder = strlen($data) % 4;
        if ($remainder) {
            $data .= str_repeat('=', 4 - $remainder);
        }
        return base64_decode($data);
    }
    
    /**
     * 獲取 token 資訊（用於調試）
     * 
     * @param string $token JWT token
     * @return array
     */
    public static function getTokenInfo($token) {
        try {
            $parts = explode('.', $token);
            if (count($parts) !== 3) {
                return ['error' => 'Invalid token format'];
            }
            
            list($headerEncoded, $payloadEncoded, $signatureEncoded) = $parts;
            
            $header = json_decode(self::base64UrlDecode($headerEncoded), true);
            $payload = json_decode(self::base64UrlDecode($payloadEncoded), true);
            
            return [
                'header' => $header,
                'payload' => $payload,
                'signature_length' => strlen($signatureEncoded),
                'is_valid' => self::validateToken($token) !== false,
                'expires_in' => isset($payload['exp']) ? $payload['exp'] - time() : null,
                'is_expiring_soon' => self::isExpiringSoon($token)
            ];
            
        } catch (Exception $e) {
            return ['error' => $e->getMessage()];
        }
    }
    
    /**
     * 生成 Access Token 和 Refresh Token 對
     * 
     * @param array $payload 載荷資料
     * @return array
     * @throws Exception
     */
    public static function generateTokenPair($payload) {
        // 生成 Access Token（短期）
        $accessPayload = $payload;
        $accessPayload['type'] = 'access';
        $accessToken = self::generateToken($accessPayload, self::$accessTokenExpiration);
        
        // 生成 Refresh Token（長期）
        $refreshPayload = [
            'user_id' => $payload['user_id'],
            'type' => 'refresh',
            'jti' => bin2hex(random_bytes(16)) // JWT ID，用於黑名單
        ];
        $refreshToken = self::generateToken($refreshPayload, self::$refreshTokenExpiration);
        
        return [
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'token_type' => 'Bearer',
            'expires_in' => self::$accessTokenExpiration,
            'refresh_expires_in' => self::$refreshTokenExpiration
        ];
    }
    
    /**
     * 使用 Refresh Token 刷新 Access Token
     * 
     * @param string $refreshToken Refresh Token
     * @param array $newPayload 新的載荷資料（可選）
     * @return array|false
     */
    public static function refreshAccessToken($refreshToken, $newPayload = null) {
        try {
            // 驗證 Refresh Token
            $payload = self::validateToken($refreshToken);
            if (!$payload) {
                return false;
            }
            
            // 檢查是否為 Refresh Token
            if (!isset($payload['type']) || $payload['type'] !== 'refresh') {
                error_log("Token refresh failed: Not a refresh token");
                return false;
            }
            
            // 檢查是否在黑名單中
            if (self::isTokenBlacklisted($refreshToken)) {
                error_log("Token refresh failed: Token is blacklisted");
                return false;
            }
            
            // 準備新的 Access Token 載荷
            $accessPayload = $newPayload ?? [
                'user_id' => $payload['user_id']
            ];
            
            // 生成新的 Token 對
            return self::generateTokenPair($accessPayload);
            
        } catch (Exception $e) {
            error_log("Token refresh failed: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * 將 Token 加入黑名單
     * 
     * @param string $token JWT Token
     * @param string $reason 加入黑名單的原因
     * @return bool
     */
    public static function blacklistToken($token, $reason = 'revoked') {
        try {
            $payload = self::validateToken($token);
            if (!$payload) {
                return false;
            }
            
            // 獲取 Token ID
            $jti = $payload['jti'] ?? hash('sha256', $token);
            $exp = $payload['exp'] ?? (time() + 86400); // 預設 24 小時後過期
            
            // 儲存到黑名單
            $blacklistDir = __DIR__ . '/../storage/jwt_blacklist';
            if (!is_dir($blacklistDir)) {
                mkdir($blacklistDir, 0755, true);
            }
            
            $blacklistFile = $blacklistDir . '/' . $jti . '.json';
            $blacklistData = [
                'jti' => $jti,
                'token_hash' => hash('sha256', $token),
                'reason' => $reason,
                'blacklisted_at' => time(),
                'expires_at' => $exp,
                'user_id' => $payload['user_id'] ?? null
            ];
            
            return file_put_contents($blacklistFile, json_encode($blacklistData)) !== false;
            
        } catch (Exception $e) {
            error_log("Token blacklist failed: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * 檢查 Token 是否在黑名單中
     * 
     * @param string $token JWT Token
     * @return bool
     */
    public static function isTokenBlacklisted($token) {
        try {
            $payload = self::validateToken($token);
            if (!$payload) {
                return true; // 無效 token 視為已撤銷
            }
            
            $jti = $payload['jti'] ?? hash('sha256', $token);
            
            $blacklistDir = __DIR__ . '/../storage/jwt_blacklist';
            $blacklistFile = $blacklistDir . '/' . $jti . '.json';
            
            if (!file_exists($blacklistFile)) {
                return false;
            }
            
            $blacklistData = json_decode(file_get_contents($blacklistFile), true);
            if (!$blacklistData) {
                return false;
            }
            
            // 檢查是否過期
            if ($blacklistData['expires_at'] < time()) {
                // 清理過期的黑名單記錄
                unlink($blacklistFile);
                return false;
            }
            
            return true;
            
        } catch (Exception $e) {
            error_log("Token blacklist check failed: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * 撤銷用戶的所有 Token
     * 
     * @param int $userId 用戶 ID
     * @param string $reason 撤銷原因
     * @return int 撤銷的 Token 數量
     */
    public static function revokeAllUserTokens($userId, $reason = 'user_revoked') {
        $blacklistDir = __DIR__ . '/../storage/jwt_blacklist';
        if (!is_dir($blacklistDir)) {
            mkdir($blacklistDir, 0755, true);
        }
        
        // 創建用戶撤銷記錄
        $revokeFile = $blacklistDir . '/user_' . $userId . '_revoked.json';
        $revokeData = [
            'user_id' => $userId,
            'revoked_at' => time(),
            'reason' => $reason,
            'expires_at' => time() + self::$refreshTokenExpiration // 使用最長的 token 過期時間
        ];
        
        file_put_contents($revokeFile, json_encode($revokeData));
        
        return 1; // 返回撤銷記錄數
    }
    
    /**
     * 檢查用戶的 Token 是否被全域撤銷
     * 
     * @param int $userId 用戶 ID
     * @param int $tokenIssuedAt Token 簽發時間
     * @return bool
     */
    public static function isUserTokenRevoked($userId, $tokenIssuedAt) {
        $blacklistDir = __DIR__ . '/../storage/jwt_blacklist';
        $revokeFile = $blacklistDir . '/user_' . $userId . '_revoked.json';
        
        if (!file_exists($revokeFile)) {
            return false;
        }
        
        $revokeData = json_decode(file_get_contents($revokeFile), true);
        if (!$revokeData) {
            return false;
        }
        
        // 檢查撤銷記錄是否過期
        if ($revokeData['expires_at'] < time()) {
            unlink($revokeFile);
            return false;
        }
        
        // 檢查 Token 是否在撤銷之前簽發
        return $tokenIssuedAt < $revokeData['revoked_at'];
    }
    
    /**
     * 清理過期的黑名單記錄
     * 
     * @return int 清理的記錄數量
     */
    public static function cleanupBlacklist() {
        $blacklistDir = __DIR__ . '/../storage/jwt_blacklist';
        if (!is_dir($blacklistDir)) {
            return 0;
        }
        
        $files = glob($blacklistDir . '/*.json');
        $cleaned = 0;
        
        foreach ($files as $file) {
            $data = json_decode(file_get_contents($file), true);
            if ($data && isset($data['expires_at']) && $data['expires_at'] < time()) {
                unlink($file);
                $cleaned++;
            }
        }
        
        return $cleaned;
    }
    
    /**
     * 驗證 Token 並檢查黑名單
     * 
     * @param string $token JWT Token
     * @return array|false
     */
    public static function validateTokenWithBlacklist($token) {
        // 基本驗證
        $payload = self::validateToken($token);
        if (!$payload) {
            return false;
        }
        
        // 檢查個別 Token 黑名單
        if (self::isTokenBlacklisted($token)) {
            error_log("Token validation failed: Token is blacklisted");
            return false;
        }
        
        // 檢查用戶全域撤銷
        if (isset($payload['user_id'], $payload['iat'])) {
            if (self::isUserTokenRevoked($payload['user_id'], $payload['iat'])) {
                error_log("Token validation failed: User tokens revoked");
                return false;
            }
        }
        
        return $payload;
    }
    
    /**
     * 驗證請求中的 JWT Token
     * 支援多種 Token 來源：Authorization header、GET 參數、POST 參數
     * 
     * @return array 包含 valid (bool) 和 payload/message 的陣列
     */
    public static function validateRequest() {
        try {
            // 嘗試從多個來源獲取 token
            $token = null;
            
            // 1. 從 Authorization header 獲取
            if (function_exists('getAuthorizationHeader')) {
                $authHeader = getAuthorizationHeader();
                if ($authHeader && strpos($authHeader, 'Bearer ') === 0) {
                    $token = trim(substr($authHeader, 7));
                }
            }
            
            // 2. 從 $_SERVER 直接獲取
            if (!$token && isset($_SERVER['HTTP_AUTHORIZATION'])) {
                $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
                if (strpos($authHeader, 'Bearer ') === 0) {
                    $token = trim(substr($authHeader, 7));
                }
            }
            
            // 3. 從 GET/POST 參數獲取 (MAMP 兼容)
            if (!$token) {
                $token = $_GET['token'] ?? $_POST['token'] ?? '';
            }
            
            if (empty($token)) {
                return [
                    'valid' => false,
                    'message' => 'Token is required'
                ];
            }
            
            // 驗證 token
            $payload = self::validateTokenWithBlacklist($token);
            if (!$payload) {
                return [
                    'valid' => false,
                    'message' => 'Invalid or expired token'
                ];
            }
            
            return [
                'valid' => true,
                'payload' => $payload
            ];
            
        } catch (Exception $e) {
            error_log("JWT request validation failed: " . $e->getMessage());
            return [
                'valid' => false,
                'message' => 'Token validation error'
            ];
        }
    }
}

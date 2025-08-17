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
     * Token 過期時間（秒）
     */
    private static $expirationTime = 604800; // 7 天
    
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
            $payload['exp'] = time() + ($expiration ?? self::$expirationTime); // 過期時間
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
}

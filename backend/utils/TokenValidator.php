<?php
/**
 * Token 驗證工具類
 * 提供統一的 token 驗證介面，支援 JWT 和舊版 base64 格式
 * 
 * @author Here4Help Team
 * @version 2.0.0
 * @since 2025-01-11
 */

require_once __DIR__ . '/JWTManager.php';

class TokenValidator {
    /**
     * 驗證 token 並返回用戶 ID
     * 支援 JWT 和舊版 base64 格式（向後兼容）
     * 
     * @param string $token 要驗證的 token
     * @return int|false 成功返回用戶 ID，失敗返回 false
     */
    public static function validateToken($token) {
        if (empty($token)) {
            error_log("Token validation failed: Empty token");
            return false;
        }
        
        // 首先嘗試 JWT 驗證
        $jwtPayload = JWTManager::validateToken($token);
        if ($jwtPayload && isset($jwtPayload['user_id'])) {
            error_log("JWT token validation successful for user: " . $jwtPayload['user_id']);
            return $jwtPayload['user_id'];
        }
        
        // 如果 JWT 驗證失敗，嘗試舊版 base64 格式（向後兼容）
        $legacyPayload = self::validateLegacyToken($token);
        if ($legacyPayload && isset($legacyPayload['user_id'])) {
            error_log("Legacy base64 token validation successful for user: " . $legacyPayload['user_id']);
            return $legacyPayload['user_id'];
        }
        
        error_log("Token validation failed: Neither JWT nor legacy format valid");
        return false;
    }
    
    /**
     * 驗證舊版 base64 編碼的 JSON token（向後兼容）
     * 
     * @param string $token 舊版 token
     * @return array|false 成功返回 payload，失敗返回 false
     */
    private static function validateLegacyToken($token) {
        try {
            // 嘗試 base64 解碼
            $decoded = base64_decode($token);
            if ($decoded === false) {
                return false;
            }
            
            $payload = json_decode($decoded, true);
            if (!$payload || !isset($payload['user_id'])) {
                return false;
            }
            
            // 檢查是否過期
            if (isset($payload['exp']) && $payload['exp'] < time()) {
                error_log("Legacy token expired for user: " . $payload['user_id']);
                return false;
            }
            
            return $payload;
            
        } catch (Exception $e) {
            error_log("Legacy token validation exception: " . $e->getMessage());
            return false;
        }
    }
    
    /**
     * 從 Authorization header 中提取並驗證 token
     * 
     * @param string $authHeader Authorization header 內容
     * @return int|false 成功返回用戶 ID，失敗返回 false
     */
    public static function validateAuthHeader($authHeader) {
        if (empty($authHeader) || !preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            error_log("Invalid Authorization header format");
            return false;
        }
        
        $token = $matches[1];
        return self::validateToken($token);
    }
    
    /**
     * 檢查 token 是否即將過期
     * 
     * @param string $token 要檢查的 token
     * @return bool
     */
    public static function isExpiringSoon($token) {
        // 優先使用 JWT 檢查
        if (JWTManager::validateToken($token)) {
            return JWTManager::isExpiringSoon($token);
        }
        
        // 舊版 token 檢查
        $payload = self::validateLegacyToken($token);
        if ($payload && isset($payload['exp'])) {
            $expirationTime = $payload['exp'];
            $currentTime = time();
            $oneHour = 3600; // 1 小時
            return ($expirationTime - $currentTime) <= $oneHour;
        }
        
        return false;
    }
    
    /**
     * 獲取 token 資訊（用於調試）
     * 
     * @param string $token 要檢查的 token
     * @return array
     */
    public static function getTokenInfo($token) {
        // 優先使用 JWT 檢查
        $jwtInfo = JWTManager::getTokenInfo($token);
        if (!isset($jwtInfo['error'])) {
            $jwtInfo['type'] = 'JWT';
            return $jwtInfo;
        }
        
        // 舊版 token 檢查
        $legacyPayload = self::validateLegacyToken($token);
        if ($legacyPayload) {
            return [
                'type' => 'Legacy Base64',
                'payload' => $legacyPayload,
                'is_valid' => true,
                'expires_in' => isset($legacyPayload['exp']) ? $legacyPayload['exp'] - time() : null,
                'is_expiring_soon' => self::isExpiringSoon($token)
            ];
        }
        
        return [
            'type' => 'Unknown',
            'error' => 'Invalid token format',
            'is_valid' => false
        ];
    }
}

<?php
/**
 * Laravel Sanctum Token 驗證器
 * 用於在 PHP 後端驗證 Laravel Sanctum 生成的 token
 */

class SanctumTokenValidator {
    
    /**
     * 驗證 Sanctum token
     * 
     * @param string $token Sanctum token (格式: {id}|{plainTextToken})
     * @return array 驗證結果
     */
    public static function validateToken($token) {
        try {
            // 解析 token 格式: {id}|{plainTextToken}
            if (!str_contains($token, '|')) {
                return [
                    'valid' => false,
                    'message' => 'Invalid token format'
                ];
            }
            
            list($tokenId, $plainTextToken) = explode('|', $token, 2);
            
            if (!is_numeric($tokenId) || empty($plainTextToken)) {
                return [
                    'valid' => false,
                    'message' => 'Invalid token format'
                ];
            }
            
            // 連接到 Laravel admin 資料庫
            $adminDb = self::getAdminDatabase();
            
            // 查詢 personal_access_tokens 表
            $stmt = $adminDb->prepare("
                SELECT pat.*, a.id as admin_id, a.username, a.email, a.role_id, ar.name as role_name
                FROM personal_access_tokens pat
                JOIN admins a ON pat.tokenable_id = a.id AND pat.tokenable_type = 'App\\\\Models\\\\Admin'
                JOIN admin_roles ar ON a.role_id = ar.id
                WHERE pat.id = ? AND pat.token = ?
            ");
            
            // Sanctum 將 plain text token 進行 hash 存儲
            $hashedToken = hash('sha256', $plainTextToken);
            $stmt->execute([$tokenId, $hashedToken]);
            $tokenRecord = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$tokenRecord) {
                return [
                    'valid' => false,
                    'message' => 'Token not found or invalid'
                ];
            }
            
            // 檢查 token 是否過期
            if ($tokenRecord['expires_at'] && strtotime($tokenRecord['expires_at']) < time()) {
                return [
                    'valid' => false,
                    'message' => 'Token expired'
                ];
            }
            
            // 更新最後使用時間
            $updateStmt = $adminDb->prepare("UPDATE personal_access_tokens SET last_used_at = NOW() WHERE id = ?");
            $updateStmt->execute([$tokenId]);
            
            return [
                'valid' => true,
                'admin_id' => (int)$tokenRecord['admin_id'],
                'username' => $tokenRecord['username'],
                'email' => $tokenRecord['email'],
                'role_id' => (int)$tokenRecord['role_id'],
                'role_name' => $tokenRecord['role_name'],
                'token_name' => $tokenRecord['name'],
                'abilities' => json_decode($tokenRecord['abilities'], true) ?? []
            ];
            
        } catch (Exception $e) {
            error_log("Sanctum token validation error: " . $e->getMessage());
            return [
                'valid' => false,
                'message' => 'Token validation failed'
            ];
        }
    }
    
    /**
     * 獲取 Laravel admin 資料庫連接（使用與主系統相同的 MySQL 資料庫）
     * 
     * @return PDO
     */
    private static function getAdminDatabase() {
        // 使用與主系統相同的資料庫連接
        require_once __DIR__ . '/../config/database.php';
        return Database::getInstance()->getConnection();
    }
    
    /**
     * 驗證請求中的 Sanctum token
     * 
     * @return array 驗證結果
     */
    public static function validateRequest() {
        try {
            // 獲取 Authorization header
            require_once __DIR__ . '/../auth_helper.php';
            $authHeader = getAuthorizationHeader();
            
            if (!$authHeader || strpos($authHeader, 'Bearer ') !== 0) {
                return [
                    'valid' => false,
                    'message' => 'Authorization header missing or invalid'
                ];
            }
            
            $token = trim(substr($authHeader, 7));
            
            if (empty($token)) {
                return [
                    'valid' => false,
                    'message' => 'Token is required'
                ];
            }
            
            return self::validateToken($token);
            
        } catch (Exception $e) {
            error_log("Sanctum request validation error: " . $e->getMessage());
            return [
                'valid' => false,
                'message' => 'Request validation failed'
            ];
        }
    }
}
?>

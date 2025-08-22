<?php
/**
 * JWT Token 撤銷端點
 * 將 Token 加入黑名單
 */

require_once __DIR__ . '/../../middleware/api_middleware.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 執行中介層
ApiMiddleware::handle(['skip_rate_limit' => false]);

try {
    // 只接受 POST 請求
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::methodNotAllowed('Only POST method is allowed');
    }
    
    // 驗證 JWT Token（必須）
    $payload = ApiMiddleware::validateJWT(true);
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }
    
    // 獲取要撤銷的 token
    $tokenToRevoke = $input['token'] ?? null;
    $revokeAll = $input['revoke_all'] ?? false;
    $reason = $input['reason'] ?? 'user_requested';
    
    if ($revokeAll) {
        // 撤銷用戶的所有 token
        $revokedCount = JWTManager::revokeAllUserTokens($payload['user_id'], $reason);
        
        Response::success([
            'revoked_count' => $revokedCount,
            'revoke_all' => true
        ], 'All user tokens revoked successfully');
        
    } else {
        // 撤銷特定 token
        if (!$tokenToRevoke) {
            // 如果沒有指定 token，撤銷當前 token
            $headers = getallheaders();
            if (isset($headers['Authorization'])) {
                $auth = $headers['Authorization'];
                if (strpos($auth, 'Bearer ') === 0) {
                    $tokenToRevoke = substr($auth, 7);
                }
            }
        }
        
        if (!$tokenToRevoke) {
            Response::badRequest('Token to revoke is required');
        }
        
        // 撤銷 token
        $success = JWTManager::blacklistToken($tokenToRevoke, $reason);
        
        if (!$success) {
            Response::serverError('Failed to revoke token');
        }
        
        Response::success([
            'revoked' => true,
            'reason' => $reason
        ], 'Token revoked successfully');
    }
    
} catch (Exception $e) {
    error_log("Token revocation error: " . $e->getMessage());
    Response::serverError('Token revocation failed');
}
?>

<?php
/**
 * JWT Token 刷新端點
 * 使用 Refresh Token 獲取新的 Access Token
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
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        Response::badRequest('Invalid JSON input');
    }
    
    // 驗證必要欄位
    if (empty($input['refresh_token'])) {
        Response::badRequest('Refresh token is required');
    }
    
    $refreshToken = $input['refresh_token'];
    
    // 刷新 Token
    $tokenPair = JWTManager::refreshAccessToken($refreshToken);
    
    if (!$tokenPair) {
        Response::unauthorized('Invalid or expired refresh token');
    }
    
    // 記錄成功的 token 刷新
    error_log("Token refreshed successfully");
    
    Response::success([
        'access_token' => $tokenPair['access_token'],
        'refresh_token' => $tokenPair['refresh_token'],
        'token_type' => $tokenPair['token_type'],
        'expires_in' => $tokenPair['expires_in'],
        'refresh_expires_in' => $tokenPair['refresh_expires_in']
    ], 'Token refreshed successfully');
    
} catch (Exception $e) {
    error_log("Token refresh error: " . $e->getMessage());
    Response::serverError('Token refresh failed');
}
?>

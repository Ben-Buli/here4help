<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * GET /api/admin/users/{user_id}/intro-referral-info
 * 管理員獲取用戶被推薦資訊 API
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/Response.php';
require_once __DIR__ . '/../../../utils/JWTManager.php';
require_once __DIR__ . '/../../../auth_helper.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    // $adminId = $tokenData['admin_id'] ?? null;
    // if (!$adminId) {
    //     Response::error('Admin access required', 403);
    // }
    
    // 從 URL 路徑獲取 user_id
    $pathParts = explode('/', trim($_SERVER['REQUEST_URI'], '/'));
    $userIdIndex = array_search('users', $pathParts) + 1;
    $userId = isset($pathParts[$userIdIndex]) ? (int)$pathParts[$userIdIndex] : null;
    
    if (!$userId) {
        Response::error('User ID is required', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶是否存在並獲取 intro_referral_code
    $userStmt = $db->prepare("
        SELECT id, name, email, permission, status, created_at, intro_referral_code
        FROM users 
        WHERE id = ?
    ");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    $responseData = null;
    
    // 如果用戶有 intro_referral_code，查找推薦人資訊
    if (!empty($user['intro_referral_code'])) {
        $referrerStmt = $db->prepare("
            SELECT id, name, email, status, permission, referral_code
            FROM users 
            WHERE referral_code = ?
        ");
        $referrerStmt->execute([$user['intro_referral_code']]);
        $referrer = $referrerStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($referrer) {
            // 查找推薦事件記錄
            // 查找點數交易記錄（推薦獎勵）
            $pointTransactionStmt = $db->prepare("
                SELECT id, user_id, transaction_type, amount, description, 
                       related_task_id, created_at
                FROM point_transactions
                WHERE user_id = ? AND transaction_type = 'referral_bonus'
                ORDER BY created_at DESC
                LIMIT 1
            ");
            $pointTransactionStmt->execute([$userId]);
            $pointTransaction = $pointTransactionStmt->fetch(PDO::FETCH_ASSOC);
            
            $responseData = [
                'intro_referral_code' => $user['intro_referral_code'],
                'referrer' => [
                    'id' => (int)$referrer['id'],
                    'name' => $referrer['name'],
                    'email' => $referrer['email'],
                    'status' => $referrer['status'],
                    'permission' => (int)$referrer['permission'],
                    'referral_code' => $referrer['referral_code']
                ],
                'referral_event' => $pointTransaction ? [
                    'id' => (int)$pointTransaction['id'],
                    'status' => 'completed',
                    'reward_points' => (int)$pointTransaction['amount'],
                    'created_at' => $pointTransaction['created_at'],
                    'completed_at' => $pointTransaction['created_at'],
                    'notes' => $pointTransaction['description']
                ] : [
                    'status' => 'pending',
                    'reward_points' => 500,
                    'created_at' => null,
                    'completed_at' => null,
                    'notes' => '等待管理員審核通過後發放獎勵'
                ]
            ];
        } else {
            // 推薦碼存在但找不到推薦人（可能是無效的推薦碼）
            $responseData = [
                'intro_referral_code' => $user['intro_referral_code'],
                'referrer' => null,
                'referral_event' => null,
                'error' => 'Referrer not found - invalid referral code'
            ];
        }
    }
    
    Response::success($responseData, 'User intro referral information retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin User Intro Referral Info API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * POST /api/admin/users/{user_id}/review
 * 管理員審核用戶驗證資料 API
 */

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../utils/ReferralCodeGenerator.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::error('Method not allowed', 405);
}

try {
    // 驗證JWT Token（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    // 從 URL 路徑獲取 user_id
    $pathParts = explode('/', trim($_SERVER['REQUEST_URI'], '/'));
    $userIdIndex = array_search('users', $pathParts) + 1;
    $userId = isset($pathParts[$userIdIndex]) ? (int)$pathParts[$userIdIndex] : null;
    
    if (!$userId) {
        Response::error('User ID is required', 400);
    }
    
    // 獲取請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error('Invalid JSON input', 400);
    }
    
    $decision = $input['decision'] ?? '';
    $notes = trim($input['notes'] ?? '');
    $newPermission = isset($input['new_permission']) ? (int)$input['new_permission'] : null;
    
    // 驗證必要欄位
    if (!in_array($decision, ['approve', 'reject'])) {
        Response::error('Invalid decision. Must be "approve" or "reject"', 400);
    }
    
    if ($newPermission === null) {
        Response::error('New permission level is required', 400);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶是否存在
    $userStmt = $db->prepare("
        SELECT id, name, email, permission, status 
        FROM users 
        WHERE id = ?
    ");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 檢查用戶當前是否為未驗證狀態
    if ((int)$user['permission'] != 0) {
        Response::error('User is not in unverified status (permission must be 0)', 400);
    }
    
    // 開始資料庫交易
    $db->beginTransaction();
    
    try {
        $referralCode = null;
        $referralReward = null;
        
        // 如果是批准，處理推薦碼生成和推薦獎勵
        if ($decision === 'approve') {
            // 為用戶生成推薦碼
            $referralCode = ReferralCodeGenerator::generateAndUpdate(Database::getInstance(), $userId);
            
            // 處理推薦獎勵：基於 intro_referral_code 查找推薦人
            $userStmt = $db->prepare("SELECT intro_referral_code FROM users WHERE id = ?");
            $userStmt->execute([$userId]);
            $user = $userStmt->fetch(PDO::FETCH_ASSOC);
            
            if ($user && !empty($user['intro_referral_code'])) {
                // 查找推薦人（Flutter app 已確保只有認證過的推薦人推薦碼才會寫入）
                $referrerStmt = $db->prepare("SELECT id, name FROM users WHERE referral_code = ?");
                $referrerStmt->execute([$user['intro_referral_code']]);
                $referrer = $referrerStmt->fetch(PDO::FETCH_ASSOC);
                
                    // 給被推薦人（新用戶）加500點數
                    $addPointsStmt = $db->prepare("
                        UPDATE users 
                        SET points = points + 500 
                        WHERE id = ?
                    ");
                    $addPointsStmt->execute([$userId]);
                    
                    // 記錄被推薦人的點數交易
                    $pointTransactionStmt = $db->prepare("
                        INSERT INTO point_transactions (
                            user_id, transaction_type, amount, description, 
                            related_task_id, created_at
                        ) VALUES (?, 'referral_bonus', 500, ?, ?, NOW())
                    ");
                    $pointTransactionStmt->execute([
                        $userId,
                        "Reward points for using referral code - New user ID: {$userId}",
                        null // related_task_id 為 null，因為這是推薦獎勵
                    ]);
                    
                    // 記錄管理員操作到 admin_activity_logs
                    $adminLogStmt = $db->prepare("
                        INSERT INTO admin_activity_logs (
                            admin_id, action, table_name, record_id, 
                            old_data, new_data, ip_address, user_agent, created_at
                        ) VALUES (?, 'referral_bonus', 'users', ?, ?, ?, ?, ?, NOW())
                    ");
                    $adminLogStmt->execute([
                        $adminId,
                        $userId,
                        null, // old_data
                        json_encode([
                            'action' => 'referral_bonus',
                            'referee_id' => $userId,
                            'referrer_id' => $referrer['id'],
                            'intro_referral_code' => $user['intro_referral_code'],
                            'reward_points' => 500
                        ]),
                        $_SERVER['REMOTE_ADDR'] ?? 'unknown',
                        $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
                    ]);
                    
                    $referralReward = [
                        'referee_id' => (int)$userId,
                        'referrer_id' => (int)$referrer['id'],
                        'referrer_name' => $referrer['name'],
                        'reward_points' => 500,
                        'intro_referral_code' => $user['intro_referral_code']
                    ];
                    
                    error_log("Reward points for using referral code - New user ID: {$userId}, Reward 500 points");
            }
        }
        
        // 更新用戶權限（只有批准時才更新為1）
            // 駁回時保持原權限
        if ($decision === 'approve') {
            $updateUserStmt = $db->prepare("
                UPDATE users 
                SET permission = 1, updated_at = NOW() 
                WHERE id = ?
            ");
            $updateUserStmt->execute([$userId]);

        } 
        
        // 更新學生證驗證記錄（如果存在）
        $verificationStatus = $decision === 'approve' ? 'approved' : 'rejected';
        $updateVerificationStmt = $db->prepare("
            UPDATE student_verifications 
            SET 
                verification_status = ?,
                verification_notes = ?,
                admin_id = ?,
                updated_at = NOW()
            WHERE user_id = ? 
            ORDER BY updated_at DESC 
            LIMIT 1
        ");
        $updateVerificationStmt->execute([
            $verificationStatus,
            $notes,
            $adminId,
            $userId
        ]);
        
        // 記錄管理員操作日誌
        $logStmt = $db->prepare("
            INSERT INTO user_activity_logs (
                user_id,
                actor_type,
                actor_id,
                action,
                details,
                created_at
            ) VALUES (?, 'admin', ?, 'user_verification_review', ?, NOW())
        ");
        
        $logDetails = json_encode([
            'decision' => $decision,
            'old_permission' => (int)$user['permission'],
            'new_permission' => $newPermission,
            'notes' => $notes,
            'admin_id' => $adminId,
            'referral_code_generated' => $referralCode,
            'referral_reward' => $referralReward
        ]);
        
        $logStmt->execute([$userId, $adminId, $logDetails]);
        
        // 提交交易
        $db->commit();
        
        $message = $decision === 'approve' 
            ? 'User verification approved successfully' 
            : 'User verification rejected successfully';
            
        $responseData = [
            'user_id' => $userId,
            'decision' => $decision,
            'old_permission' => (int)$user['permission'],
            'new_permission' => $decision === 'approve' ? 1 : $newPermission,
            'notes' => $notes,
            'reviewed_by' => $adminId,
            'reviewed_at' => date('Y-m-d H:i:s')
        ];
        
        // 如果生成了推薦碼，加入回應
        if ($referralCode) {
            $responseData['referral_code_generated'] = $referralCode;
        }
        
        // 如果有推薦獎勵，加入回應
        if ($referralReward) {
            $responseData['referral_reward'] = $referralReward;
            $message .= " - Referral reward of {$referralReward['reward_points']} points awarded to {$referralReward['referrer_name']}";
        }
            
        Response::success($responseData, $message);
        
    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("Admin User Review API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

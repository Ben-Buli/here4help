<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

/**
 * GET /api/admin/users/{user_id}/verification
 * 管理員獲取用戶驗證資料 API
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
    
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶是否存在
    $userStmt = $db->prepare("
        SELECT id, name, email, permission, status, created_at 
        FROM users 
        WHERE id = ?
    ");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 獲取用戶最新的學生證驗證記錄
    $verificationStmt = $db->prepare("
        SELECT 
            id,
            user_id,
            school_name,
            student_name,
            student_id,
            student_id_image_path,
            verification_status,
            verification_notes,
            admin_id,
            created_at,
            updated_at
        FROM student_verifications 
        WHERE user_id = ? 
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    
    $verificationStmt->execute([$userId]);
    $verification = $verificationStmt->fetch(PDO::FETCH_ASSOC);
    
    $previousStmt = $db->prepare("
        SELECT verification_status 
        FROM student_verifications 
        WHERE user_id = ? 
        ORDER BY created_at DESC 
        LIMIT 1 OFFSET 1
    ");
    $previousStmt->execute([$userId]);
    $previousVerification = $previousStmt->fetch(PDO::FETCH_ASSOC);

    $countStmt = $db->prepare("
        SELECT COUNT(*) AS total 
        FROM student_verifications 
        WHERE user_id = ?
    ");
    $countStmt->execute([$userId]);
    $submissionCount = (int)($countStmt->fetch(PDO::FETCH_ASSOC)['total'] ?? 0);

    $responseData = [
        'user' => $user,
        'verification' => null
    ];
    
    if ($verification) {
        // 構建完整的圖片 URL
        $imageUrl = null;
        $normalizedImagePath = null;
        if ($verification['student_id_image_path']) {
            $normalizedImagePath = ltrim($verification['student_id_image_path'], '/');
            if (strpos($normalizedImagePath, 'uploads/') === 0) {
                $normalizedImagePath = substr($normalizedImagePath, strlen('uploads/'));
            }
            // 直接使用 /uploads 路徑，讓 Vite 代理處理
            $imageUrl = '/uploads/' . $normalizedImagePath;
        }

        $requiresReReview = $previousVerification
            && $previousVerification['verification_status'] === 'rejected'
            && $verification['verification_status'] === 'pending';
        
        $responseData['verification'] = [
            'id' => (int)$verification['id'],
            'school_name' => $verification['school_name'],
            'student_name' => $verification['student_name'],
            'student_id' => $verification['student_id'],
            'student_id_image_path' => $normalizedImagePath,
            'student_id_image' => $imageUrl,
            'verification_status' => $verification['verification_status'],
            'verification_notes' => $verification['verification_notes'],
            'admin_id' => $verification['admin_id'] ? (int)$verification['admin_id'] : null,
            'created_at' => $verification['created_at'],
            'updated_at' => $verification['updated_at'],
            'previous_status' => $previousVerification['verification_status'] ?? null,
            'submission_count' => $submissionCount,
            'requires_re_review' => $requiresReReview
        ];
        error_log("User verification data retrieved successfully: " . json_encode($responseData));
    }
    
    Response::success($responseData, 'User verification data retrieved successfully');
    
} catch (Exception $e) {
    error_log("Admin User Verification API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

<?php
/**
 * 獲取用戶學生證審核狀態 API
 * 
 * 功能：
 * - 檢查當前用戶的學生證審核狀態
 * - 如果狀態為 'rejected'，返回最新一筆被拒絕的資料
 * - 用於首頁顯示重新上傳按鈕的條件判斷
 * 
 * 路徑：GET /api/auth/get-student-verification-status.php
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

header('Content-Type: application/json');
Response::setCorsHeaders();

// 處理 OPTIONS 請求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 僅允許 GET 請求
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    // JWT 認證 - 支援 Header 和 URL 參數
    $token = null;
    
    // 嘗試從 Authorization header 獲取
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            $token = $matches[1];
        }
    }
    
    // 如果沒有從 header 獲取到，嘗試從 URL 參數獲取
    if (!$token && isset($_GET['token'])) {
        $token = $_GET['token'];
    }
    
    if (!$token) {
        Response::error('Token is required', 401);
    }
    
    $jwtManager = new JWTManager();
    $payload = $jwtManager->validateToken($token);
    
    if (!$payload) {
        Response::error('Invalid or expired token', 401);
    }

    $userId = $payload['user_id'];
    error_log('Get Student Verification Status API: user_id: ' . $userId);
    
    $db = Database::getInstance()->getConnection();
    
    // 檢查用戶是否存在
    $userStmt = $db->prepare("SELECT id, email FROM users WHERE id = ?");
    $userStmt->execute([$userId]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$user) {
        Response::error('User not found', 404);
    }
    
    // 獲取用戶最新的學生證審核記錄
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
            created_at,
            updated_at
        FROM student_verifications 
        WHERE user_id = ? 
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    
    $verificationStmt->execute([$userId]);
    $verification = $verificationStmt->fetch(PDO::FETCH_ASSOC);
    
    // 如果沒有找到學生證記錄
    if (!$verification) {
        Response::success([
            'has_verification' => false,
            'verification_status' => null,
            'message' => 'No student verification record found'
        ]);
        return;
    }
    
    // 格式化回傳資料
    $responseData = [
        'has_verification' => true,
        'id' => (int)$verification['id'],
        'user_id' => (int)$verification['user_id'],
        'school_name' => $verification['school_name'],
        'student_name' => $verification['student_name'],
        'student_id' => $verification['student_id'],
        'student_id_image_path' => $verification['student_id_image_path'],
        'verification_status' => $verification['verification_status'],
        'verification_notes' => $verification['verification_notes'],
        'created_at' => $verification['created_at'],
        'updated_at' => $verification['updated_at']
    ];
    
    Response::success($responseData, 'Student verification status retrieved successfully');

} catch (PDOException $e) {
    error_log("Database error in get student verification status: " . $e->getMessage());
    Response::error('Database error occurred', 500);
} catch (Exception $e) {
    error_log("Error in get student verification status: " . $e->getMessage());
    Response::error('An error occurred while retrieving verification status: ' . $e->getMessage(), 500);
}
?>

<?php
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::error('Method not allowed', 405);
}

try {
    $db = Database::getInstance();
    
    // 獲取所有學生證驗證記錄和對應的用戶資訊
    $sql = "
        SELECT 
            sv.*,
            u.name as user_name,
            u.email
        FROM student_verifications sv 
        JOIN users u ON sv.user_id = u.id 
        ORDER BY sv.created_at DESC
    ";
    
    $verifications = $db->fetchAll($sql);
    $images = [];
    
    foreach ($verifications as $verification) {
        $imagePath = $verification['student_id_image_path'];
        $fullPath = __DIR__ . '/../../../' . $imagePath;
        
        $fileSize = 0;
        if (file_exists($fullPath)) {
            $fileSize = filesize($fullPath);
        }
        
        $images[] = [
            'user_name' => $verification['user_name'],
            'email' => $verification['email'],
            'school_name' => $verification['school_name'],
            'student_name' => $verification['student_name'],
            'student_id' => $verification['student_id'],
            'image_path' => $imagePath,
            'file_size' => $fileSize,
            'verification_status' => $verification['verification_status'],
            'created_at' => $verification['created_at']
        ];
    }
    
    Response::success($images, 'Images retrieved successfully');
    
} catch (Exception $e) {
    Response::serverError('Failed to retrieve images: ' . $e->getMessage());
}
?> 
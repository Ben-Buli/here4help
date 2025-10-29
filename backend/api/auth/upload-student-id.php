<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/TokenValidator.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Response.php';

// 設置 CORS 標頭
Response::setCorsHeaders();

// 只允許 POST 請求
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    Response::methodNotAllowed('Method not allowed');
}

try {
    $db = Database::getInstance();
    
    // 檢查是否有上傳的圖片
    if (!isset($_FILES['student_id_image']) || $_FILES['student_id_image']['error'] !== UPLOAD_ERR_OK) {
        Response::badRequest('No image uploaded or upload error');
    }
    
    // 獲取表單數據
    $userId = $_POST['user_id'] ?? '';
    $email = $_POST['email'] ?? '';
    $schoolName = $_POST['school_name'] ?? '';
    $studentName = $_POST['student_name'] ?? '';
    $studentId = $_POST['student_id'] ?? '';
    
    // 驗證必填欄位
    if (empty($schoolName) || empty($studentName) || empty($studentId)) {
        Response::badRequest('Missing required fields: school_name, student_name, student_id');
    }
    
    // 🔧 修復：優先使用 user_id，如果沒有則使用 email 查找
    if (!empty($userId)) {
        // 直接使用 user_id
        $user = $db->fetch("SELECT id, email FROM users WHERE id = ?", [$userId]);
        if (!$user) {
            Response::notFound('User not found with provided user_id');
        }
        $userId = $user['id'];
        $userEmail = $user['email'];
        error_log("[upload-student-id] 使用 user_id: $userId, email: $userEmail");
    } elseif (!empty($email)) {
        // 使用 email 查找（向後兼容）
        $user = $db->fetch("SELECT id FROM users WHERE email = ?", [$email]);
        if (!$user) {
            Response::notFound('User not found with provided email');
        }
        $userId = $user['id'];
        error_log("[upload-student-id] 使用 email 查找到 user_id: $userId");
    } else {
        Response::badRequest('Either user_id or email is required');
    }
    
    // 處理圖片上傳
    $uploadDir = '../../uploads/student_id_images/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }
    
    $fileExtension = pathinfo($_FILES['student_id_image']['name'], PATHINFO_EXTENSION);
    $fileName = 'student_id_' . $userId . '_' . time() . '.' . $fileExtension;
    $filePath = $uploadDir . $fileName;
    
    // 移動上傳的檔案
    if (!move_uploaded_file($_FILES['student_id_image']['tmp_name'], $filePath)) {
        Response::serverError('Failed to save image');
    }
    
    // 取得上一筆驗證資料（用於判斷是否重新審核）
    $previousVerification = $db->fetch("
        SELECT id, verification_status 
        FROM student_verifications 
        WHERE user_id = ? 
        ORDER BY created_at DESC 
        LIMIT 1
    ", [$userId]);
    
    $requiresReReview = $previousVerification && $previousVerification['verification_status'] === 'rejected';

    // 開始事務
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 建立新的驗證記錄（總是新增，不覆蓋舊資料）
        $db->query("
            INSERT INTO student_verifications (
                user_id, 
                school_name, 
                student_name, 
                student_id, 
                student_id_image_path, 
                verification_status, 
                created_at, 
                updated_at
            ) VALUES (?, ?, ?, ?, ?, 'pending', NOW(), NOW())
        ", [$userId, $schoolName, $studentName, $studentId, 'student_id_images/' . $fileName]);
        
        $submissionCountRow = $db->fetch("
            SELECT COUNT(*) AS total 
            FROM student_verifications 
            WHERE user_id = ?
        ", [$userId]);
        $submissionCount = (int)($submissionCountRow['total'] ?? 1);
        
        // 提交事務
        $connection->commit();
        
        Response::success(
            [
                'user_id' => $userId,
                'image_path' => 'student_id_images/' . $fileName,
                'requires_re_review' => $requiresReReview,
                'submission_count' => $submissionCount
            ],
            'Student ID uploaded successfully'
        );
        
    } catch (Exception $e) {
        // 回滾事務
        $connection->rollback();
        
        // 刪除已上傳的圖片
        if (file_exists($filePath)) {
            unlink($filePath);
        }
        
        Response::serverError('Database error: ' . $e->getMessage());
    }
    
} catch (Exception $e) {
    Response::serverError('Server error: ' . $e->getMessage());
}
?> 

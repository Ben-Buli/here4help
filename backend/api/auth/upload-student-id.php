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
    Response::error('Method not allowed', 405);
    exit;
}

try {
    $db = Database::getInstance();
    
    // 檢查是否有上傳的圖片
    if (!isset($_FILES['student_id_image']) || $_FILES['student_id_image']['error'] !== UPLOAD_ERR_OK) {
        Response::error('No image uploaded or upload error');
        exit;
    }
    
    // 獲取表單數據
    $userId = $_POST['user_id'] ?? '';
    $email = $_POST['email'] ?? '';
    $schoolName = $_POST['school_name'] ?? '';
    $studentName = $_POST['student_name'] ?? '';
    $studentId = $_POST['student_id'] ?? '';
    
    // 驗證必填欄位
    if (empty($schoolName) || empty($studentName) || empty($studentId)) {
        Response::error('Missing required fields: school_name, student_name, student_id');
        exit;
    }
    
    // 🔧 修復：優先使用 user_id，如果沒有則使用 email 查找
    if (!empty($userId)) {
        // 直接使用 user_id
        $user = $db->fetch("SELECT id, email FROM users WHERE id = ?", [$userId]);
        if (!$user) {
            Response::error('User not found with provided user_id');
            exit;
        }
        $userId = $user['id'];
        $userEmail = $user['email'];
        error_log("[upload-student-id] 使用 user_id: $userId, email: $userEmail");
    } elseif (!empty($email)) {
        // 使用 email 查找（向後兼容）
        $user = $db->fetch("SELECT id FROM users WHERE email = ?", [$email]);
        if (!$user) {
            Response::error('User not found with provided email');
            exit;
        }
        $userId = $user['id'];
        error_log("[upload-student-id] 使用 email 查找到 user_id: $userId");
    } else {
        Response::error('Either user_id or email is required');
        exit;
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
        Response::error('Failed to save image');
        exit;
    }
    
    // 開始事務
    $connection = $db->getConnection();
    $connection->beginTransaction();
    
    try {
        // 檢查是否已有學生證記錄
        $existingVerification = $db->fetch("SELECT id FROM student_verifications WHERE user_id = ?", [$userId]);
        
        if ($existingVerification) {
            // 更新現有記錄
            $db->query("
                UPDATE student_verifications 
                SET school_name = ?, student_name = ?, student_id = ?, student_id_image_path = ?, updated_at = NOW()
                WHERE user_id = ?
            ", [$schoolName, $studentName, $studentId, $fileName, $userId]);
        } else {
            // 創建新記錄
            $db->query("
                INSERT INTO student_verifications (user_id, school_name, student_name, student_id, student_id_image_path, verification_status, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, 'pending', NOW(), NOW())
            ", [$userId, $schoolName, $studentName, $studentId, $fileName]);
        }
        
        // 🔧 暫時移除用戶狀態更新，避免 ENUM 值錯誤
        // 學生證驗證狀態已在 student_verifications 表中記錄
        // $db->query("UPDATE users SET status = 'pending' WHERE id = ?", [$userId]);
        
        // 提交事務
        $connection->commit();
        
        Response::success('Student ID uploaded successfully', [
            'user_id' => $userId,
            'image_path' => $fileName
        ]);
        
    } catch (Exception $e) {
        // 回滾事務
        $connection->rollback();
        
        // 刪除已上傳的圖片
        if (file_exists($filePath)) {
            unlink($filePath);
        }
        
        Response::error('Database error: ' . $e->getMessage());
    }
    
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage());
}
?> 
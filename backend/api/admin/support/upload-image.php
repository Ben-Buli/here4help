<?php
require_once __DIR__ . '/bootstrap.php';
// 載入 PHP 8.4 相容性配置

/**
 * 管理員客服聊天室圖片上傳 API
 * POST /api/admin/support/upload-image
 */

require_once __DIR__ . '/../../config/database.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    // 驗證請求方法
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error('Method not allowed', 405);
    }
    
    // JWT 驗證（需要管理員權限）
    $tokenData = JWTManager::validateRequest();
    if (!$tokenData['valid']) {
        Response::error($tokenData['message'], 401);
    }
    
    // 檢查管理員權限
    $adminId = $tokenData['admin_id'] ?? null;
    if (!$adminId) {
        Response::error('Admin access required', 403);
    }
    
    $db = Database::getInstance()->getConnection();
    
    // 獲取聊天室 ID
    $roomId = isset($_POST['room_id']) ? (int)$_POST['room_id'] : 0;
    if ($roomId <= 0) {
        Response::error('Room ID is required', 400);
    }
    
    // 檢查管理員是否有權限訪問此聊天室
    $room = $db->prepare("
        SELECT id, admin_id 
        FROM support_chat_rooms 
        WHERE id = ? AND admin_id = ?
    ");
    $room->execute([$roomId, $adminId]);
    $roomData = $room->fetch(PDO::FETCH_ASSOC);
    
    if (!$roomData) {
        Response::error('Chat room not found or access denied', 404);
    }
    
    // 檢查上傳檔案
    if (!isset($_FILES['image']) || empty($_FILES['image']['tmp_name'])) {
        Response::error('No image file uploaded', 400);
    }
    
    $file = $_FILES['image'];
    
    // 驗證檔案
    if ($file['error'] !== UPLOAD_ERR_OK) {
        Response::error('Upload error: ' . $file['error'], 400);
    }
    
    // 檢查檔案大小 (5MB 限制)
    $maxSize = 5 * 1024 * 1024; // 5MB
    if ($file['size'] > $maxSize) {
        Response::error('File too large (max 5MB)', 413);
    }
    
    // 檢查檔案類型
    $allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp'];
    $allowedExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    
    $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($fileExtension, $allowedExtensions)) {
        Response::error('Invalid file type. Allowed: ' . implode(', ', $allowedExtensions), 422);
    }
    
    // 創建上傳目錄
    $uploadDir = dirname(__DIR__, 2) . '/uploads/support_chat';
    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0755, true)) {
            Response::error('Failed to create upload directory', 500);
        }
    }
    
    // 生成唯一檔案名
    $fileName = uniqid('admin_support_') . '.' . $fileExtension;
    $filePath = $uploadDir . '/' . $fileName;
    
    // 移動上傳檔案
    if (!move_uploaded_file($file['tmp_name'], $filePath)) {
        Response::error('Failed to move uploaded file', 500);
    }
    
    // 生成公開路徑
    $publicPath = 'uploads/support_chat/' . $fileName;
    
    Response::success([
        'filename' => $file['name'],
        'saved_as' => $fileName,
        'path' => $publicPath,
        'url' => $publicPath,
        'size' => $file['size'],
        'mime_type' => $file['type']
    ], 'Image uploaded successfully');
    
} catch (Exception $e) {
    error_log("Admin Support Image Upload API Error: " . $e->getMessage());
    Response::error('Internal server error: ' . $e->getMessage(), 500);
}
?>

<?php
require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/UserActiveLogger.php';
require_once __DIR__ . '/../../utils/ErrorCodes.php';
require_once __DIR__ . '/../../auth_helper.php';

// CORS headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'OK']);
    exit;
}

try {
    // 驗證 JWT token - 支持多源讀取
    $jwtManager = new JWTManager();
    $authHeader = getAuthorizationHeader();
    $token = null;
    
    if ($authHeader && strpos($authHeader, 'Bearer ') === 0) {
        $token = trim(substr($authHeader, 7));
    }
    
    if (!$token) {
        $token = $_GET['token'] ?? $_POST['token'] ?? '';
    }
    
    if (!$token) {
        Response::unauthorized('Token is required');
    }
    
    $payload = $jwtManager->validateToken($token);
    if (!$payload) {
        Response::unauthorized('Invalid or expired token');
    }
    
    $userId = $payload['user_id'];
    
    // 建立資料庫連線
    $dbHost = EnvLoader::get('DB_HOST');
    if ($dbHost === 'localhost') { $dbHost = '127.0.0.1'; }
    $dbPort = EnvLoader::get('DB_PORT') ?: '3306';
    $dsn = "mysql:host={$dbHost};port={$dbPort};dbname=" . EnvLoader::get('DB_NAME') . ";charset=utf8mb4";

    $pdo = new PDO(
        $dsn,
        EnvLoader::get('DB_USERNAME'),
        EnvLoader::get('DB_PASSWORD'),
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // 上傳頭像
        if (!isset($_FILES['avatar']) || $_FILES['avatar']['error'] !== UPLOAD_ERR_OK) {
            Response::badRequest('No avatar file uploaded or upload error');
        }
        
        $file = $_FILES['avatar'];
        
        // 檢查檔案大小 (最大 5MB)
        $maxSize = 5 * 1024 * 1024; // 5MB
        if ($file['size'] > $maxSize) {
            Response::badRequest('File size exceeds 5MB limit');
        }
        
        // 檢查檔案類型
        $allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);
        
        if (!in_array($mimeType, $allowedTypes)) {
            Response::badRequest('Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed');
        }
        
        // 生成唯一檔案名
        $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
        $fileName = 'avatar_' . $userId . '_' . time() . '.' . $extension;
        
        // 確保上傳目錄存在
        $uploadDir = __DIR__ . '/../../uploads/avatars/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0755, true);
        }
        
        $filePath = $uploadDir . $fileName;
        
        // 移動上傳的檔案
        if (!move_uploaded_file($file['tmp_name'], $filePath)) {
            Response::serverError('Failed to save uploaded file');
        }
        
        // 圖片壓縮處理
        $compressedPath = $filePath;
        try {
            $compressedPath = compressImage($filePath, $uploadDir . 'compressed_' . $fileName);
            if ($compressedPath && $compressedPath !== $filePath) {
                unlink($filePath); // 刪除原始檔案
                $fileName = 'compressed_' . $fileName;
            }
        } catch (Exception $e) {
            // 壓縮失敗，使用原始檔案
            error_log("Avatar compression failed: " . $e->getMessage());
        }
        
        $avatarUrl = '/backend/uploads/avatars/' . $fileName;
        
        $pdo->beginTransaction();
        
        try {
            // 獲取舊頭像 URL 以便刪除
            $stmt = $pdo->prepare("SELECT avatar_url FROM users WHERE id = ?");
            $stmt->execute([$userId]);
            $oldAvatarUrl = $stmt->fetchColumn();
            
            // 更新用戶頭像
            $stmt = $pdo->prepare("UPDATE users SET avatar_url = ?, updated_at = NOW() WHERE id = ?");
            $stmt->execute([$avatarUrl, $userId]);
            
            // 記錄操作日誌
            $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
            $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
            $rid = $_SERVER['HTTP_X_REQUEST_ID'] ?? null;
            $tid = $_SERVER['HTTP_X_TRACE_ID'] ?? null;
            
            // new version
            UserActiveLogger::logAction(
                $pdo,
                $userId,
                'avatar_upload',
                'avatar_url',
                $oldAvatarUrl,
                $avatarUrl,
                'User uploaded new avatar',
                'user',
                $userId,
                json_encode([
                    'file_name'   => $fileName,
                    'file_size'   => $file['size'],
                    'mime_type'   => $mimeType,
                    'uploaded_at' => date('Y-m-d H:i:s'),
                ])
            );

            
            $pdo->commit();
            
            // 刪除舊頭像檔案（如果存在且不是預設頭像）
            if ($oldAvatarUrl && $oldAvatarUrl !== $avatarUrl && strpos($oldAvatarUrl, '/backend/uploads/avatars/') === 0) {
                $oldFilePath = __DIR__ . '/../..' . $oldAvatarUrl;
                if (file_exists($oldFilePath)) {
                    unlink($oldFilePath);
                }
            }
            
            Response::success([
                'avatar_url' => $avatarUrl,
                'file_name' => $fileName,
                'uploaded_at' => date('Y-m-d H:i:s')
            ], 'Avatar uploaded successfully');
            
        } catch (Exception $e) {
            $pdo->rollBack();
            // 刪除已上傳的檔案
            if (file_exists($compressedPath)) {
                unlink($compressedPath);
            }
            throw $e;
        }
        
    } elseif ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        // 刪除頭像
        $pdo->beginTransaction();
        
        try {
            // 獲取當前頭像 URL
            $stmt = $pdo->prepare("SELECT avatar_url FROM users WHERE id = ?");
            $stmt->execute([$userId]);
            $avatarUrl = $stmt->fetchColumn();
            
            if (!$avatarUrl) {
                Response::badRequest('No avatar to delete');
            }
            
            // 更新用戶頭像為空
            $stmt = $pdo->prepare("UPDATE users SET avatar_url = NULL, updated_at = NOW() WHERE id = ?");
            $stmt->execute([$userId]);
            
            // 記錄操作日誌
            $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
            $ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
            $rid = $_SERVER['HTTP_X_REQUEST_ID'] ?? null;
            $tid = $_SERVER['HTTP_X_TRACE_ID'] ?? null;
            
            UserActiveLogger::logAction(
                $pdo,
                $userId,
                'avatar_delete',
                'avatar_url',
                $avatarUrl,
                null,
                'User deleted avatar',
                'user',
                $userId,
                null
            );
            
            $pdo->commit();
            
            // 刪除檔案（如果是上傳的檔案）
            if (strpos($avatarUrl, '/backend/uploads/avatars/') === 0) {
                $filePath = __DIR__ . '/../..' . $avatarUrl;
                if (file_exists($filePath)) {
                    unlink($filePath);
                }
            }
            
            Response::success([
                'deleted_avatar_url' => $avatarUrl,
                'deleted_at' => date('Y-m-d H:i:s')
            ], 'Avatar deleted successfully');
            
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
        
    } else {
        Response::error(ErrorCodes::METHOD_NOT_ALLOWED);
    }
    
} catch (Exception $e) {
    Response::badRequest($e->getMessage());
}

/**
 * 壓縮圖片
 */
function compressImage($source, $destination, $quality = 80) {
    $info = getimagesize($source);
    
    if ($info === false) {
        throw new Exception('Invalid image file');
    }
    
    $mime = $info['mime'];
    
    switch ($mime) {
        case 'image/jpeg':
            $image = imagecreatefromjpeg($source);
            break;
        case 'image/png':
            $image = imagecreatefrompng($source);
            break;
        case 'image/gif':
            $image = imagecreatefromgif($source);
            break;
        case 'image/webp':
            $image = imagecreatefromwebp($source);
            break;
        default:
            throw new Exception('Unsupported image type');
    }
    
    if ($image === false) {
        throw new Exception('Failed to create image resource');
    }
    
    // 計算新尺寸（最大 800x800）
    $maxWidth = 800;
    $maxHeight = 800;
    $width = imagesx($image);
    $height = imagesy($image);
    
    if ($width > $maxWidth || $height > $maxHeight) {
        $ratio = min($maxWidth / $width, $maxHeight / $height);
        $newWidth = (int)($width * $ratio);
        $newHeight = (int)($height * $ratio);
        
        $resized = imagecreatetruecolor($newWidth, $newHeight);
        
        // 保持透明度
        if ($mime === 'image/png' || $mime === 'image/gif') {
            imagealphablending($resized, false);
            imagesavealpha($resized, true);
            $transparent = imagecolorallocatealpha($resized, 255, 255, 255, 127);
            imagefill($resized, 0, 0, $transparent);
        }
        
        imagecopyresampled($resized, $image, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);
        imagedestroy($image);
        $image = $resized;
    }
    
    // 保存壓縮後的圖片
    $result = false;
    switch ($mime) {
        case 'image/jpeg':
            $result = imagejpeg($image, $destination, $quality);
            break;
        case 'image/png':
            $result = imagepng($image, $destination, (int)(9 - ($quality / 10)));
            break;
        case 'image/gif':
            $result = imagegif($image, $destination);
            break;
        case 'image/webp':
            $result = imagewebp($image, $destination, $quality);
            break;
    }
    
    imagedestroy($image);
    
    if (!$result) {
        throw new Exception('Failed to save compressed image');
    }
    
    return $destination;
}
?>

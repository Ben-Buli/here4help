<?php
/**
 * 媒體檔案上傳 API
 * 支援聊天室、申訴、頭像等不同情境的檔案上傳
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/MediaValidator.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Logger.php';

// 禁用自動日誌記錄
define('LOGGING_MIDDLEWARE_DISABLED', true);

header('Content-Type: application/json');

try {
    // 驗證請求方法
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error('METHOD_NOT_ALLOWED', '僅支援 POST 請求');
        exit;
    }
    
    // JWT 驗證
    $jwt = JWTManager::validateRequest();
    if (!$jwt['valid']) {
        Response::error('UNAUTHORIZED', $jwt['message']);
        exit;
    }
    
    $userId = $jwt['payload']['user_id'];
    
    // 檢查上傳檔案
    if (!isset($_FILES['file']) || empty($_FILES['file']['tmp_name'])) {
        Response::error('NO_FILE', '沒有上傳檔案');
        exit;
    }
    
    // 獲取上傳情境
    $context = $_POST['context'] ?? 'chat';
    $allowedContexts = ['chat', 'dispute', 'avatar', 'verification', 'document'];
    
    if (!in_array($context, $allowedContexts)) {
        Response::error('INVALID_CONTEXT', '無效的上傳情境');
        exit;
    }
    
    // 獲取相關 ID (如聊天室 ID、申訴 ID 等)
    $relatedId = $_POST['related_id'] ?? null;
    
    // 驗證檔案
    $validator = new MediaValidator();
    $validation = $validator->validateUpload($_FILES['file'], $context);
    
    if (!$validation['valid']) {
        Response::error('VALIDATION_FAILED', '檔案驗證失敗', [
            'errors' => $validation['errors']
        ]);
        exit;
    }
    
    // 生成檔案路徑
    $uploadResult = processUpload($_FILES['file'], $context, $userId, $relatedId, $validation);
    
    if (!$uploadResult['success']) {
        Response::error('UPLOAD_FAILED', $uploadResult['message']);
        exit;
    }
    
    // 記錄上傳日誌
    Logger::logBusiness('media_uploaded', $userId, [
        'context' => $context,
        'file_name' => $_FILES['file']['name'],
        'file_size' => $_FILES['file']['size'],
        'file_path' => $uploadResult['file_path'],
        'related_id' => $relatedId
    ]);
    
    Response::success('檔案上傳成功', [
        'file_id' => $uploadResult['file_id'],
        'file_url' => $uploadResult['file_url'],
        'file_name' => $uploadResult['file_name'],
        'file_size' => $uploadResult['file_size'],
        'mime_type' => $uploadResult['mime_type'],
        'compressed' => $uploadResult['compressed'] ?? false
    ]);
    
} catch (Exception $e) {
    Logger::logError('Media upload failed', [
        'user_id' => $userId ?? null,
        'context' => $context ?? null,
        'error' => $e->getMessage()
    ], $e);
    
    Response::error('INTERNAL_ERROR', '上傳處理失敗');
}

/**
 * 處理檔案上傳
 */
function processUpload($file, $context, $userId, $relatedId, $validation) {
    try {
        // 創建上傳目錄
        $uploadDir = createUploadDirectory($context);
        if (!$uploadDir) {
            return ['success' => false, 'message' => '無法創建上傳目錄'];
        }
        
        // 生成唯一檔案名
        $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $fileName = generateUniqueFileName($fileExtension);
        $filePath = $uploadDir . '/' . $fileName;
        
        // 移動上傳檔案
        if (!move_uploaded_file($file['tmp_name'], $filePath)) {
            return ['success' => false, 'message' => '檔案移動失敗'];
        }
        
            // 壓縮處理
    $compressed = false;
    if ($validation['should_compress']) {
        $compressedPath = $uploadDir . '/compressed_' . $fileName;
        $validator = new MediaValidator();
        
        if ($validator->compressImage($filePath, $compressedPath, $context)) {
            // 使用壓縮後的檔案
            unlink($filePath);
            rename($compressedPath, $filePath);
            $compressed = true;
        }
    }
    
    // 安全掃描
    require_once __DIR__ . '/../../utils/SecurityScanner.php';
    $scanner = new SecurityScanner();
    $scanResult = $scanner->scanFile($filePath, $context);
    
    // 如果發現威脅，阻止上傳
    if ($scanResult['status'] === 'infected') {
        // 清理檔案
        if (file_exists($filePath)) {
            unlink($filePath);
        }
        return [
            'success' => false, 
            'message' => '檔案包含惡意內容，上傳被阻止',
            'scan_result' => $scanResult
        ];
    }
        
        // 保存到資料庫
        $fileRecord = saveFileRecord($fileName, $filePath, $file, $context, $userId, $relatedId, $compressed, $scanResult);
        
        if (!$fileRecord) {
            // 清理檔案
            if (file_exists($filePath)) {
                unlink($filePath);
            }
            return ['success' => false, 'message' => '資料庫記錄失敗'];
        }
        
        return [
            'success' => true,
            'file_id' => $fileRecord['id'],
            'file_url' => generateFileUrl($fileName, $context),
            'file_name' => $file['name'],
            'file_size' => filesize($filePath),
            'file_path' => $filePath,
            'mime_type' => $file['type'],
            'compressed' => $compressed
        ];
        
    } catch (Exception $e) {
        return ['success' => false, 'message' => $e->getMessage()];
    }
}

/**
 * 創建上傳目錄
 */
function createUploadDirectory($context) {
    $baseDir = __DIR__ . '/../../uploads';
    $contextDir = $baseDir . '/' . $context;
    $dateDir = $contextDir . '/' . date('Y/m/d');
    
    if (!is_dir($dateDir)) {
        if (!mkdir($dateDir, 0755, true)) {
            return false;
        }
    }
    
    return $dateDir;
}

/**
 * 生成唯一檔案名
 */
function generateUniqueFileName($extension) {
    return uniqid('media_', true) . '_' . time() . '.' . $extension;
}

/**
 * 保存檔案記錄到資料庫
 */
function saveFileRecord($fileName, $filePath, $file, $context, $userId, $relatedId, $compressed, $scanResult = null) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            INSERT INTO media_files (
                user_id, context, related_id, original_name, 
                file_name, file_path, file_size, mime_type, 
                compressed, scan_status, scan_result, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ";
        
        $stmt = $db->prepare($sql);
        $success = $stmt->execute([
            $userId,
            $context,
            $relatedId,
            $file['name'],
            $fileName,
            $filePath,
            filesize($filePath),
            $file['type'],
            $compressed ? 1 : 0,
            $scanResult ? $scanResult['status'] : 'pending',
            $scanResult ? json_encode($scanResult) : null
        ]);
        
        if ($success) {
            return [
                'id' => $db->lastInsertId(),
                'file_name' => $fileName
            ];
        }
        
        return false;
        
    } catch (Exception $e) {
        Logger::logError('Failed to save file record', [
            'file_name' => $fileName,
            'error' => $e->getMessage()
        ], $e);
        return false;
    }
}

/**
 * 生成檔案 URL
 */
function generateFileUrl($fileName, $context) {
    $baseUrl = $_ENV['APP_URL'] ?? 'http://localhost:8888/here4help';
    return $baseUrl . "/backend/api/media/serve.php?file=" . urlencode($fileName) . "&context=" . urlencode($context);
}

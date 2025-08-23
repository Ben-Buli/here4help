<?php
/**
 * 媒體檔案服務 API
 * 安全地提供檔案下載和預覽
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Logger.php';

// 禁用自動日誌記錄
define('LOGGING_MIDDLEWARE_DISABLED', true);

try {
    // 獲取參數
    $fileName = $_GET['file'] ?? '';
    $context = $_GET['context'] ?? '';
    $download = isset($_GET['download']);
    
    if (empty($fileName) || empty($context)) {
        http_response_code(400);
        echo 'Missing parameters';
        exit;
    }
    
    // 驗證檔案名稱安全性
    if (!isValidFileName($fileName)) {
        http_response_code(400);
        echo 'Invalid file name';
        exit;
    }
    
    // 獲取檔案記錄
    $fileRecord = getFileRecord($fileName, $context);
    if (!$fileRecord) {
        http_response_code(404);
        echo 'File not found';
        exit;
    }
    
    // 權限檢查
    if (!checkFileAccess($fileRecord, $context)) {
        http_response_code(403);
        echo 'Access denied';
        exit;
    }
    
    // 檢查檔案是否存在
    $filePath = $fileRecord['file_path'];
    if (!file_exists($filePath)) {
        http_response_code(404);
        echo 'Physical file not found';
        exit;
    }
    
    // 記錄訪問日誌
    logFileAccess($fileRecord, $context);
    
    // 提供檔案
    serveFile($filePath, $fileRecord, $download);
    
} catch (Exception $e) {
    Logger::logError('Media serve failed', [
        'file_name' => $fileName ?? 'unknown',
        'context' => $context ?? 'unknown',
        'error' => $e->getMessage()
    ], $e);
    
    http_response_code(500);
    echo 'Internal server error';
}

/**
 * 驗證檔案名稱
 */
function isValidFileName($fileName) {
    // 檢查是否包含路徑遍歷
    if (strpos($fileName, '..') !== false || strpos($fileName, '/') !== false || strpos($fileName, '\\') !== false) {
        return false;
    }
    
    // 檢查檔案名稱格式
    if (!preg_match('/^media_[a-f0-9\.]+_\d+\.[a-zA-Z0-9]+$/', $fileName)) {
        return false;
    }
    
    return true;
}

/**
 * 獲取檔案記錄
 */
function getFileRecord($fileName, $context) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            SELECT id, user_id, context, related_id, original_name, 
                   file_name, file_path, file_size, mime_type, 
                   compressed, created_at
            FROM media_files 
            WHERE file_name = ? AND context = ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$fileName, $context]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
        
    } catch (Exception $e) {
        Logger::logError('Failed to get file record', [
            'file_name' => $fileName,
            'context' => $context,
            'error' => $e->getMessage()
        ], $e);
        return false;
    }
}

/**
 * 檢查檔案訪問權限
 */
function checkFileAccess($fileRecord, $context) {
    // 公開檔案 (頭像等)
    if (in_array($context, ['avatar'])) {
        return true;
    }
    
    // 需要登入的檔案
    $jwt = JWTManager::validateRequest();
    if (!$jwt['valid']) {
        return false;
    }
    
    $userId = $jwt['payload']['user_id'];
    
    // 檢查是否為檔案擁有者
    if ($fileRecord['user_id'] == $userId) {
        return true;
    }
    
    // 根據情境檢查特殊權限
    switch ($context) {
        case 'chat':
            return checkChatFileAccess($fileRecord['related_id'], $userId);
            
        case 'dispute':
            return checkDisputeFileAccess($fileRecord['related_id'], $userId);
            
        case 'verification':
            // 只有管理員和本人可以查看
            return isAdmin($userId) || $fileRecord['user_id'] == $userId;
            
        default:
            return false;
    }
}

/**
 * 檢查聊天室檔案訪問權限
 */
function checkChatFileAccess($roomId, $userId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            SELECT COUNT(*) 
            FROM chat_rooms 
            WHERE id = ? AND (creator_id = ? OR participant_id = ?)
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$roomId, $userId, $userId]);
        
        return $stmt->fetchColumn() > 0;
        
    } catch (Exception $e) {
        return false;
    }
}

/**
 * 檢查申訴檔案訪問權限
 */
function checkDisputeFileAccess($disputeId, $userId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            SELECT COUNT(*) 
            FROM task_disputes 
            WHERE id = ? AND user_id = ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$disputeId, $userId]);
        
        return $stmt->fetchColumn() > 0;
        
    } catch (Exception $e) {
        return false;
    }
}

/**
 * 檢查是否為管理員
 */
function isAdmin($userId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "SELECT permission FROM users WHERE id = ?";
        $stmt = $db->prepare($sql);
        $stmt->execute([$userId]);
        
        $permission = $stmt->fetchColumn();
        return $permission == 99; // 管理員權限
        
    } catch (Exception $e) {
        return false;
    }
}

/**
 * 記錄檔案訪問日誌
 */
function logFileAccess($fileRecord, $context) {
    Logger::logBusiness('media_accessed', null, [
        'file_id' => $fileRecord['id'],
        'file_name' => $fileRecord['file_name'],
        'context' => $context,
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? '',
        'ip_address' => $_SERVER['REMOTE_ADDR'] ?? ''
    ]);
}

/**
 * 提供檔案
 */
function serveFile($filePath, $fileRecord, $download = false) {
    // 設定 HTTP 標頭
    $mimeType = $fileRecord['mime_type'];
    $fileName = $fileRecord['original_name'];
    $fileSize = $fileRecord['file_size'];
    
    // 安全的 MIME 類型
    $safeMimeTypes = [
        'image/jpeg', 'image/png', 'image/gif', 'image/webp',
        'application/pdf', 'text/plain'
    ];
    
    if (!in_array($mimeType, $safeMimeTypes)) {
        $mimeType = 'application/octet-stream';
        $download = true; // 強制下載不安全的檔案類型
    }
    
    header('Content-Type: ' . $mimeType);
    header('Content-Length: ' . $fileSize);
    header('Cache-Control: private, max-age=3600'); // 1小時快取
    header('Last-Modified: ' . gmdate('D, d M Y H:i:s', filemtime($filePath)) . ' GMT');
    
    // 設定檔案名稱
    if ($download) {
        header('Content-Disposition: attachment; filename="' . addslashes($fileName) . '"');
    } else {
        header('Content-Disposition: inline; filename="' . addslashes($fileName) . '"');
    }
    
    // 支援範圍請求 (用於大檔案和影片)
    if (isset($_SERVER['HTTP_RANGE'])) {
        serveRangeRequest($filePath, $fileSize);
    } else {
        // 直接輸出檔案
        readfile($filePath);
    }
}

/**
 * 處理範圍請求
 */
function serveRangeRequest($filePath, $fileSize) {
    if (!isset($_SERVER['HTTP_RANGE'])) {
        return;
    }
    
    $range = $_SERVER['HTTP_RANGE'];
    
    if (preg_match('/bytes=(\d+)-(\d*)/', $range, $matches)) {
        $start = intval($matches[1]);
        $end = $matches[2] ? intval($matches[2]) : $fileSize - 1;
        
        if ($start > $end || $start >= $fileSize) {
            http_response_code(416);
            header('Content-Range: bytes */' . $fileSize);
            return;
        }
        
        $length = $end - $start + 1;
        
        http_response_code(206);
        header('Accept-Ranges: bytes');
        header('Content-Range: bytes ' . $start . '-' . $end . '/' . $fileSize);
        header('Content-Length: ' . $length);
        
        $handle = fopen($filePath, 'rb');
        fseek($handle, $start);
        
        $bufferSize = 8192;
        $remaining = $length;
        
        while ($remaining > 0 && !feof($handle)) {
            $readSize = min($bufferSize, $remaining);
            echo fread($handle, $readSize);
            $remaining -= $readSize;
            
            if (connection_aborted()) {
                break;
            }
        }
        
        fclose($handle);
    }
}

<?php
/**
 * 媒體檔案安全掃描 API
 * 手動觸發檔案掃描或查詢掃描結果
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/SecurityScanner.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/JWTManager.php';
require_once __DIR__ . '/../../utils/Logger.php';

// 禁用自動日誌記錄
define('LOGGING_MIDDLEWARE_DISABLED', true);

header('Content-Type: application/json');

try {
    // JWT 驗證 (管理員權限)
    $jwt = JWTManager::validateRequest();
    if (!$jwt['valid']) {
        Response::error('UNAUTHORIZED', $jwt['message']);
        exit;
    }
    
    // 檢查管理員權限
    if (!isAdmin($jwt['payload']['user_id'])) {
        Response::error('FORBIDDEN', '需要管理員權限');
        exit;
    }
    
    $method = $_SERVER['REQUEST_METHOD'];
    
    switch ($method) {
        case 'POST':
            handleScanRequest();
            break;
            
        case 'GET':
            handleScanQuery();
            break;
            
        default:
            Response::error('METHOD_NOT_ALLOWED', '不支援的請求方法');
    }
    
} catch (Exception $e) {
    Logger::logError('Media scan API failed', [
        'method' => $_SERVER['REQUEST_METHOD'],
        'error' => $e->getMessage()
    ], $e);
    
    Response::error('INTERNAL_ERROR', '掃描請求處理失敗');
}

/**
 * 處理掃描請求
 */
function handleScanRequest() {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $fileId = $input['file_id'] ?? null;
    $scanType = $input['scan_type'] ?? 'full'; // full, quick, rescan
    
    if (!$fileId) {
        Response::error('MISSING_PARAMETER', '缺少檔案 ID');
        return;
    }
    
    // 獲取檔案資訊
    $fileInfo = getFileInfo($fileId);
    if (!$fileInfo) {
        Response::error('FILE_NOT_FOUND', '檔案不存在');
        return;
    }
    
    // 檢查檔案是否存在於檔案系統
    if (!file_exists($fileInfo['file_path'])) {
        Response::error('PHYSICAL_FILE_NOT_FOUND', '實體檔案不存在');
        return;
    }
    
    // 執行掃描
    $scanner = new SecurityScanner();
    $scanResult = $scanner->scanFile($fileInfo['file_path'], $fileInfo['context']);
    
    // 更新資料庫記錄
    updateScanResult($fileId, $scanResult);
    
    Response::success('掃描完成', [
        'file_id' => $fileId,
        'scan_result' => $scanResult,
        'file_info' => [
            'name' => $fileInfo['original_name'],
            'size' => $fileInfo['file_size'],
            'context' => $fileInfo['context']
        ]
    ]);
}

/**
 * 處理掃描查詢
 */
function handleScanQuery() {
    $fileId = $_GET['file_id'] ?? null;
    $status = $_GET['status'] ?? null;
    $context = $_GET['context'] ?? null;
    $limit = min((int)($_GET['limit'] ?? 50), 100);
    $offset = max((int)($_GET['offset'] ?? 0), 0);
    
    if ($fileId) {
        // 查詢特定檔案的掃描結果
        $result = getScanResult($fileId);
        if ($result) {
            Response::success('掃描結果', $result);
        } else {
            Response::error('NOT_FOUND', '找不到掃描結果');
        }
    } else {
        // 查詢掃描列表
        $results = getScanList($status, $context, $limit, $offset);
        Response::success('掃描列表', $results);
    }
}

/**
 * 獲取檔案資訊
 */
function getFileInfo($fileId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            SELECT id, user_id, context, original_name, file_name, 
                   file_path, file_size, mime_type, scan_status, 
                   scan_result, created_at
            FROM media_files 
            WHERE id = ? AND deleted_at IS NULL
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$fileId]);
        
        return $stmt->fetch(PDO::FETCH_ASSOC);
        
    } catch (Exception $e) {
        Logger::logError('Failed to get file info', ['file_id' => $fileId], $e);
        return null;
    }
}

/**
 * 更新掃描結果
 */
function updateScanResult($fileId, $scanResult) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            UPDATE media_files 
            SET scan_status = ?, 
                scan_result = ?, 
                updated_at = NOW()
            WHERE id = ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([
            $scanResult['status'],
            json_encode($scanResult),
            $fileId
        ]);
        
        Logger::logBusiness('scan_result_updated', null, [
            'file_id' => $fileId,
            'status' => $scanResult['status'],
            'message' => $scanResult['message']
        ]);
        
        return true;
        
    } catch (Exception $e) {
        Logger::logError('Failed to update scan result', [
            'file_id' => $fileId,
            'scan_status' => $scanResult['status']
        ], $e);
        return false;
    }
}

/**
 * 獲取掃描結果
 */
function getScanResult($fileId) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $sql = "
            SELECT mf.*, u.name as user_name, u.email as user_email
            FROM media_files mf
            LEFT JOIN users u ON mf.user_id = u.id
            WHERE mf.id = ?
        ";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$fileId]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            // 解析掃描結果
            if ($result['scan_result']) {
                $result['scan_result'] = json_decode($result['scan_result'], true);
            }
            
            return $result;
        }
        
        return null;
        
    } catch (Exception $e) {
        Logger::logError('Failed to get scan result', ['file_id' => $fileId], $e);
        return null;
    }
}

/**
 * 獲取掃描列表
 */
function getScanList($status, $context, $limit, $offset) {
    try {
        $db = Database::getInstance()->getConnection();
        
        $whereConditions = ['mf.deleted_at IS NULL'];
        $params = [];
        
        if ($status) {
            $whereConditions[] = 'mf.scan_status = ?';
            $params[] = $status;
        }
        
        if ($context) {
            $whereConditions[] = 'mf.context = ?';
            $params[] = $context;
        }
        
        $whereClause = implode(' AND ', $whereConditions);
        
        // 查詢總數
        $countSql = "
            SELECT COUNT(*) 
            FROM media_files mf 
            WHERE $whereClause
        ";
        
        $countStmt = $db->prepare($countSql);
        $countStmt->execute($params);
        $total = $countStmt->fetchColumn();
        
        // 查詢列表
        $listSql = "
            SELECT mf.id, mf.user_id, mf.context, mf.original_name, 
                   mf.file_size, mf.mime_type, mf.scan_status, 
                   mf.created_at, mf.updated_at,
                   u.name as user_name, u.email as user_email
            FROM media_files mf
            LEFT JOIN users u ON mf.user_id = u.id
            WHERE $whereClause
            ORDER BY mf.updated_at DESC
            LIMIT ? OFFSET ?
        ";
        
        $listParams = array_merge($params, [$limit, $offset]);
        $listStmt = $db->prepare($listSql);
        $listStmt->execute($listParams);
        $files = $listStmt->fetchAll(PDO::FETCH_ASSOC);
        
        return [
            'files' => $files,
            'pagination' => [
                'total' => (int)$total,
                'limit' => $limit,
                'offset' => $offset,
                'has_more' => ($offset + $limit) < $total
            ]
        ];
        
    } catch (Exception $e) {
        Logger::logError('Failed to get scan list', [
            'status' => $status,
            'context' => $context
        ], $e);
        
        return [
            'files' => [],
            'pagination' => ['total' => 0, 'limit' => $limit, 'offset' => $offset, 'has_more' => false]
        ];
    }
}

/**
 * 檢查管理員權限
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

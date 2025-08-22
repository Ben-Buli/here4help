<?php
/**
 * 錯誤報告接收 API
 * 接收來自 Flutter 應用的錯誤報告
 */

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../utils/Response.php';
require_once __DIR__ . '/../../utils/Logger.php';
require_once __DIR__ . '/../../middleware/logging_middleware.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        Response::error(ErrorCodes::METHOD_NOT_ALLOWED);
    }
    
    // 解析請求資料
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        Response::error(ErrorCodes::INVALID_JSON);
    }
    
    $reports = $input['reports'] ?? [];
    $batchSize = $input['batch_size'] ?? count($reports);
    
    if (empty($reports)) {
        Response::error(ErrorCodes::MISSING_PARAMETER, 'No error reports provided');
    }
    
    // 驗證報告格式
    $processedReports = [];
    foreach ($reports as $report) {
        $validatedReport = validateErrorReport($report);
        if ($validatedReport) {
            $processedReports[] = $validatedReport;
        }
    }
    
    if (empty($processedReports)) {
        Response::error(ErrorCodes::INVALID_PARAMETER, 'No valid error reports');
    }
    
    // 保存錯誤報告
    $savedCount = 0;
    foreach ($processedReports as $report) {
        if (saveErrorReport($report)) {
            $savedCount++;
        }
    }
    
    // 記錄接收統計
    Logger::logBusiness('error_reports_received', null, [
        'batch_size' => $batchSize,
        'valid_reports' => count($processedReports),
        'saved_reports' => $savedCount,
        'client_info' => [
            'app_version' => $processedReports[0]['app_info']['version'] ?? null,
            'platform' => $processedReports[0]['device_info']['platform'] ?? null,
        ]
    ]);
    
    Response::success([
        'received' => $batchSize,
        'processed' => count($processedReports),
        'saved' => $savedCount
    ], 'Error reports received successfully');
    
} catch (Exception $e) {
    Logger::logError('Error reports API failed', [], $e);
    Response::error(ErrorCodes::INTERNAL_SERVER_ERROR, 'Failed to process error reports');
}

/**
 * 驗證錯誤報告格式
 */
function validateErrorReport($report) {
    if (!is_array($report)) {
        return null;
    }
    
    // 必要欄位檢查
    $requiredFields = ['timestamp', 'error_type', 'severity', 'message'];
    foreach ($requiredFields as $field) {
        if (!isset($report[$field]) || empty($report[$field])) {
            return null;
        }
    }
    
    // 驗證嚴重程度
    $validSeverities = ['debug', 'info', 'warning', 'error', 'critical'];
    if (!in_array($report['severity'], $validSeverities)) {
        return null;
    }
    
    // 驗證時間戳
    if (!strtotime($report['timestamp'])) {
        return null;
    }
    
    // 清理和標準化數據
    return [
        'timestamp' => $report['timestamp'],
        'error_type' => sanitizeString($report['error_type']),
        'severity' => $report['severity'],
        'message' => sanitizeString($report['message']),
        'stack_trace' => sanitizeString($report['stack_trace'] ?? ''),
        'context' => sanitizeString($report['context'] ?? ''),
        'device_info' => sanitizeArray($report['device_info'] ?? []),
        'app_info' => sanitizeArray($report['app_info'] ?? []),
        'additional_data' => sanitizeArray($report['additional_data'] ?? []),
        'user_id' => sanitizeString($report['user_id'] ?? ''),
        'session_id' => sanitizeString($report['session_id'] ?? ''),
        'received_at' => date('Y-m-d H:i:s'),
        'client_ip' => $_SERVER['REMOTE_ADDR'] ?? '',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? ''
    ];
}

/**
 * 保存錯誤報告
 */
function saveErrorReport($report) {
    try {
        // 保存到日誌檔案
        $logDir = __DIR__ . '/../../storage/logs';
        if (!is_dir($logDir)) {
            mkdir($logDir, 0755, true);
        }
        
        $logFile = $logDir . '/client_errors.log';
        $logEntry = json_encode($report) . "\n";
        
        if (file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX) === false) {
            return false;
        }
        
        // 如果是嚴重錯誤，額外記錄到系統日誌
        if (in_array($report['severity'], ['error', 'critical'])) {
            Logger::log(Logger::LEVEL_ERROR, 'Client Error Report', [
                'error_type' => $report['error_type'],
                'severity' => $report['severity'],
                'message' => $report['message'],
                'app_version' => $report['app_info']['version'] ?? null,
                'platform' => $report['device_info']['platform'] ?? null,
                'user_id' => $report['user_id'] ?: null
            ], Logger::TYPE_ERROR);
        }
        
        return true;
        
    } catch (Exception $e) {
        error_log("Failed to save error report: " . $e->getMessage());
        return false;
    }
}

/**
 * 清理字符串
 */
function sanitizeString($value) {
    if (!is_string($value)) {
        return '';
    }
    
    // 限制長度
    $value = substr($value, 0, 10000);
    
    // 移除危險字符
    $value = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', '', $value);
    
    return trim($value);
}

/**
 * 清理陣列
 */
function sanitizeArray($array) {
    if (!is_array($array)) {
        return [];
    }
    
    $sanitized = [];
    foreach ($array as $key => $value) {
        if (is_string($key) && strlen($key) <= 100) {
            if (is_string($value)) {
                $sanitized[$key] = sanitizeString($value);
            } elseif (is_numeric($value)) {
                $sanitized[$key] = $value;
            } elseif (is_bool($value)) {
                $sanitized[$key] = $value;
            } elseif (is_array($value)) {
                $sanitized[$key] = sanitizeArray($value);
            }
        }
    }
    
    return $sanitized;
}
?>

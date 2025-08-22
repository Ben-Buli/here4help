<?php
/**
 * 集中化日誌系統
 * 支援 TraceId 追蹤和結構化日誌記錄
 */

require_once __DIR__ . '/TraceId.php';
require_once __DIR__ . '/ErrorCodes.php';

class Logger {
    
    // 日誌級別
    const LEVEL_DEBUG = 'DEBUG';
    const LEVEL_INFO = 'INFO';
    const LEVEL_WARNING = 'WARNING';
    const LEVEL_ERROR = 'ERROR';
    const LEVEL_CRITICAL = 'CRITICAL';
    
    // 日誌類型
    const TYPE_REQUEST = 'request';
    const TYPE_RESPONSE = 'response';
    const TYPE_ERROR = 'error';
    const TYPE_BUSINESS = 'business';
    const TYPE_SECURITY = 'security';
    const TYPE_PERFORMANCE = 'performance';
    
    private static $logDir = null;
    
    /**
     * 初始化日誌目錄
     */
    private static function initLogDir() {
        if (self::$logDir === null) {
            self::$logDir = __DIR__ . '/../storage/logs';
            if (!is_dir(self::$logDir)) {
                mkdir(self::$logDir, 0755, true);
            }
        }
    }
    
    /**
     * 記錄日誌
     */
    public static function log($level, $message, $context = [], $type = self::TYPE_REQUEST) {
        self::initLogDir();
        
        $traceId = TraceId::current();
        $timestamp = date('Y-m-d H:i:s');
        
        $logEntry = [
            'timestamp' => $timestamp,
            'trace_id' => $traceId,
            'level' => $level,
            'type' => $type,
            'message' => $message,
            'context' => $context,
            'request' => [
                'method' => $_SERVER['REQUEST_METHOD'] ?? '',
                'uri' => $_SERVER['REQUEST_URI'] ?? '',
                'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
                'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? ''
            ]
        ];
        
        // 寫入對應的日誌檔案
        $logFile = self::$logDir . '/' . $type . '.log';
        file_put_contents($logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
        
        // 錯誤和關鍵級別也寫入 PHP 錯誤日誌
        if (in_array($level, [self::LEVEL_ERROR, self::LEVEL_CRITICAL])) {
            error_log("[$traceId] $level: $message");
        }
    }
    
    /**
     * 記錄 HTTP 請求
     */
    public static function logRequest($userId = null, $additionalContext = []) {
        $context = array_merge([
            'user_id' => $userId,
            'headers' => self::getRequestHeaders(),
            'body_size' => $_SERVER['CONTENT_LENGTH'] ?? 0
        ], $additionalContext);
        
        self::log(self::LEVEL_INFO, 'HTTP Request', $context, self::TYPE_REQUEST);
    }
    
    /**
     * 記錄 HTTP 響應
     */
    public static function logResponse($statusCode, $responseData = null, $additionalContext = []) {
        $level = self::getLogLevelByStatusCode($statusCode);
        
        $context = array_merge([
            'status_code' => $statusCode,
            'response_size' => $responseData ? strlen(json_encode($responseData)) : 0,
            'execution_time' => TraceId::getExecutionTime()
        ], $additionalContext);
        
        $message = "HTTP Response: $statusCode";
        
        self::log($level, $message, $context, self::TYPE_RESPONSE);
        
        // 4xx/5xx 錯誤額外記錄到錯誤日誌
        if ($statusCode >= 400) {
            self::logError("HTTP $statusCode Error", $context);
        }
    }
    
    /**
     * 記錄錯誤
     */
    public static function logError($message, $context = [], $exception = null) {
        if ($exception) {
            $context = array_merge($context, [
                'exception' => [
                    'class' => get_class($exception),
                    'message' => $exception->getMessage(),
                    'file' => $exception->getFile(),
                    'line' => $exception->getLine(),
                    'trace' => $exception->getTraceAsString()
                ]
            ]);
        }
        
        self::log(self::LEVEL_ERROR, $message, $context, self::TYPE_ERROR);
    }
    
    /**
     * 記錄商務事件
     */
    public static function logBusiness($event, $userId = null, $context = []) {
        $businessContext = array_merge([
            'user_id' => $userId,
            'event' => $event
        ], $context);
        
        self::log(self::LEVEL_INFO, "Business Event: $event", $businessContext, self::TYPE_BUSINESS);
    }
    
    /**
     * 記錄安全事件
     */
    public static function logSecurity($event, $userId = null, $context = []) {
        $securityContext = array_merge([
            'user_id' => $userId,
            'event' => $event,
            'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? ''
        ], $context);
        
        self::log(self::LEVEL_WARNING, "Security Event: $event", $securityContext, self::TYPE_SECURITY);
    }
    
    /**
     * 記錄性能事件
     */
    public static function logPerformance($operation, $duration, $context = []) {
        $performanceContext = array_merge([
            'operation' => $operation,
            'duration_ms' => $duration,
            'memory_usage' => memory_get_usage(true),
            'memory_peak' => memory_get_peak_usage(true)
        ], $context);
        
        $level = $duration > 5000 ? self::LEVEL_WARNING : self::LEVEL_INFO;
        
        self::log($level, "Performance: $operation took {$duration}ms", $performanceContext, self::TYPE_PERFORMANCE);
    }
    
    /**
     * 根據 HTTP 狀態碼決定日誌級別
     */
    private static function getLogLevelByStatusCode($statusCode) {
        if ($statusCode >= 500) {
            return self::LEVEL_ERROR;
        } elseif ($statusCode >= 400) {
            return self::LEVEL_WARNING;
        } elseif ($statusCode >= 300) {
            return self::LEVEL_INFO;
        } else {
            return self::LEVEL_INFO;
        }
    }
    
    /**
     * 獲取請求標頭
     */
    private static function getRequestHeaders() {
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (strpos($key, 'HTTP_') === 0) {
                $header = str_replace('HTTP_', '', $key);
                $header = str_replace('_', '-', $header);
                $headers[strtolower($header)] = $value;
            }
        }
        return $headers;
    }
    
    /**
     * 清理舊日誌檔案
     */
    public static function cleanup($daysToKeep = 30) {
        self::initLogDir();
        
        $cutoffTime = time() - ($daysToKeep * 24 * 60 * 60);
        $files = glob(self::$logDir . '/*.log');
        $cleaned = 0;
        
        foreach ($files as $file) {
            if (filemtime($file) < $cutoffTime) {
                unlink($file);
                $cleaned++;
            }
        }
        
        return $cleaned;
    }
    
    /**
     * 獲取日誌統計
     */
    public static function getStats($type = null, $hours = 24) {
        self::initLogDir();
        
        $pattern = $type ? self::$logDir . "/$type.log" : self::$logDir . '/*.log';
        $files = glob($pattern);
        
        $stats = [
            'total_entries' => 0,
            'error_count' => 0,
            'warning_count' => 0,
            'by_level' => [],
            'by_type' => [],
            'recent_errors' => []
        ];
        
        $cutoffTime = time() - ($hours * 60 * 60);
        
        foreach ($files as $file) {
            $lines = file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            
            foreach ($lines as $line) {
                $entry = json_decode($line, true);
                if (!$entry || !isset($entry['timestamp'])) continue;
                
                $entryTime = strtotime($entry['timestamp']);
                if ($entryTime < $cutoffTime) continue;
                
                $stats['total_entries']++;
                
                $level = $entry['level'] ?? 'UNKNOWN';
                $type = $entry['type'] ?? 'unknown';
                
                $stats['by_level'][$level] = ($stats['by_level'][$level] ?? 0) + 1;
                $stats['by_type'][$type] = ($stats['by_type'][$type] ?? 0) + 1;
                
                if ($level === self::LEVEL_ERROR) {
                    $stats['error_count']++;
                    if (count($stats['recent_errors']) < 10) {
                        $stats['recent_errors'][] = $entry;
                    }
                } elseif ($level === self::LEVEL_WARNING) {
                    $stats['warning_count']++;
                }
            }
        }
        
        return $stats;
    }
}
